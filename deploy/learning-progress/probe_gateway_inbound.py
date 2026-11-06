"""网关入站链路探测（表 7 补充后新增）。

用途：不依赖网关方口头确认，自行判断
  1) learning 三档路由分别由哪层拦截；
  2) learning-internal 的 L2 AppKey 白名单包含谁；
  3) 127.0.0.1:8080 后面是真实平台还是回显桩；
  4) 网关剥离/重算 identity 头的行为。

用法（密钥走 STDIN，不落脚本、不进命令行历史）：
    printf '%s\\n' "$APP_SECRET" | python3 probe_gateway_inbound.py
    # 或在服务器： python3 probe_gateway_inbound.py < /path/to/secret

只读探测，不修改网关任何配置。
"""
import hashlib
import hmac
import json
import socket
import sys
import time
import urllib.error
import urllib.parse as up
import urllib.request as u
import uuid

HOST = '8.138.246.181'
BASE = 'http://' + HOST
APP_KEY = 'jy-learning-svc'
SECRET = sys.stdin.readline().strip()
if len(SECRET) != 64:
    raise SystemExit('need 64-hex L2 app_secret on stdin (jy-learning-svc)')

INTERNAL = '/api/v1/learning/internal/peers/forum/handshake'
ANON = '/api/v1/learning/auth/login'
opener = u.build_opener(u.ProxyHandler({}))


def l2_headers(app_key, method, url, secret, body=b''):
    ts = str(int(time.time()))
    nonce = str(uuid.uuid4())
    ps = up.urlsplit(url)
    q = up.parse_qsl(ps.query, keep_blank_values=True)
    q.sort(key=lambda kv: (kv[0], kv[1]))
    canonical = '\n'.join([
        app_key, ts, nonce, method.upper(), ps.path,
        up.urlencode(q), hashlib.sha256(body).hexdigest(),
    ])
    return {
        'X-App-Key': app_key,
        'X-Timestamp': ts,
        'X-Nonce': nonce,
        'X-Sign-Alg': 'HMAC-SHA256',
        'X-Signature': hmac.new(secret.encode(), canonical.encode(),
                                hashlib.sha256).hexdigest(),
        'Content-Type': 'application/json',
    }


def call(url, headers=None, method='GET', data=None):
    req = u.Request(BASE + url, headers=headers or {}, method=method, data=data)
    try:
        r = opener.open(req, timeout=12)
        return r.status, r.read(), r.headers.get('Server', '')
    except urllib.error.HTTPError as e:
        return e.code, e.read(), e.headers.get('Server', '')
    except Exception as e:
        return 0, str(e).encode(), ''


def brief(status, body):
    text = body.decode('utf-8', 'replace')
    try:
        code = json.loads(text).get('code', '')
    except Exception:
        code = ''
    return 'HTTP %s code=%s %s' % (status, code, repr(text[:90]))


print('=== 1. 回环 upstream 端口（公网侧应全部不可达） ===')
for port in (8080, 8090, 8000, 9088, 80):
    s = socket.socket()
    s.settimeout(4)
    try:
        s.connect((HOST, port))
        result = 'OPEN'
    except Exception as e:
        result = type(e).__name__
    finally:
        s.close()
    print('  %-5s %s' % (port, result))

print()
print('=== 2. 三档路由分层（无签名） ===')
routes = [
    ('learning-api  (user)', '/api/v1/learning/peers'),
    ('learning-internal (service)', INTERNAL),
    ('learning-auth (anonymous)', ANON),
    ('exact /api/v1/learning', '/api/v1/learning'),
]
for label, path in routes:
    st, body, srv = call(path)
    print('  %-30s %s  server=%s' % (label, brief(st, body), srv))

print()
print('=== 3. learning-internal 的 L2 AppKey 白名单 ===')
print('  (40108=AppKey 不在该路由白名单；40105=AppKey 存在但签名不符)')
for key in (APP_KEY, 'jy-exam-svc', 'jy-workshop-svc',
            'jy-forum-svc', 'no-such-app'):
    st, body, _ = call(INTERNAL, l2_headers(key, 'GET', INTERNAL, SECRET))
    print('  %-20s %s' % (key, brief(st, body)))

print()
print('=== 4. 出站对照（同一把 AppKey 打账号确认，应进业务层） ===')
body_bytes = json.dumps({
    'login': 'probe@example.invalid', 'pass': 'never-valid',
    'login_type': 'auto', 'client_id': APP_KEY,
}, separators=(',', ':')).encode()
path = '/answer/api/v1/account/verify'
st, body, _ = call(path, l2_headers(APP_KEY, 'POST', path, SECRET, body_bytes),
                   method='POST', data=body_bytes)
print('  %s' % brief(st, body))

print()
print('=== 5. 回环桩回显：网关注入的 identity 七字段 ===')
st, body, _ = call(ANON)
try:
    d = json.loads(body.decode())
    print('  platform=%s sign_valid=%s body_bytes=%s'
          % (d.get('platform'), d.get('sign_valid'), d.get('body_bytes')))
    print('  identity fields = %s' % list(d.get('identity', {}).keys()))
except Exception:
    print('  ' + repr(body[:200]))

print()
print('=== 6. 伪造身份头是否被剥离（安全行为核对） ===')
forged = {
    'X-User-Id': '999999', 'X-User-Role': 'admin',
    'X-Client-Id': 'attacker', 'X-Token-Exp': '9999999999',
    'X-Request-Id': 'fake-request-id', 'X-Auth-Mode': 'service',
    'X-Timestamp': '1000000000', 'X-Internal-Sign': 'deadbeef',
    'X-App-Code': 'jy-forum',
}
st, body, _ = call(ANON, forged)
try:
    ident = json.loads(body.decode()).get('identity', {})
    checks = [
        ('user_id 剥离', ident.get('user_id') == ''),
        ('auth_mode 剥离', ident.get('auth_mode') == 'anonymous'),
        ('timestamp 重算', ident.get('timestamp') != '1000000000'),
        ('request_id 重算', ident.get('request_id') != 'fake-request-id'),
        ('sign_valid', json.loads(body.decode()).get('sign_valid') is True),
    ]
    for label, ok in checks:
        print('  %-20s %s' % (label, 'OK' if ok else 'FAIL'))
    print('  client_id=%r  <-- 注意 X-App-Code 是否透传' % ident.get('client_id'))
except Exception:
    print('  ' + repr(body[:200]))

print()
print('=== 判读 ===')
print('  learning-auth 200 且 platform=learning  => 8080 后是回显桩，不是本平台')
print('  jy-learning-svc 40108 / exam|workshop 40105 => 白名单只含 exam/workshop')
print('  出站 account/verify 40104 => L2 AppSecret 有效，40108 是白名单而非密钥问题')
