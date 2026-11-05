#!/bin/bash
# 重置后台 basic auth 密码，并把新密码写入只有 root 可读的记录文件
set -euo pipefail

HTPASSWD=/etc/nginx/.htpasswd-ctc
RECORD=/root/ctc_admin_pass.txt

mkdir -p /root/nginx-backup
cp -a "$HTPASSWD" "/root/nginx-backup/htpasswd-ctc.$(date +%Y%m%d-%H%M%S)"

# 注意：不要用 tr | head 取随机串。head 提前关闭管道会让 tr 收到 SIGPIPE，
# 在 set -o pipefail 下整条命令失败，set -e 直接退出，脚本静默中止。
PASS=$(openssl rand -hex 7)
HASH=$(openssl passwd -apr1 "$PASS")

printf 'admin:%s\n' "$HASH" > "$HTPASSWD"
chmod 0640 "$HTPASSWD"
chown root:nginx "$HTPASSWD"

umask 077
printf 'url=https://8.138.34.151/admin/\nuser=admin\npass=%s\nreset_at=%s\n' \
    "$PASS" "$(date -Iseconds)" > "$RECORD"
chmod 0600 "$RECORD"

systemctl reload nginx
sleep 1

echo "ADMIN_USER=admin"
echo "ADMIN_PASS=$PASS"
printf 'with_cred=%s ' "$(curl -sk -o /dev/null -w '%{http_code}' -u "admin:$PASS" https://127.0.0.1/admin/video_upload/)"
printf 'wrong_cred=%s ' "$(curl -sk -o /dev/null -w '%{http_code}' -u 'admin:wrong' https://127.0.0.1/admin/video_upload/)"
printf 'no_cred=%s\n' "$(curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1/admin/video_upload/)"
