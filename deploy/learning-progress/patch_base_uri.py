"""在生产 config.php 中配置 gateway.base_uri（网关连接根地址）。

只替换 base_uri 一行（加注释），不碰其他键。
幂等：已配置则跳过。写前备份，写后 php -l，语法不过自动回滚。
"""
import io
import os
import subprocess
import sys
import time

CONFIG = '/www/ctc/config/config.php'
OLD = "$config['gateway']['base_uri'] = '';"
NEW = """/**
 * 统一网关根地址（投递链路用）。
 *
 * 留空表示「本地直连、不外发」：course.completed 只入箱、界面标记已投递。
 * 配上后经网关真实外发（L2 五头 + 内部签名头）；若网关侧对端路由的 L2
 * 白名单不含本平台 AppKey，会以 40108 失败进死信（可 replay），
 * 属网关侧待调整项，不是本平台配置错误。
 *
 * 注意：论坛账号确认走 gateway.account_base，不复用此值，两边互不影响。
 */
$config['gateway']['base_uri'] = 'http://8.138.246.181';"""

src = io.open(CONFIG, encoding='utf-8', newline='').read()
if OLD not in src:
    if "base_uri'] = 'http://8.138.246.181'" in src:
        print('SKIP: base_uri already configured')
        sys.exit(0)
    print('FAIL: anchor line not found')
    sys.exit(1)

ts = time.strftime('%Y%m%d%H%M%S')
bak = '/root/backup/config.php.bak.' + ts
io.open(bak, 'w', encoding='utf-8', newline='').write(src)
os.chmod(bak, 0o600)
io.open(CONFIG, 'w', encoding='utf-8', newline='').write(src.replace(OLD, NEW, 1))

lint = subprocess.Popen(['php', '-l', CONFIG],
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
out = lint.communicate()[0].decode('utf-8', 'replace')
if 'No syntax errors' not in out:
    io.open(CONFIG, 'w', encoding='utf-8', newline='').write(
        io.open(bak, encoding='utf-8', newline='').read())
    print('FAIL: php -l failed, rolled back. backup=' + bak)
    sys.exit(1)

print('OK: base_uri configured, php -l passed, backup=' + bak)
