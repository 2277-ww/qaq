#!/bin/bash
# 阶段一：PHP 7.3 运行时（remi 源）
set -e
echo "===== [1/4] 安装 remi 源 ====="
dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm 2>&1 | tail -5

echo "===== [2/4] 启用 php:remi-7.3 ====="
dnf module reset php -y 2>&1 | tail -3
dnf module enable php:remi-7.3 -y 2>&1 | tail -5

echo "===== [3/4] 安装 PHP 7.3 与编译工具链 ====="
dnf install -y php-fpm php-cli php-devel php-pear php-pdo php-mysqlnd \
    php-gd php-mbstring php-opcache php-zip php-bcmath php-json \
    php-process php-xml php-fpm gcc gcc-c++ make autoconf libtool 2>&1 | tail -8

echo "===== [4/4] 版本核对 ====="
php -v | head -2
php -m | tr '\n' ' ' | fold -w 160
echo
php-fpm -v 2>&1 | head -1
echo "STAGE1_OK"
