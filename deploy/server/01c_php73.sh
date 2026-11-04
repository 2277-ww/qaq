#!/bin/bash
# 阶段一（最终版）：装真正的 PHP 7.3（手写 remi-php73 仓库，卸掉 7.4）
set -e

echo "===== [1/5] 卸载 PHP 7.4 ====="
dnf remove -y 'php*' 2>&1 | tail -3

echo "===== [2/5] 写 remi-php73 仓库 ====="
cat > /etc/yum.repos.d/remi-php73.repo <<'EOF'
[remi-php73]
name=Remi's PHP 7.3 RPM repository for Enterprise Linux 8 - x86_64
baseurl=https://rpms.remirepo.net/enterprise/8/php73/x86_64/
enabled=1
gpgcheck=1
gpgkey=https://rpms.remirepo.net/RPM-GPG-KEY-remi
module_hotfixes=1
EOF
dnf clean all >/dev/null 2>&1 || true

echo "===== [3/5] 确认仓库内 PHP 版本 ====="
dnf --disablerepo=remi --disablerepo=remi-modular list available php 2>/dev/null | tail -3

echo "===== [4/5] 安装 PHP 7.3 ====="
dnf install -y --disablerepo=remi --disablerepo=remi-modular --allowerasing \
    php-fpm php-cli php-devel php-pdo php-mysqlnd \
    php-gd php-mbstring php-opcache php-zip php-bcmath php-json \
    php-process php-xml php-pecl-zip 2>&1 | tail -12

echo "===== [5/5] 版本核对 ====="
php -v | head -2
php -m | tr '\n' ' '
echo
php-fpm -v 2>&1 | head -1
echo "STAGE1_OK"
