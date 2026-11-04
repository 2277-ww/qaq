#!/bin/bash
# 阶段一（修正版）：PHP 7.3，绕开 remi-release 的虚拟依赖
set -e
echo "===== [1/5] 下载 remi-release ====="
cd /root/ctc_deploy
curl -sSL -o remi-release.rpm https://rpms.remirepo.net/enterprise/remi-release-8.rpm
rpm -ivh --nodeps --replacepkgs remi-release.rpm 2>&1 | tail -3

echo "===== [2/5] 修正 releasever（Alinux 的 3 会拼出错误 URL）====="
for f in /etc/yum.repos.d/remi*.repo; do
    [ -f "$f" ] && sed -i 's/\$releasever/8/g' "$f" && echo "fixed $f"
done
dnf clean all >/dev/null 2>&1 || true

echo "===== [3/5] 探测 remi-php73 仓库 ====="
dnf --enablerepo=remi-php73 list available 2>/dev/null | grep -E "^php\.|^php-fpm\." | head -5

echo "===== [4/5] 安装 PHP 7.3 与编译工具链 ====="
dnf install -y --enablerepo=remi-php73 --enablerepo=remi \
    php php-fpm php-cli php-devel php-pear php-pdo php-mysqlnd \
    php-gd php-mbstring php-opcache php-zip php-bcmath php-json \
    php-process php-xml php-pecl-zip \
    gcc gcc-c++ make autoconf libtool libtool-ltdl-devel 2>&1 | tail -10

echo "===== [5/5] 版本核对 ====="
php -v | head -2
echo "--- 已加载扩展 ---"
php -m | tr '\n' ' '
echo
echo "STAGE1_OK"
