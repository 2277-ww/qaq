#!/bin/bash
# 阶段一（最终3）：跳过 list，直接安装 PHP 7.3
set -e

pkill -f '01e.sh' 2>/dev/null || true
pkill -f 'dnf list' 2>/dev/null || true
sleep 1

echo "===== [1/4] 直接安装 PHP 7.3 ====="
dnf install -y \
    --disablerepo='*' \
    --enablerepo='alinux3-*' --enablerepo=epel --enablerepo=remi-safe --enablerepo=remi-php73 \
    --setopt=timeout=40 --setopt=retries=2 --allowerasing \
    php-fpm php-cli php-devel php-pdo php-mysqlnd \
    php-gd php-mbstring php-opcache php-zip php-bcmath php-json \
    php-process php-xml 2>&1 | tail -18

echo "===== [2/4] 版本核对 ====="
php -v | head -2
echo "===== [3/4] 扩展清单 ====="
php -m | tr '\n' ' '
echo
php-fpm -v 2>&1 | head -1
echo "STAGE1_OK"
