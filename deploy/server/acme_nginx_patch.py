#!/usr/bin/env python3
# 在 80 端口站点配置中插入 ACME http-01 验证路径
# 只新增一个精确匹配的 location，不触碰 Halo 的代理规则

import shutil
import time

PATH = '/etc/nginx/conf.d/plaza.conf'
MARKER = '    # ---------- 站点主体 ----------'

BLOCK = """    # ---------- ACME 证书验证（Let's Encrypt http-01）----------
    location ^~ /.well-known/acme-challenge/ {
        root /var/www/acme;
        default_type text/plain;
        access_log off;
    }

"""

with open(PATH, encoding='utf-8') as fp:
    content = fp.read()

if 'acme-challenge' in content:
    print('SKIP: acme location already present')
else:
    if MARKER not in content:
        raise SystemExit('FAIL: anchor not found in plaza.conf')
    shutil.copy(PATH, PATH + '.bak.' + time.strftime('%Y%m%d%H%M%S'))
    content = content.replace(MARKER, BLOCK + MARKER, 1)
    with open(PATH, 'w', encoding='utf-8') as fp:
        fp.write(content)
    print('OK: acme location inserted')
