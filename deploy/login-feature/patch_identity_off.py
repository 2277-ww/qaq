#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
关闭内置身份模式：config/config.php 的 identity.enabled 由 true 改为 false。

背景：identity.enabled=true 时 Home::getAuthInfo() 不读会话、恒返回内置账号
10000，所有人共享同一身份——登录会话即使写入也永远不生效。登录功能上线
必须先关掉这个开关。

用法（在生产机执行）：
    python3 patch_identity_off.py

安全措施：
    1. 备份原文件（带时间戳，保存在 config/ 目录内）
    2. 只做精确的「这一行」替换，替换计数必须等于 1，否则报错退出不改写
    3. 写入后 php -l 语法校验，失败自动回滚备份
"""

import os
import re
import subprocess
import sys
import time

CONFIG = '/www/ctc/config/config.php'

PATTERN = re.compile(
    r"(\$config\['identity'\]\['enabled'\]\s*=\s*)true(\s*;)"
)


def main():
    if not os.path.isfile(CONFIG):
        print('ERROR: config not found: %s' % CONFIG)
        return 1

    with open(CONFIG, 'r', encoding='utf-8') as fh:
        content = fh.read()

    if PATTERN.search(content) is None:
        # 已经是 false 视为幂等成功
        if re.search(
            r"\$config\['identity'\]\['enabled'\]\s*=\s*false\s*;", content
        ):
            print('SKIP: identity.enabled already false')
            return 0
        print('ERROR: identity.enabled definition not found or unexpected form')
        return 1

    new_content, count = PATTERN.subn(r"\1false\2", content)

    if count != 1:
        print('ERROR: expected exactly 1 replacement, got %d' % count)
        return 1

    backup = '%s.bak.%s' % (CONFIG, time.strftime('%Y%m%d%H%M%S'))

    with open(backup, 'w', encoding='utf-8') as fh:
        fh.write(content)
    os.chmod(backup, 0o640)

    with open(CONFIG, 'w', encoding='utf-8') as fh:
        fh.write(new_content)

    check = subprocess.run(
        ['/usr/bin/php', '-l', CONFIG],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )

    if check.returncode != 0:
        # 回滚
        with open(backup, 'r', encoding='utf-8') as fh:
            rolled = fh.read()
        with open(CONFIG, 'w', encoding='utf-8') as fh:
            fh.write(rolled)
        print('ERROR: php -l failed, rolled back: %s' % check.stderr.strip())
        return 1

    print('OK: identity.enabled true -> false, backup: %s' % backup)
    return 0


if __name__ == '__main__':
    sys.exit(main())
