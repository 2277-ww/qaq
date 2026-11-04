#!/bin/bash
# 阶段一（最终2）：PHP 7.3 —— 排除所有系统源中的 php*，只从 remi-php73 取
set -e

echo "===== [0/7] 停掉旧任务 ====="
pkill -f '01d.sh' 2>/dev/null || true
pkill -f 'dnf makecache' 2>/dev/null || true
sleep 1

echo "===== [1/7] 清理残留 php 包 ====="
rpm -qa | grep -E '^php' | xargs -r rpm -e --nodeps 2>/dev/null || true
rpm -qa | grep -E '^php' | head -5
echo "(以上为空表示已清干净)"

echo "===== [2/7] 所有系统源排除 php* ====="
for f in /etc/yum.repos.d/*.repo; do
    case "$f" in
        *remi-php73*) continue ;;
    esac
    grep -q '^exclude=php' "$f" || sed -i '/^\[/a exclude=php php-*' "$f"
done
echo "已处理:"; grep -l 'exclude=php' /etc/yum.repos.d/*.repo | xargs -n1 basename | tr '\n' ' '
echo

echo "===== [3/7] 只刷新必要仓库 ====="
dnf clean all >/dev/null 2>&1 || true
timeout 180 dnf makecache --disablerepo='*' --enablerepo=remi-php73,remi-safe,alinux3-os,AliYun 2>&1 | tail -3 || echo "(makecache 超时，跳过)"

echo "===== [4/7] 可见的 php 版本 ====="
dnf list available 'php' --enablerepo=remi-php73 2>/dev/null | tail -3

echo "===== [5/7] 安装 PHP 7.3 ====="
dnf install -y --enablerepo=remi-php73 --allowerasing \
    php-fpm php-cli php-devel php-pdo php-mysqlnd \
    php-gd php-mbstring php-opcache php-zip php-bcmath php-json \
    php-process php-xml 2>&1 | tail -15

echo "===== [6/7] 版本核对 ====="
php -v | head -2
php -m | tr '\n' ' '
echo
php-fpm -v 2>&1 | head -1
echo "STAGE1_OK"
