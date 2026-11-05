# -*- coding: utf-8 -*-
"""按文档规范验签的本地假网关

只做一件事：证明本平台真实发出的 HTTP 请求，能被一个独立实现验签通过。
验签规则严格照《论坛账号确认接口说明 v2.2.0》2.1 节：

  canonical = appKey \n timestamp \n nonce \n METHOD \n path \n canonicalQuery \n sha256Hex(rawBody)
  X-Signature = hex(HMAC-SHA256(appSecret, canonical))

与 account_verify_client.py 的 sign() 逐字一致。
"""
import hashlib
import hmac
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qsl, urlsplit, urlencode

APP_KEY = "jy-learning-svc"
APP_SECRET = "local-test-secret-0123456789"
SKEW = 300
NONCE_TTL = 600

_seen = {}          # nonce -> 首次出现时间
_calls = []         # 收到的请求记录，供末尾汇总


def canonical_query(query):
    """同名参数按 (key, value) 排序后 urlencode，空格编码为 +"""
    pairs = parse_qsl(query, keep_blank_values=True)
    pairs.sort(key=lambda kv: (kv[0], kv[1]))
    return urlencode(pairs)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def _reply(self, status, payload, extra=None):
        body = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)

        parsed = urlsplit(self.path)
        path = parsed.path
        query = canonical_query(parsed.query)

        app_key = self.headers.get("X-App-Key", "")
        ts = self.headers.get("X-Timestamp", "")
        nonce = self.headers.get("X-Nonce", "")
        alg = self.headers.get("X-Sign-Alg", "")
        sig = self.headers.get("X-Signature", "")

        record = {"path": path, "appKey": app_key, "hasBody": len(raw) > 0}

        # 1) 五个头齐不齐
        if not all([app_key, ts, nonce, alg, sig]):
            record["result"] = "40105 缺签名头"
            _calls.append(record)
            return self._reply(401, {"code": 40105, "message": "签名头不全", "data": None})

        # 2) 算法
        if alg != "HMAC-SHA256":
            record["result"] = "40105 算法不符"
            _calls.append(record)
            return self._reply(401, {"code": 40105, "message": "签名算法不符", "data": None})

        # 3) AppKey 白名单
        if app_key != APP_KEY:
            record["result"] = "40108 AppKey 未登记"
            _calls.append(record)
            return self._reply(401, {"code": 40108, "message": "AppKey 未注册", "data": None})

        # 4) 时间窗 ±300s
        try:
            skew = abs(int(time.time()) - int(ts))
        except (TypeError, ValueError):
            skew = 10 ** 9
        if skew > SKEW:
            record["result"] = "40106 时间戳超窗 offset=%ss" % skew
            _calls.append(record)
            return self._reply(401, {"code": 40106, "message": "时间戳超窗", "data": None})

        # 5) nonce 去重（600s）
        now = time.time()
        for k in [k for k, v in _seen.items() if now - v > NONCE_TTL]:
            _seen.pop(k, None)
        if nonce in _seen:
            record["result"] = "40107 nonce 重放"
            _calls.append(record)
            return self._reply(401, {"code": 40107, "message": "nonce 重复", "data": None})
        _seen[nonce] = now

        # 6) 重算签名
        canon = "\n".join([
            app_key, ts, nonce, "POST", path, query,
            hashlib.sha256(raw).hexdigest(),
        ])
        expect = hmac.new(APP_SECRET.encode(), canon.encode(), hashlib.sha256).hexdigest()

        if not hmac.compare_digest(expect, sig):
            record["result"] = "40105 签名不一致"
            record["expect"] = expect[:16]
            record["got"] = sig[:16]
            _calls.append(record)
            return self._reply(401, {"code": 40105, "message": "签名校验失败", "data": None})

        # 7) 签名通过，校验业务参数
        try:
            body = json.loads(raw or b"{}")
        except ValueError:
            record["result"] = "40001 请求体非 JSON"
            _calls.append(record)
            return self._reply(400, {"code": 40001, "message": "bad json",
                                     "data": {"confirmed": False, "reason": "invalid_params"}})

        login = str(body.get("login", ""))
        password = str(body.get("pass", ""))
        login_type = str(body.get("login_type", "auto"))

        if not login or not (8 <= len(password) <= 32) or login_type not in ("auto", "username", "email"):
            record["result"] = "40001 参数非法"
            _calls.append(record)
            return self._reply(400, {"code": 40001, "message": "invalid params",
                                     "data": {"confirmed": False, "reason": "invalid_params"}})

        # 按文档口径：账号不存在与密码错误同一结论
        if password == "Correct@12345":
            record["result"] = "200 confirmed"
            _calls.append(record)
            return self._reply(200, {
                "code": 200, "message": "ok",
                "data": {
                    "confirmed": True, "user_id": "1", "username": login,
                    "display_name": "测试账号", "role": "teacher",
                    "e_mail_masked": "t***@jspi.edu.cn",
                    "account_source": "legacy", "status": "available",
                    "request_id": nonce[:8] + "-fake",
                },
            })

        record["result"] = "40104 invalid_credentials"
        _calls.append(record)
        return self._reply(401, {
            "code": 40104, "message": "账号或密码错误",
            "data": {"confirmed": False, "reason": "invalid_credentials"},
        })

    def do_GET(self):
        if self.path != "/__stats":
            return self._reply(404, {"code": 40400, "message": "not found"})
        body = json.dumps(_calls, ensure_ascii=False).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 19090
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print("fake gateway on http://127.0.0.1:%d" % port, flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
