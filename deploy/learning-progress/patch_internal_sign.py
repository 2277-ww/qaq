# -*- coding: utf-8 -*-
"""
在生产 config.php 就地写入网关内部签名密钥并开启入站验签。

密钥从 STDIN 读取：不写进本脚本、不进命令行参数、不进版本库。
只替换两个已存在的键，绝不整文件覆盖——生产 config 里还有数据库口令、
域名等本地没有的配置。写前备份，写后 php -l，语法不过自动回滚。

用法（在生产机）：
    python3 patch_internal_sign.py < 密钥文件
"""
import io
import os
import re
import shutil
import subprocess
import sys
import time

CONFIG = '/www/ctc/config/config.php'


def main():
    secret = sys.stdin.readline().strip()

    if not re.match(r'^[0-9a-fA-F]{64}$', secret):
        print('ERROR: 密钥必须是 64 位十六进制字符串，实际长度 %d' % len(secret))
        return 1

    if not os.path.isfile(CONFIG):
        print('ERROR: 找不到 %s' % CONFIG)
        return 1

    with io.open(CONFIG, 'r', encoding='utf-8') as fh:
        src = fh.read()

    original = src

    pat_secret = re.compile(
        r"(\$config\['gateway'\]\['internal_sign_secret'\]\s*=\s*)'[^']*'\s*;"
    )
    pat_verify = re.compile(
        r"(\$config\['gateway'\]\['verify_sign'\]\s*=\s*)(?:true|false)\s*;"
    )

    if not pat_secret.search(src) or not pat_verify.search(src):
        print('ERROR: 目标配置键不存在，拒绝写入（请先确认 config 结构）')
        return 1

    src = pat_secret.sub(lambda m: m.group(1) + "'" + secret + "';", src)
    src = pat_verify.sub(lambda m: m.group(1) + 'true;', src)

    if src == original:
        print('SKIP: 配置已是目标值')
        return 0

    backup = CONFIG + '.bak.' + time.strftime('%Y%m%d%H%M%S')
    shutil.copy2(CONFIG, backup)

    with io.open(CONFIG, 'w', encoding='utf-8', newline='') as fh:
        fh.write(src)

    try:
        out = subprocess.check_output(
            ['php', '-l', CONFIG], stderr=subprocess.STDOUT
        )
        text = out.decode('utf-8', 'replace')
        if 'No syntax errors' not in text:
            raise RuntimeError(text)
    except Exception as exc:
        shutil.copy2(backup, CONFIG)
        print('ERROR: php -l 未通过，已回滚。%s' % exc)
        return 1

    print('OK: internal_sign_secret(len=%d) 与 verify_sign=true 已写入' % len(secret))
    print('BACKUP: %s' % backup)
    return 0


if __name__ == '__main__':
    sys.exit(main())
