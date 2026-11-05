#!/bin/bash
#
# 08 —— 视频转码能力 + 证书看门狗 + 媒体防盗链
#
# 前置：01~07 已执行（nginx / php-fpm / 课程平台 / 视频上传已就绪）
# 幂等：可重复执行
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WEB_ROOT=/www/ctc

echo "== 1. ffmpeg =="
if command -v ffmpeg >/dev/null 2>&1; then
    echo "已安装：$(ffmpeg -version 2>/dev/null | head -1)"
else
    # Alinux 3 自身源没有 ffmpeg，用 rpmfusion（阿里云镜像）
    if [ ! -f /etc/yum.repos.d/rpmfusion-free-updates.repo ]; then
        dnf -y install https://mirrors.aliyun.com/rpmfusion/free/el/rpmfusion-free-release-8.noarch.rpm
    fi
    cat >/etc/yum.repos.d/ctc-rpmfusion.repo <<'EOF'
[rpmfusion-free-updates]
name=RPM Fusion free for EL 8 (aliyun)
baseurl=https://mirrors.aliyun.com/rpmfusion/free/el/updates/8/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-el-8
EOF
    sed -i 's/^enabled=1/enabled=0/' \
        /etc/yum.repos.d/rpmfusion-free-updates.repo \
        /etc/yum.repos.d/rpmfusion-free-updates-testing.repo 2>/dev/null || true
    dnf -y --setopt=install_weak_deps=0 install ffmpeg ffmpeg-libs
    ffmpeg -version | head -1
fi

echo "== 2. 媒体目录与状态目录 =="
install -d -o apache -g apache -m 0775 /www/media/vod /www/media/tmp
install -d -m 0755 /var/www/acme-status /var/log/ctc

echo "== 3. 证书看门狗 =="
install -m 0755 "$HERE/cert/ctc-cert-watch.sh" /usr/local/bin/ctc-cert-watch.sh
if [ ! -f /etc/ctc/alert.conf ]; then
    install -d -m 0755 /etc/ctc
    install -m 0600 "$HERE/cert/alert.conf.example" /etc/ctc/alert.conf
fi
cat >/etc/cron.d/ctc-cert-watch <<'EOF'
# 证书看门狗：在 acme.sh 每次续期尝试（3/9/15/21 点）之后复查
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
17 4,10,16,22 * * * root /usr/local/bin/ctc-cert-watch.sh >/dev/null 2>&1
EOF
chmod 0644 /etc/cron.d/ctc-cert-watch
/usr/local/bin/ctc-cert-watch.sh || true

echo "== 4. nginx 配置（防盗链 + 证书状态端点）=="
install -m 0644 "$HERE/video-upload/ctc.conf" /etc/nginx/conf.d/ctc.conf
install -m 0644 "$HERE/video-upload/ctc-ssl.conf" /etc/nginx/conf.d/ctc-ssl.conf
nginx -t
systemctl reload nginx

echo "== 5. 自检 =="
curl -sk -o /dev/null -w 'https 首页 %{http_code}\n' https://8.138.34.151/
curl -s -o /dev/null -w '证书状态 %{http_code}\n' --resolve 8.138.34.151:443:127.0.0.1 https://8.138.34.151/_status/cert.txt
cat /var/www/acme-status/cert.txt
echo "完成"
