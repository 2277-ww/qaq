#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""论坛平台 · 学习进度事件接收端点（参考实现）

背景
----
网关的 forum-internal 路由把 /api/v1/forum/internal/* 原样转发到论坛上游
（设计约束是「路径不重写」），但论坛本体并没有学习进度接收接口，请求会被
论坛当成未知路径处理。这条端点就是补上这个缺口：它是论坛侧唯一需要新增的
东西，论坛本体不需要改。

部署形态
--------
只监听 127.0.0.1:9082，由网关的一条专用路由转发过来：

    /api/v1/forum/internal/learning/*  ->  127.0.0.1:9082

之所以单独起一条路由而不是改 forum-internal 的上游，是因为 forum-internal
后面还有论坛自己的内部 API，改上游会把它们一并打偏。

安全模型
--------
本端点不信任任何入站身份头，只信任 X-Internal-Sign。签名由网关在转发前
重算，密钥是「网关 ↔ 论坛」这一对，与学习平台那把不同。因此：

  * 请求直接打到 9082 而没经过网关 -> 签名对不上 -> 401
  * 外部伪造 X-Auth-Mode / X-User-Id -> 网关已剥离，这里是独立校验兜底

幂等
----
按 event_id 去重并落 sqlite。学习平台的投递器会重试，同一 event_id 可能到达
多次，重复到达必须返回 200 + duplicate，否则对方会一直重试到进死信。

注意
----
这是最小可用实现，用于打通链路与验收；正式上线建议并入论坛自己的服务框架，
数据库换成论坛现有的库，不要长期跑这个脚本。
"""

import hashlib
import hmac
import json
import os
import sqlite3
import sys
import time
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# ── 配置（生产从环境变量或 /etc/jingyuan-forum/peer.json 读，不要写死）──────
LISTEN_HOST = os.environ.get("FORUM_PEER_HOST", "127.0.0.1")
LISTEN_PORT = int(os.environ.get("FORUM_PEER_PORT", "9082"))
DB_PATH = os.environ.get("FORUM_PEER_DB", "/var/lib/jingyuan-forum/learning_events.db")

# 网关重算 X-Internal-Sign 用的密钥（「网关 ↔ 论坛」这一把，不是学习平台那把）
INTERNAL_SIGN_KEY = os.environ.get("FORUM_INTERNAL_SIGN_KEY", "")

# 允许的时间戳偏移，与网关 auth.sign.skew 一致
SKEW_SECONDS = int(os.environ.get("FORUM_SIGN_SKEW", "300"))

# 学习平台允许投递过来的事件类型（收到白名单之外的类型直接拒，不要静默入库）
ALLOWED_EVENTS = {
    "course.completed",
}

# 参与签名的七字段，顺序必须与网关 jy-identity 插件一致。
# 本平台（自学平台）的 Gateway::sign() 用的也是这个顺序；
# 若网关侧 jy-identity.lua 的拼接顺序不同，只改这里一行即可。
SIGN_FIELDS = [
    "X-User-Id",
    "X-User-Role",
    "X-Client-Id",
    "X-Token-Exp",
    "X-Request-Id",
    "X-Auth-Mode",
    "X-Timestamp",
]

MAX_BODY = 2 * 1024 * 1024


def canonical(headers):
    """按固定顺序拼接七字段，缺失的字段当作空串"""
    return "\n".join((headers.get(name) or "").strip() for name in SIGN_FIELDS)


def verify(headers, body):
    """返回 (ok, reason)"""
    if not INTERNAL_SIGN_KEY:
        return False, "sign_key_not_configured"

    given = (headers.get("X-Internal-Sign") or "").strip().lower()

    if not given:
        return False, "missing_signature"

    ts = (headers.get("X-Timestamp") or "").strip()

    if not ts.isdigit():
        return False, "missing_timestamp"

    if abs(int(time.time()) - int(ts)) > SKEW_SECONDS:
        return False, "timestamp_expired"

    expect = hmac.new(
        INTERNAL_SIGN_KEY.encode(), canonical(headers).encode(), hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(expect, given):
        return False, "bad_signature"

    return True, ""


def db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

    conn = sqlite3.connect(DB_PATH, timeout=10)

    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS learning_event (
            event_id      TEXT PRIMARY KEY,
            event_type    TEXT NOT NULL,
            user_id       TEXT,
            course_id     TEXT,
            progress      INTEGER,
            payload       TEXT,
            request_id    TEXT,
            received_at   INTEGER
        )
        """
    )

    conn.commit()

    return conn


class Handler(BaseHTTPRequestHandler):
    server_version = "forum-peer/1.0"

    def log_message(self, fmt, *args):
        # 一行一 JSON，便于和网关 access.log 对齐 request_id
        sys.stdout.write(
            json.dumps(
                {
                    "ts": int(time.time()),
                    "path": self.path,
                    "msg": fmt % args,
                },
                ensure_ascii=False,
            )
            + "\n"
        )
        sys.stdout.flush()

    def reply(self, status, code, message, data=None, request_id=""):
        body = json.dumps(
            {
                "code": code,
                "message": message,
                "data": data or {},
                "requestId": request_id or (self.headers.get("X-Request-Id") or ""),
            },
            ensure_ascii=False,
        ).encode()

        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/api/v1/forum/internal/learning/health":
            self.reply(200, "OK", "success", {"status": "up"})
            return

        self.reply(404, "NOT_FOUND", "接口不存在")

    def do_POST(self):
        if self.path.split("?")[0] != "/api/v1/forum/internal/learning/progress":
            self.reply(404, "NOT_FOUND", "接口不存在")
            return

        try:
            length = int(self.headers.get("Content-Length") or 0)

            if length > MAX_BODY:
                self.reply(413, "PAYLOAD_TOO_LARGE", "请求体超过 2MB")
                return

            raw = self.rfile.read(length) if length > 0 else b""

            ok, reason = verify(self.headers, raw)

            if not ok:
                self.reply(401, "UNAUTHORIZED", "内部签名校验失败：%s" % reason)
                return

            try:
                body = json.loads(raw.decode("utf-8"))
            except Exception:
                self.reply(400, "BAD_REQUEST", "请求体不是合法 JSON")
                return

            event_id = str(body.get("eventId") or "").strip()
            event_type = str(body.get("eventType") or "").strip()

            if not event_id or not event_type:
                self.reply(400, "VALIDATION_ERROR", "缺少 eventId 或 eventType")
                return

            if event_type not in ALLOWED_EVENTS:
                self.reply(
                    422,
                    "EVENT_NOT_ALLOWED",
                    "事件类型 %s 不在接收白名单内" % event_type,
                )
                return

            data = body.get("data") or {}

            conn = db()

            try:
                exists = conn.execute(
                    "SELECT 1 FROM learning_event WHERE event_id = ?", (event_id,)
                ).fetchone()

                if exists:
                    # 重复投递必须回 200，否则对方按失败重试到死信
                    self.reply(
                        200,
                        "OK",
                        "该事件已入库，幂等返回",
                        {"received": True, "duplicate": True, "eventId": event_id},
                    )
                    return

                conn.execute(
                    "INSERT INTO learning_event "
                    "(event_id, event_type, user_id, course_id, progress, payload, request_id, received_at) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    (
                        event_id,
                        event_type,
                        str(data.get("userId") or ""),
                        str(data.get("courseId") or ""),
                        int(data.get("progress") or 0),
                        raw.decode("utf-8", "replace"),
                        self.headers.get("X-Request-Id") or "",
                        int(time.time()),
                    ),
                )

                conn.commit()

            finally:
                conn.close()

            self.reply(
                200,
                "OK",
                "已受理",
                {"received": True, "duplicate": False, "eventId": event_id},
            )

        except Exception as err:  # noqa: BLE001
            traceback.print_exc()

            self.reply(500, "INTERNAL_ERROR", "服务内部错误：%s" % err)


def main():
    if not INTERNAL_SIGN_KEY:
        sys.stderr.write(
            "[warn] FORUM_INTERNAL_SIGN_KEY 未配置，所有请求都会被判签名失败\n"
        )

    server = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), Handler)

    sys.stdout.write(
        json.dumps(
            {
                "ts": int(time.time()),
                "msg": "forum peer endpoint listening",
                "addr": "%s:%d" % (LISTEN_HOST, LISTEN_PORT),
            }
        )
        + "\n"
    )
    sys.stdout.flush()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()


if __name__ == "__main__":
    main()
