# -*- coding: utf-8 -*-
"""
入站内部签名验收（在生产机上执行）。

用法（密钥不进命令行、不进脚本）：
    python3 verify_inbound_sign.py < 密钥文件
    BASE=https://8.138.34.151 python3 verify_inbound_sign.py < 密钥文件

签名规则与 App\\Services\\Learning\\Gateway::sign() 一致：
七个头按固定顺序用 \\n 连接，HMAC-SHA256，密钥为
gateway.internal_sign_secret（secrets.json 的 internal_sign_keys["learning"]）。
"""
import hashlib
import hmac
import os
import ssl
import sys
import time
import uuid
import urllib.error
import urllib.request as urlreq

SECRET = sys.stdin.readline().strip()
BASE = os.environ.get('BASE', 'https://127.0.0.1')
PATH = '/api/v1/learning/progress/10001'
# 网关侧 L2 路径带 internal 段；本平台 nginx 入口会剥离它。
# 入站签名 canonical 只含七个头、不含 path，剥离后验签结果必须一致。
PATH_INTERNAL = '/api/v1/learning/internal/progress/10001'

ORDER = [
    'X-User-Id', 'X-User-Role', 'X-Client-Id', 'X-Token-Exp',
    'X-Request-Id', 'X-Auth-Mode', 'X-Timestamp',
]

ctx = ssl._create_unverified_context()
opener = urlreq.build_opener(
    urlreq.HTTPSHandler(context=ctx), urlreq.ProxyHandler({})
)


def call(name, fields, sign_mode, expect, path=None):
    fields = dict(fields)
    fields['X-Request-Id'] = str(uuid.uuid4())
    fields['X-Timestamp'] = str(int(time.time()))

    # 签名仍按实际发出的时间戳计算，只让时间窗校验失败
    if sign_mode == 'good_expired':
        fields['X-Timestamp'] = str(int(time.time()) - 1000)

    canonical = '\n'.join([str(fields.get(k, '')) for k in ORDER])
    signature = hmac.new(
        SECRET.encode(), canonical.encode(), hashlib.sha256
    ).hexdigest()

    headers = dict((k, str(v)) for k, v in fields.items())
    if sign_mode in ('good', 'good_expired'):
        headers['X-Internal-Sign'] = signature
    elif sign_mode == 'bad':
        headers['X-Internal-Sign'] = '0' * 64

    req = urlreq.Request(BASE + (path or PATH), headers=headers, method='GET')
    try:
        resp = opener.open(req, timeout=12)
        status, body = resp.status, resp.read(320).decode('utf-8', 'replace')
    except urllib.error.HTTPError as exc:
        status, body = exc.code, exc.read(320).decode('utf-8', 'replace')
    except Exception as exc:
        status, body = 'ERR', '%s: %s' % (type(exc).__name__, exc)

    ok = expect(body, status)
    print('%s %-28s status=%-4s %s'
          % ('[PASS]' if ok else '[FAIL]', name, status,
             body.replace('\n', ' ')[:130]))
    return ok


USER = {
    'X-User-Id': '10001', 'X-User-Role': 'student',
    'X-Client-Id': 'jy-gateway', 'X-Token-Exp': '', 'X-Auth-Mode': 'user',
}
SERVICE = {
    'X-User-Id': '', 'X-User-Role': '',
    'X-Client-Id': 'jy-gateway', 'X-Token-Exp': '', 'X-Auth-Mode': 'service',
}

denied = lambda body, status: status == 401 and 'AUTH_REQUIRED' in body


def passed(body, status):
    """必须真正进入业务层。

    只看「不是 401」是不够的：服务态曾因 mode 归一化不一致被
    assertReadable 挡成 403 sys.forbidden，旧判定照样全绿，
    但经网关的机器调用实际一个接口都调不通。
    """
    return (status != 401
            and 'AUTH_REQUIRED' not in body
            and 'sys.forbidden' not in body
            and 'FORBIDDEN' not in body)

print('secret_len=%d base=%s' % (len(SECRET), BASE))
print('-' * 100)
results = [
    call('user 无签名', USER, None, lambda b, s: denied(b, s) and 'X-Internal-Sign' in b),
    call('user 错误签名', USER, 'bad', lambda b, s: denied(b, s) and '签名校验失败' in b),
    call('user 正确签名', USER, 'good', passed),
    call('service 无签名(伪造)', SERVICE, None, lambda b, s: denied(b, s) and 'X-Internal-Sign' in b),
    call('service 正确签名', SERVICE, 'good', passed),
    call('service 过期时间戳', SERVICE, 'good_expired',
         lambda b, s: denied(b, s) and '时间戳' in b),
    # 网关 internal 前缀：nginx 剥离后验签仍应生效，且不能被当成免鉴权路径
    call('internal 无签名', SERVICE, None,
         lambda b, s: denied(b, s) and 'X-Internal-Sign' in b, PATH_INTERNAL),
    call('internal 正确签名', SERVICE, 'good', passed, PATH_INTERNAL),
]
print('-' * 100)
print('ALL PASS' if all(results) else 'SOME FAILED')
sys.exit(0 if all(results) else 1)
