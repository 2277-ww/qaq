#!/bin/bash
# 阶段一（最终）：PHP 7.3 —— 系统源排除 php*，只从 remi-php73 安装
set -e

echo "===== [0/6] 清理残留 php 包 ====="
rpm -qa | grep -E '^php' | xargs -r rpm -e --nodeps 2>/dev/null || true
rpm -qa | grep -E '^php' | head -5
echo "(以上为空表示已清干净)"

echo "===== [1/6] 系统源排除 php* ====="
for f in /etc/yum.repos.d/alinux3-*.repo /etc/yum.repos.d/epel*.repo; do
    [ -f "$f" ] || continue
    grep -q '^exclude=php\*' "$f" || sed -i '/^\[/a exclude=php*' "$f"
done
grep -l 'exclude=php' /etc/yum.repos.d/*.repo | tr '\n' ' '
echo

echo "===== [2/6] 刷新元数据 ====="
dnf clean all >/dev/null 2>&1 || true
dnf makecache >/dev/null 2>&1 || true

echo "===== [3/6] 可见的 php 版本 ====="
dnf list available 'php' --enablerepo=remi-php73 2>/dev/null | tail -3

echo "===== [4/6] 安装 PHP 7.3 ====="
dnf install -y --enablerepo=remi-php73 --allowerasing \
    php-fpm php-cli php-devel php-pdo php-mysqlnd \
    php-gd php-mbstring php-opcache php-zip php-bcmath php-json \
    php-process php-xml 2>&1 | tail -15

echo "===== [5/6] 版本核对 ====="
php -v | head -2
php -m | tr '\n' ' '
echo
php-fpm -v 2>&1 | head -1
echo "STAGE1_OK"
