#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""向生产 config/errors.php 追加论坛账号登录文案（幂等）。

只追加缺失的键，不覆盖生产已有文案——生产比本地少了一些模块，
直接覆盖会把本地的文案带进去，未必符合线上裁剪口径。
"""
import io
import subprocess
import sys
import time

TARGET = '/www/ctc/config/errors.php'

MARK = "$error['account.forum_login_failed']"

BLOCK = """/**
 * 论坛账号登录
 *
 * forum_login_failed 刻意不区分「账号不存在」与「密码错误」：论坛侧对这两种
 * 情况返回同一结论，本平台若再细分，两边各泄露一点信息就能拼出账号枚举能力。
 */
$error['account.forum_login_failed'] = '论坛账号或密码不正确';
$error['account.forum_account_unavailable'] = '该论坛账号已停用，请联系管理员';
$error['account.forum_invalid_params'] = '账号或密码格式不正确（密码 8-32 位）';
$error['account.forum_not_configured'] = '未启用论坛账号登录';
$error['account.forum_unavailable'] = '论坛账号服务暂不可用，请稍后重试或使用本平台账号登录';
$error['account.forum_rate_limited'] = '尝试次数过多，请稍后再试';

"""


def main():
    src = io.open(TARGET, encoding='utf-8').read()

    if MARK in src:
        print('SKIP  文案已存在')
        return 0

    anchor = 'return $error;'

    if anchor not in src:
        print('ERROR 找不到 return $error;')
        return 2

    bak = '%s.bak.%s' % (TARGET, time.strftime('%Y%m%d%H%M%S'))
    io.open(bak, 'w', encoding='utf-8', newline='').write(src)
    print('BACKUP %s' % bak)

    out = src.replace(anchor, BLOCK + anchor, 1)

    io.open(TARGET, 'w', encoding='utf-8', newline='').write(out)

    lint = subprocess.Popen(['php', '-l', TARGET],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    stdout, stderr = lint.communicate()

    if lint.returncode != 0:
        io.open(TARGET, 'w', encoding='utf-8', newline='').write(src)
        print('ROLLBACK 语法失败')
        print(stdout.decode('utf-8', 'replace') + stderr.decode('utf-8', 'replace'))
        return 3

    print('OK  已追加 6 条文案，php -l 通过')
    return 0


if __name__ == '__main__':
    sys.exit(main())
