"""在生产 config.php 修正 peers/顶层 exam 的投递路径（加 internal 段、training→workshop）。

依据 2026-11-06 公网实测：
  /api/v1/exam/learning/progress          -> 40101（user 档，L2 不匹配）
  /api/v1/exam/internal/learning/progress -> 40108（service 档存在，白名单待网关方）
  /api/v1/training/internal/...           -> 40300（网关无 training 路由组）
  /api/v1/workshop/internal/...           -> 40108（workshop-internal 存在）

规则表每条必须恰好命中 1 次，否则整体失败回滚。写前备份，写后 php -l。
幂等：全部已是新值则跳过。
"""
import io
import os
import subprocess
import sys
import time

CONFIG = '/www/ctc/config/config.php'

RULES = [
    # (old, new, 说明)
    ("$config['exam']['push_path'] = '/api/v1/exam/learning/progress';",
     "$config['exam']['push_path'] = '/api/v1/exam/internal/learning/progress';",
     '顶层 exam.push_path 加 internal 段'),
    ("    'push_path' => '/api/v1/exam/learning/progress',",
     "    'push_path' => '/api/v1/exam/internal/learning/progress',",
     'peers.exam.push_path 加 internal 段'),
    ("    'push_path' => '/api/v1/training/learning/progress',",
     "    'push_path' => '/api/v1/workshop/internal/learning/progress',",
     'peers.training.push_path 修正平台名 training->workshop 并加 internal 段'),
    ("    'app_code' => 'learning',\n    'push_path' => '/api/v1/forum/learning/progress',",
     "    'app_code' => 'learning',\n"
     "    'app_key' => 'jy-learning-svc',\n"
     "    'push_path' => '/api/v1/forum/internal/learning/progress',",
     'peers.forum 补 app_key 并给 push_path 加 internal 段（enabled=false，仅对齐）'),
]

src = io.open(CONFIG, encoding='utf-8', newline='').read()

pending = [(o, n, d) for o, n, d in RULES if o in src]
already = all(n in src for o, n, d in RULES)

if not pending and already:
    print('SKIP: all rules already applied')
    sys.exit(0)

for old, new, desc in pending:
    if src.count(old) != 1:
        print('FAIL: rule not unique (%d hits): %s' % (src.count(old), desc))
        sys.exit(1)

ts = time.strftime('%Y%m%d%H%M%S')
bak = '/root/backup/config.php.bak.' + ts
io.open(bak, 'w', encoding='utf-8', newline='').write(src)
os.chmod(bak, 0o600)

for old, new, desc in pending:
    src = src.replace(old, new, 1)
    print('patched: ' + desc)

io.open(CONFIG, 'w', encoding='utf-8', newline='').write(src)

lint = subprocess.Popen(['php', '-l', CONFIG],
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
out = lint.communicate()[0].decode('utf-8', 'replace')
if 'No syntax errors' not in out:
    io.open(CONFIG, 'w', encoding='utf-8', newline='').write(
        io.open(bak, encoding='utf-8', newline='').read())
    print('FAIL: php -l failed, rolled back. backup=' + bak)
    sys.exit(1)

print('OK: %d rule(s) applied, php -l passed, backup=%s' % (len(pending), bak))
