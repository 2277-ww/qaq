#!/bin/bash
# 阶段一（最终4）：改用阿里云 remi 镜像，避免拉国外源
set -e

pkill -f '01f.sh' 2>/dev/null || true
pkill -f 'dnf install' 2>/dev/null || true
sleep 2

echo "===== [1/5] 指向阿里云 remi 镜像 ====="
cat > /etc/yum.repos.d/remi-php73.repo <<'EOF'
[remi-php73]
name=Remi PHP 7.3 (aliyun mirror)
baseurl=https://mirrors.aliyun.com/remi/enterprise/8/php73/x86_64/
enabled=1
gpgcheck=0
module_hotfixes=1
EOF
cat > /etc/yum.repos.d/remi-safe.repo <<'EOF'
[remi-safe]
name=Remi Safe (aliyun mirror)
baseurl=https://mirrors.aliyun.com/remi/enterprise/8/safe/x86_64/
enabled=1
gpgcheck=0
module_hotfixes=1
EOF
# 关掉用不到的外国源
for r in epel-testing epel-testing-modular remi remi-modular; do
    dnf config-manager --set-disabled "$r" >/dev/null 2>&1 || true
done
curl -s -o /dev/null -w "aliyun remi-php73: %{http_code} %{speed_download}B/s\n" --max-time 20 \
    https://mirrors.aliyun.com/remi/enterprise/8/php73/x86_64/repodata/repomd.xml

echo "===== [2/5] 清缓存 ====="
dnf clean all >/dev/null 2>&1 || true

echo "===== [3/5] 安装 PHP 7.3 ====="
dnf install -y \
    --disablerepo='*' --enablerepo='alinux3-*' --enablerepo=epel \
    --enablerepo=remi-safe --enablerepo=remi-php73 \
    --setopt=timeout=60 --setopt=retries=1 --setopt=minrate=1000 --allowerasing \
    php-fpm php-cli php-devel php-pdo php-mysqlnd \
    php-gd php-mbstring php-opcache php-zip php-bcmath php-json \
    php-process php-xml 2>&1 | tail -20

echo "===== [4/5] 版本核对 ====="
php -v | head -2
echo "===== [5/5] 扩展 ====="
php -m | tr '\n' ' '
echo
php-fpm -v 2>&1 | head -1
echo "STAGE1_OK"
