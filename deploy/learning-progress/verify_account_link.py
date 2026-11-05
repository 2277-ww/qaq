#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""论坛账号确认链路验收

分两组，分别定位「网关侧」与「本平台侧」的问题：

  A 网关组：直接打公网 /answer/api/v1/account/verify
            验证 L2 签名、时间窗、nonce、AppKey 白名单与错误码
  B 平台组：打本平台 /account/forum/login
            验证限流、建号、会话与失败提示

用法：

  # A 组（需要密钥）
  python verify_account_link.py --group gateway --secrets /etc/jingyuan-gateway/secrets.json

  # A 组（密钥走环境变量）
  APP_SECRET=xxx python verify_account_link.py --group gateway

  # B 组（本平台在跑）
  python verify_account_link.py --group platform --base http://127.0.0.1

  # 带一组真实账号跑成功分支
  python verify_account_link.py --group gateway --login admin@jspi.edu.cn --password 'XXXX'

注意：成功分支会真实调用账号确认接口，属于只读操作，不写任何账号数据。
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

APP_KEY_DEFAULT = "jy-learning-svc"
PATH_DEFAULT = "/answer/api/v1/account/verify"
BASE_DEFAULT = "http://8.138.246.181"

RESULT = []


def build_opener():
    """禁用系统代理：本地或内网地址被代理劫持时会表现成 502，看着像服务没起。"""
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    urllib.request.install_opener(opener)


def req(method, url, body=None, headers=None, timeout=15):
    data = body.encode() if isinstance(body, str) else body
    r = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", "ignore")
            status = resp.status
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "ignore")
        status = e.code
    except Exception as e:
        return 0, {"error": str(e)}
    try:
        return status, json.loads(raw)
    except Exception:
        return status, {"raw": raw[:200]}


def canonical_query(query):
    pairs = urllib.parse.parse_qsl(query, keep_blank_values=True)
    pairs.sort(key=lambda kv: (kv[0], kv[1]))
    return urllib.parse.urlencode(pairs)


def l2_headers(secret, method, path, body="", app_key=APP_KEY_DEFAULT,
               ts=None, nonce=None):
    ts = str(ts if ts is not None else int(time.time()))
    nonce = nonce or str(uuid.uuid4())
    parsed = urllib.parse.urlsplit(path)
    raw = body.encode() if isinstance(body, str) else body
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
        "X-Signature": sign,
        "Content-Type": "application/json",
    }


def gw_code(body):
    if not isinstance(body, dict):
        return 0
    code = body.get("code")
    return int(code) if isinstance(code, (int, str)) and str(code).isdigit() else 0


def check(name, ok, detail=""):
    RESULT.append((name, ok))
    print("%s  %-52s %s" % ("[PASS]" if ok else "[FAIL]", name, detail))


def group_gateway(secret, base, path, login, password):
    print("=" * 88)
    print("A 网关组 ·", base + path)
    print("=" * 88)

    url = base + path

    def body_of(login_value, pass_value):
        return json.dumps({
            "login": login_value, "pass": pass_value,
            "login_type": "auto", "client_id": "verify-account-suite",
        }, separators=(",", ":"), ensure_ascii=False)

    # 1 缺签名头
    st, d = req("POST", url, body_of(login, password),
                {"Content-Type": "application/json"})
    check("A1 缺签名头 -> 40105", st == 401 and gw_code(d) == 40105,
          "status=%s code=%s" % (st, gw_code(d)))

    # 2 错误签名
    h = l2_headers(secret, "POST", path, body_of(login, password))
    h["X-Signature"] = "0" * 64
    st, d = req("POST", url, body_of(login, password), h)
    check("A2 签名被篡改 -> 40105", st == 401 and gw_code(d) == 40105,
          "status=%s code=%s" % (st, gw_code(d)))

    # 3 时间戳超窗
    body = body_of(login, password)
    h = l2_headers(secret, "POST", path, body, ts=int(time.time()) - 3600)
    st, d = req("POST", url, body, h)
    check("A3 时间戳超窗 -> 40106", st == 401 and gw_code(d) == 40106,
          "status=%s code=%s" % (st, gw_code(d)))

    # 4 未知 AppKey
    h = l2_headers(secret, "POST", path, body, app_key="no-such-app")
    st, d = req("POST", url, body, h)
    check("A4 未知 AppKey -> 40108", st == 401 and gw_code(d) == 40108,
          "status=%s code=%s" % (st, gw_code(d)))

    # 5 密钥有效性探测
    #
    # 这一步是整个脚本的关键分叉：密钥不对时，后面每个用例都会返回 40105，
    # 看结果的人很容易以为是签名算法写错了，而实际上只是 AppSecret 配错。
    # 先单独判定，把「密钥问题」和「契约问题」彻底分开。
    probe_body = body_of(login if login else "probe", password or "12345678")
    h = l2_headers(secret, "POST", path, probe_body)
    st, d = req("POST", url, probe_body, h)
    secret_ok = not (st == 401 and gw_code(d) == 40105)

    check("A5 密钥有效性（正确签名可通过签名层）", secret_ok,
          "status=%s code=%s" % (st, gw_code(d)))

    if not secret_ok:
        print()
        print("已停止后续用例：A1-A4 证明链路与头构造正确，")
        print("当前 AppKey=%s 的签名被网关拒绝，请核对 secrets.json 里"
              " app_keys.%s.secret 的实际值。" % (APP_KEY_DEFAULT, APP_KEY_DEFAULT))
        return

    # 6 nonce 重放：同一 nonce 连发两次
    nonce = str(uuid.uuid4())
    h1 = l2_headers(secret, "POST", path, body, nonce=nonce)
    st1, _ = req("POST", url, body, h1)
    h2 = l2_headers(secret, "POST", path, body, nonce=nonce)
    st2, d2 = req("POST", url, body, h2)
    check("A6 同 nonce 重放 -> 40107", st2 == 401 and gw_code(d2) == 40107,
          "首次=%s 重放=%s/%s" % (st1, st2, gw_code(d2)))

    # 7 非 POST
    h = l2_headers(secret, "GET", path, "")
    st, d = req("GET", url, None, h)
    check("A7 非 POST -> 400/40001", st == 400 and gw_code(d) in (40001, 0),
          "status=%s code=%s" % (st, gw_code(d)))

    # 8 正确签名 + 错误密码 -> 同一结论
    if not password:
        print("[SKIP]  A8 未提供 --password，跳过账号结论分支")
    else:
        wrong = password + "_wrong_suffix"
        h = l2_headers(secret, "POST", path, body_of(login, wrong))
        st, d = req("POST", url, body_of(login, wrong), h)
        reason = (d.get("data") or {}).get("reason") if isinstance(d, dict) else ""
        check("A8 错误密码 -> 40104 invalid_credentials",
              st == 401 and gw_code(d) == 40104 and reason == "invalid_credentials",
              "status=%s code=%s reason=%s" % (st, gw_code(d), reason))

        # 9 不存在账号 -> 与错误密码同一结论（防枚举）
        ghost = "no_such_user_%d" % int(time.time())
        h = l2_headers(secret, "POST", path, body_of(ghost, password))
        st, d = req("POST", url, body_of(ghost, password), h)
        reason = (d.get("data") or {}).get("reason") if isinstance(d, dict) else ""
        check("A9 账号不存在 -> 与错误密码同结论",
              st == 401 and gw_code(d) == 40104 and reason == "invalid_credentials",
              "status=%s code=%s reason=%s" % (st, gw_code(d), reason))

        # 10 正确凭据 -> confirmed
        h = l2_headers(secret, "POST", path, body_of(login, password))
        st, d = req("POST", url, body_of(login, password), h)
        data = (d.get("data") or {}) if isinstance(d, dict) else {}
        check("A10 正确凭据 -> 200 confirmed",
              st == 200 and data.get("confirmed") is True,
              "status=%s uid=%s role=%s" % (st, data.get("user_id"), data.get("role")))

        # 11 敏感字段不外泄
        leaked = [k for k in ("pass", "password", "token", "phone", "e_mail")
                  if k in data]
        check("A11 响应不含密码/令牌/完整邮箱", not leaked,
              "泄露字段=%s" % (leaked or "无"))


