#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""为「学习进度 → 论坛」新增一条网关路由（在网关服务器上执行）

为什么不是复用 forum-internal
----------------------------
forum-internal 的上游是论坛本体 9088，它后面还有论坛自己的内部 API。把它的
上游改到学习事件接收端点，会把论坛内部调用一并打偏。正确做法是加一条更长的
前缀路由，让 APISIX 按最长匹配分流：

    /api/v1/forum/internal/learning/*  ->  127.0.0.1:9082   （本脚本新增）
    /api/v1/forum/internal/*           ->  127.0.0.1:9088   （原样保留）

为什么复制而不是手写插件
------------------------
鉴权、限流、体积、超时、可信头注入、错误规范化这一整套参数必须和 forum-internal
完全一致，手抄容易漏（尤其 L2 签名插件漏了就等于端口裸奔）。这里直接从 Admin API
读出 forum-internal 的配置，只替换 uri / id / upstream / desc 四个字段再写回，
新增路由自动继承同一套策略。

用法
----
    # 预演，只打印将要写入的内容
    python3 add_forum_learning_route.py --dry-run

    # 正式写入（幂等，可重复执行）
    python3 add_forum_learning_route.py

    # 撤销
    python3 add_forum_learning_route.py --delete
"""

import argparse
import json
import sys
import urllib.error
import urllib.request

ADMIN = "http://127.0.0.1:9180/apisix/admin"
SECRETS = "/etc/jingyuan-gateway/secrets.json"

SOURCE_ROUTE = "forum-internal"
TARGET_ROUTE = "forum-learning-events"
TARGET_URI = "/api/v1/forum/internal/learning/*"
TARGET_NODES = {"127.0.0.1:9082": 1}


def admin_key():
    with open(SECRETS, encoding="utf-8") as fh:
        return json.load(fh)["admin_key"]


def call(method, path, body=None, key=""):
    data = json.dumps(body).encode() if body is not None else None

    req = urllib.request.Request(
        ADMIN + path,
        data=data,
        method=method,
        headers={"X-API-KEY": key, "Content-Type": "application/json"},
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status, json.loads(resp.read().decode() or "{}")
    except urllib.error.HTTPError as err:
        return err.code, json.loads(err.read().decode() or "{}")


def build(key):
    status, payload = call("GET", "/routes/" + SOURCE_ROUTE, key=key)

    if status != 200:
        sys.exit("读取 %s 失败（HTTP %s），请确认路由 ID 与 Admin Key" % (SOURCE_ROUTE, status))

    node = payload.get("value") or payload.get("node", {}).get("value") or {}

    if not node:
        sys.exit("响应里没有路由内容，Admin API 版本可能不同，请检查返回结构")

    route = {
        "id": TARGET_ROUTE,
        "name": TARGET_ROUTE,
        "desc": "学习进度事件投递到论坛接收端点（继承 forum-internal 的鉴权与限流策略）",
        "uri": TARGET_URI,
        "methods": node.get("methods", ["POST"]),
        "plugins": node.get("plugins", {}),
        "upstream": {
            "type": "roundrobin",
            "scheme": "http",
            "nodes": TARGET_NODES,
            # 学习进度是内部事件投递，沿用 S 档（3s）足够；超时过长会让投递器
            # 一直挂着，反而拖慢发件箱整体吞吐
            "timeout": {"connect": 1, "send": 3, "read": 3},
            "pass_host": "node",
        },
        "status": 1,
    }

    return route


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--delete", action="store_true")
    args = parser.parse_args()

    key = admin_key()

    if args.delete:
        status, payload = call("DELETE", "/routes/" + TARGET_ROUTE, key=key)
        print("删除 %s -> HTTP %s" % (TARGET_ROUTE, status))
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return

    route = build(key)

    # 安全兜底：L2 签名插件必须在，否则这条路由等于把接收端点暴露在公网
    if "jy-l2-sign" not in route["plugins"]:
        sys.exit(
            "forum-internal 上没有 jy-l2-sign 插件，拒绝创建——"
            "否则 /api/v1/forum/internal/learning/* 会绕过服务态鉴权"
        )

    if args.dry_run:
        print(json.dumps(route, ensure_ascii=False, indent=2))
        return

    status, payload = call("PUT", "/routes/" + TARGET_ROUTE, route, key=key)

    print("写入 %s -> HTTP %s" % (TARGET_ROUTE, status))
    print(json.dumps(payload, ensure_ascii=False, indent=2))

    if status not in (200, 201):
        sys.exit(1)

    print(
        "\n完成。验证：\n"
        "  curl -i http://127.0.0.1/api/v1/forum/internal/learning/health\n"
        "  期望：带 L2 头时 200；不带时 401/40105"
    )


if __name__ == "__main__":
    main()
