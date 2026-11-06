#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""在生产 config.php 的 gateway 段就地补入账号确认所需配置键。

只插入缺失的键，已存在则跳过并报告，绝不整文件覆盖——
生产 config 里有数据库密码、域名等本地不存在的配置。
写前备份，写后 php -l，语法不过自动回滚。

密钥从 STDIN 读第一行，不接受命令行参数（会进 shell history 与进程列表），
也不硬编码在本文件里（本文件会进版本库）。
"""
import io
import subprocess
import sys
import time

CONFIG = '/www/ctc/config/config.php'

APP_KEY = 'jy-learning-svc'

APP_SECRET = sys.stdin.readline().strip()

if not APP_SECRET:
    print('ERROR 缺少密钥：请从 STDIN 传入')
    sys.exit(2)

BLOCK = """
/**
 * 网关 L2 应用凭据（服务态调用）
 *
 * app_key / app_secret 是「应用级」凭据，与 internal_sign_secret 那套七头
 * 内部签名不是同一把密钥：前者过网关入口，验完即剥离，不进上游；
 * 后者是网关重算后注入上游、供业务侧校验身份用的。
 *
 * app_secret 必须从网关机 /etc/jingyuan-gateway/secrets.json 的 app_keys 段取得，
 * 不得写进版本库（config.php 已在 .gitignore 内）。
 */
$config['gateway']['app_key'] = '%s';

$config['gateway']['app_secret'] = '%s';

/**
 * 论坛账号确认（用论坛账号登录本平台）
 *
 * account_base 留空则登录页不展示论坛登录入口，不会出现必然失败的按钮。
 * account_timeout 略大于网关 S 级 3s，留出本平台到网关这一跳的余量。
 */
$config['gateway']['account_base'] = 'http://8.138.246.181';

$config['gateway']['account_path'] = '/answer/api/v1/account/verify';

$config['gateway']['account_timeout'] = 5;

/**
 * 论坛登录限流：按客户端 IP 计数。
 * 不限流时本平台会成为论坛账号确认的代理入口，可被用来做密码尝试。
 */
$config['gateway']['account_login_limit'] = 10;

$config['gateway']['account_login_window'] = 60;

""" % (APP_KEY, APP_SECRET)


def main():
    src = io.open(CONFIG, encoding='utf-8').read()

    if "$config['gateway']['app_key']" in src:
        print('SKIP  已存在 gateway.app_key，不重复插入')
        return 0

    anchor = "$config['gateway']['expect_json'] = true;"

    if anchor not in src:
        print('ERROR 找不到锚点 expect_json，放弃修改')
        return 2

    bak = '%s.bak.%s' % (CONFIG, time.strftime('%Y%m%d%H%M%S'))
    io.open(bak, 'w', encoding='utf-8', newline='').write(src)
    print('BACKUP %s' % bak)

    out = src.replace(anchor, anchor + BLOCK, 1)

    io.open(CONFIG, 'w', encoding='utf-8', newline='').write(out)

    lint = subprocess.run(['php', '-l', CONFIG], capture_output=True, text=True)

    if lint.returncode != 0:
        io.open(CONFIG, 'w', encoding='utf-8', newline='').write(src)
        print('ROLLBACK 语法检查失败，已还原')
        print(lint.stdout + lint.stderr)
        return 3

    print('OK  已插入 7 个配置键，php -l 通过')
    return 0


if __name__ == '__main__':
    sys.exit(main())