def group_platform(base, login, password):
    print("=" * 88)
    print("B 平台组 ·", base + "/account/forum/login")
    print("=" * 88)

    url = base + "/account/forum/login"

    def post(payload, headers=None):
        return req("POST", url, json.dumps(payload, ensure_ascii=False), headers or {})

    # 1 参数缺失
    st, d = post({"account": "", "password": ""})
    check("B1 空账号 -> 非 5xx", 400 <= st < 500,
          "status=%s msg=%s" % (st, _msg(d)))

    # 2 密码过短（本地先拦，不打网关）
    st, d = post({"account": "someone", "password": "123"})
    check("B2 密码过短 -> 4xx 且提示格式", 400 <= st < 500 and _has(d, "8-32"),
          "status=%s msg=%s" % (st, _msg(d)))

    # 3 配置缺失时应是 503 而不是 500
    st, d = post({"account": "someone", "password": "12345678"})
    check("B3 未配置/不可达 -> 4xx/5xx 带可读提示",
          st in (400, 503) and _msg(d) != "",
          "status=%s msg=%s" % (st, _msg(d)))

    # 4 限流：连打 15 次应出现 429 语义的拒绝（提示尝试次数过多）
    hit = False
    for _ in range(15):
        st, d = post({"account": "throttle_probe", "password": "12345678"})
        if _has(d, "尝试次数过多"):
            hit = True
            break
    check("B4 同 IP 连续尝试触发限流", hit, "命中=%s" % hit)


def _msg(d):
    if not isinstance(d, dict):
        return ""
    return str(d.get("message") or d.get("msg") or d.get("error") or "")[:60]


def _has(d, needle):
    return needle in _msg(d)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--group", choices=["gateway", "platform", "all"], default="gateway")
    p.add_argument("--base", default=BASE_DEFAULT)
    p.add_argument("--path", default=PATH_DEFAULT)
    p.add_argument("--app-key", default=APP_KEY_DEFAULT)
    p.add_argument("--secrets", default="")
    p.add_argument("--login", default="admin@jspi.edu.cn")
    p.add_argument("--password", default="")
    args = p.parse_args()

    build_opener()

    secret = os.environ.get("APP_SECRET", "")

    if not secret and args.secrets:
        try:
            data = json.load(open(args.secrets, encoding="utf-8"))
            secret = data.get("app_keys", {}).get(args.app_key, {}).get("secret", "")
        except Exception as e:
            print("读取 secrets 失败：%s" % e)
            sys.exit(2)

    if args.group in ("gateway", "all") and not secret:
        print("缺少密钥：用 --secrets 指定 secrets.json，或设置 APP_SECRET 环境变量")
        print("提示：密钥在服务器 /etc/jingyuan-gateway/secrets.json 的 app_keys.%s.secret" % args.app_key)
        sys.exit(2)

    if args.group in ("gateway", "all"):
        group_gateway(secret, args.base, args.path, args.login, args.password)

    if args.group in ("platform", "all"):
        if args.group == "all":
            print()
        group_platform(args.base, args.login, args.password)

    total = len(RESULT)
    passed = sum(1 for _, ok in RESULT if ok)
    print()
    print("%d/%d 通过" % (passed, total))
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
