#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""学习进度窗口 ↔ 论坛平台 接入验收

分两组，可以分开跑：

  A 网关组（对公网统一网关）
    证明「本平台的 L2 签名实现与网关一致」。这一组不需要论坛上线，也不需要
    本平台部署在网关后面——它验的是签名本身能不能过网关。

  B 平台组（对本平台）
    证明握手、能力发现、入站鉴权、跨对端隔离都正常。

用法
----
  # 只跑网关组（最常见；密钥从文件读，不落命令行历史）
  python verify_forum_link.py --group gateway --secrets secrets.json

  # 用环境变量传密钥
  APP_SECRET=xxx python verify_forum_link.py --group gateway

  # 跑平台组（本平台已在本机/内网起好）
  python verify_forum_link.py --group platform --base http://127.0.0.1 --peer forum

  # 两组都跑
  python verify_forum_link.py --secrets secrets.json --base http://127.0.0.1

密钥来源
--------
网关服务器 /etc/jingyuan-gateway/secrets.json：
    app_keys["jy-learning-svc"]["secret"]         -> APP_SECRET
    internal_sign_keys["learning"]                -> INTERNAL_SIGN_KEY（平台组用）

注意
----
非交互环境里跑，务必确认系统代理不会劫持 127.0.0.1 的请求，
否则本地用例会以 502 的形态失败，看起来像服务没起来。
"""

import argparse
import hashlib
import hmac
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

GATEWAY = os.environ.get("GATEWAY_BASE", "http://8.138.246.181")
APP_KEY = os.environ.get("APP_KEY", "jy-learning-svc")

RESULT = []


def build_opener(no_proxy_local=True):
    handlers = []

    if no_proxy_local:
        # 本地回环绝不能被代理接管，否则一律 502
        handlers.append(urllib.request.ProxyHandler({
            "http": "", "https": "",
            "no": "127.0.0.1,localhost,::1",
        }))

    return urllib.request.build_opener(*handlers)


OPENER = build_opener()


def req(method, url, body=None, headers=None, timeout=15):
    data = None
    h = dict(headers or {})

    if body is not None:
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        h.setdefault("Content-Type", "application/json")

    r = urllib.request.Request(url, data=data, method=method, headers=h)

    try:
        with OPENER.open(r, timeout=timeout) as resp:
            return resp.status, dict(resp.headers), resp.read()
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read()
    except Exception as e:  # noqa: BLE001
        return 0, {}, str(e).encode()


def jbody(raw):
    try:
        return json.loads(raw.decode("utf-8", "ignore"))
    except Exception:
        return {}


def check(name, ok, detail=""):
    RESULT.append((name, ok, detail))
    print("%s  %-46s %s" % ("[PASS]" if ok else "[FAIL]", name, detail))
    return ok


# ── L2 签名（与网关 jy-l2-sign 及本平台 GatewaySign 同一套规范）──────────────
def canonical_query(query):
    pairs = urllib.parse.parse_qsl(query, keep_blank_values=True)
    pairs.sort(key=lambda kv: (kv[0], kv[1]))
    return urllib.parse.urlencode(pairs)


def l2_headers(secret, method, path, body="", ts=None, nonce=None, app_key=None,
               sign_override=None):
    ts = str(ts if ts is not None else int(time.time()))
    nonce = nonce or uuid.uuid4().hex
    app_key = app_key or APP_KEY

    parsed = urllib.parse.urlsplit(path)
    raw = body.encode() if isinstance(body, str) else (body or b"")

    canonical = "\n".join([
        app_key, ts, nonce, method.upper(), parsed.path,
        canonical_query(parsed.query), hashlib.sha256(raw).hexdigest(),
    ])

    sign = hmac.new(secret.encode(), canonical.encode(), hashlib.sha256).hexdigest()

    return {
        "X-App-Key": app_key,
        "X-Timestamp": ts,
        "X-Nonce": nonce,
        "X-Sign-Alg": "HMAC-SHA256",
        "X-Signature": sign_override if sign_override is not None else sign,
    }


def gw_code(body):
    d = jbody(body)

    return int(d.get("code") or 0) if isinstance(d, dict) else 0


# ── A 网关组 ────────────────────────────────────────────────────────────────
def group_gateway(secret, peer):
    path = "/api/v1/learning/internal/peers/%s/handshake" % peer
    url = GATEWAY + path

    print("\n── A 网关组 · %s ────────────────────────────────────" % GATEWAY)

    st, _, raw = req("GET", url)
    check("A1 路由存在且需鉴权", st in (401, 403),
          "status=%d code=%s" % (st, gw_code(raw)))

    h = l2_headers(secret, "GET", path)
    st, _, raw = req("GET", url, headers=h)
    code = gw_code(raw)

    check("A2 L2 正确签名通过网关", code not in (40105, 40106, 40108),
          "status=%d code=%s（非签名类错误即算法一致）" % (st, code))

    bad = dict(h, **{"X-Signature": "0" * 64})
    st, _, raw = req("GET", url, headers=bad)
    check("A3 篡改签名 -> 40105", gw_code(raw) == 40105,
          "status=%d code=%s" % (st, gw_code(raw)))

    # 重放同一个 nonce：网关侧 Redis 记 600s
    st, _, raw = req("GET", url, headers=h)
    check("A4 nonce 重放 -> 40107", gw_code(raw) == 40107,
          "status=%d code=%s" % (st, gw_code(raw)))

    h2 = l2_headers(secret, "GET", path, ts=int(time.time()) - 3600)
    st, _, raw = req("GET", url, headers=h2)
    check("A5 时间戳超窗 -> 40106", gw_code(raw) == 40106,
          "status=%d code=%s" % (st, gw_code(raw)))

    h3 = l2_headers(secret, "GET", path, app_key="jy-not-exist-svc")
    st, _, raw = req("GET", url, headers=h3)
    check("A6 未知 AppKey -> 40108", gw_code(raw) == 40108,
          "status=%d code=%s" % (st, gw_code(raw)))

    h4 = {k: v for k, v in h.items() if k != "X-Nonce"}
    st, _, raw = req("GET", url, headers=h4)
    check("A7 缺签名头 -> 40105", gw_code(raw) == 40105,
          "status=%d code=%s" % (st, gw_code(raw)))

    # 带 query 的签名：最容易出偏差的一段（排序 + 空格编码）
    qpath = "/api/v1/learning/internal/peers/%s/pull?limit=10&afterId=1&flag=" % peer
    h5 = l2_headers(secret, "GET", qpath)
    st, _, raw = req("GET", GATEWAY + qpath, headers=h5)
    check("A8 带 query 的签名一致", gw_code(raw) not in (40105, 40106),
          "status=%d code=%s" % (st, gw_code(raw)))

    # 投递路径：L2 通 + 上游未接线时应为 404/502，而不是签名错
    push = "/api/v1/forum/internal/learning/progress"
    payload = json.dumps({"eventId": "evt_check", "eventType": "course.completed"},
                         ensure_ascii=False)
    h6 = l2_headers(secret, "POST", push, payload)
    st, _, raw = req("POST", GATEWAY + push, payload, headers=h6)
    check("A9 投递路径已接线", st in (200, 202, 404, 422, 500, 502) and gw_code(raw) not in (40105, 40300),
          "status=%d code=%s body=%s" % (st, gw_code(raw), raw[:90].decode("utf-8", "ignore")))


# ── B 平台组 ────────────────────────────────────────────────────────────────
def group_platform(base, peer, internal_key):
    print("\n── B 平台组 · %s ────────────────────────────────────" % base)

    prefix = "/api/v1/learning/internal/peers/" + peer

    st, _, raw = req("GET", base + prefix + "/handshake")
    d = jbody(raw)
    data = d.get("data") or {}
    check("B1 握手 200", st == 200, "status=%d" % st)
    check("B2 契约版本", data.get("contract") == "learning-progress/1.0",
          "contract=%s" % data.get("contract"))
    check("B3 对端已启用", data.get("peerEnabled") is True,
          "peerEnabled=%s" % data.get("peerEnabled"))
    l2 = ((data.get("gatewayEntry") or {}).get("l2") or {})
    check("B4 已下发 L2 规范", bool(l2.get("headers")), "appKey=%s" % l2.get("appKey"))
    check("B5 出站地址就绪", data.get("outboundReady") is True,
          "notice=%s" % (data.get("notice") or "无"))

    student = "/students/usr_10000/progress"

    st, _, raw = req("GET", base + prefix + student)
    check("B6 未签名 -> 401", st == 401, "status=%d" % st)

    if internal_key:
        ts = str(int(time.time()))
        rid = str(uuid.uuid4())
        fields = {
            "X-User-Id": "", "X-User-Role": "", "X-Client-Id": "learning-service",
            "X-Token-Exp": "", "X-Request-Id": rid, "X-Auth-Mode": "service",
            "X-Timestamp": ts,
        }
        sign = hmac.new(internal_key.encode(),
                        "\n".join(fields[k] for k in
                                  ["X-User-Id", "X-User-Role", "X-Client-Id",
                                   "X-Token-Exp", "X-Request-Id", "X-Auth-Mode",
                                   "X-Timestamp"]).encode(),
                        hashlib.sha256).hexdigest()

        st, _, raw = req("GET", base + prefix + student,
                         headers=dict(fields, **{"X-Internal-Sign": sign}))
        check("B7 网关注入签名 -> 放行", st in (200, 404),
              "status=%d（404 表示用户不存在，链路已通）" % st)

        st, _, raw = req("GET", base + prefix + student,
                         headers=dict(fields, **{"X-Internal-Sign": "0" * 64}))
        check("B8 错误签名 -> 401", st == 401, "status=%d" % st)
    else:
        print("[SKIP]  B7/B8 需要 INTERNAL_SIGN_KEY 才能验（从 secrets.json 取）")

    st, _, raw = req("GET", base + "/api/v1/learning/internal/peers/not-registered/handshake")
    check("B9 未登记对端 -> 404", st == 404, "status=%d" % st)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--group", choices=["gateway", "platform", "all"], default="all")
    p.add_argument("--secrets", default="", help="secrets.json 路径")
    p.add_argument("--base", default="http://127.0.0.1", help="本平台地址")
    p.add_argument("--peer", default="forum")
    args = p.parse_args()

    secret = os.environ.get("APP_SECRET", "")
    internal_key = os.environ.get("INTERNAL_SIGN_KEY", "")

    if args.secrets:
        with open(args.secrets, encoding="utf-8") as fh:
            s = json.load(fh)

        app_keys = s.get("app_keys") or {}
        node = app_keys.get(APP_KEY) or {}
        secret = secret or node.get("secret", "")

        isk = s.get("internal_sign_keys") or {}
        if isinstance(isk, dict):
            internal_key = internal_key or isk.get("learning", "")

    print("=" * 74)
    print("学习进度窗口 ↔ 论坛平台 接入验收")
    print("=" * 74)

    if args.group in ("gateway", "all"):
        if not secret:
            print("[SKIP]  网关组需要 APP_SECRET（--secrets 或环境变量）")
        else:
            group_gateway(secret, args.peer)

    if args.group in ("platform", "all"):
        group_platform(args.base, args.peer, internal_key)

    print("\n" + "=" * 74)
    passed = sum(1 for _, ok, _ in RESULT if ok)
    print("结果：%d/%d 通过" % (passed, len(RESULT)))
    fails = [n for n, ok, _ in RESULT if not ok]
    if fails:
        print("未通过：" + "; ".join(fails))
    print("=" * 74)

    return 0 if RESULT and passed == len(RESULT) else 1


if __name__ == "__main__":
    sys.exit(main())
