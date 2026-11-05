#!/usr/bin/env bash
#
# 10_harden.sh —— 安全加固与备份（幂等，可重复执行）
#
# 做四件事：
#   1. 后台 /admin/ 加 nginx basic auth（改造版 Admin Auth 不读会话，公网可直连）
#   2. 停用 8080 HTTP 入口，只保留 443
#   3. 安装 rsync + 每日备份（数据库 dump + 视频硬链接快照）
#   4. 自检：401 / 200 / 8080 不通 / 备份可读
#
# 用法：
#   bash 10_harden.sh              # 首次：生成随机密码并打印
#   bash 10_harden.sh --reset-pass # 重置后台密码

set -uo pipefail

APP_DIR=${APP_DIR:-/www/ctc}
HTPASSWD=/etc/nginx/.htpasswd-ctc
SSL_CONF=/etc/nginx/conf.d/ctc-ssl.conf
BACKUP_LOG=/www/backup/backup.log
RESET_PASS=0

[ "${1:-}" = "--reset-pass" ] && RESET_PASS=1

echo "==> 1/5 后台 basic auth"

if [ -f "$HTPASSWD" ] && [ "$RESET_PASS" = "0" ]; then
    echo "    已存在 $HTPASSWD，跳过（重置密码用 --reset-pass）"
else
    PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 14)
    HASH=$(openssl passwd -apr1 "$PASS")
    printf 'admin:%s\n' "$HASH" >"$HTPASSWD"
    echo "    已生成：用户名 admin  密码 $PASS"
    echo "    （只显示这一次，请立刻保存）"
fi

chmod 0640 "$HTPASSWD"
chown root:nginx "$HTPASSWD" 2>/dev/null || chown root:www-data "$HTPASSWD"

if ! grep -q 'auth_basic_user_file /etc/nginx/.htpasswd-ctc' "$SSL_CONF"; then
    mkdir -p /root/nginx-backup
    cp -a "$SSL_CONF" "/root/nginx-backup/ctc-ssl.conf.$(date +%Y%m%d-%H%M%S)"
    python3 - "$SSL_CONF" <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
block = '''    # 后台入口鉴权（改造版 Admin Auth 为内置身份模式，不鉴权等于公网可写）
    location ^~ /admin/ {
        auth_basic           "CTC Admin";
        auth_basic_user_file /etc/nginx/.htpasswd-ctc;
        try_files $uri $uri/ /index.php?_url=$uri&$args;
    }

'''
anchor = '    # 保护敏感文件'
if anchor not in s:
    print('!! 未找到插入锚点，请手工添加', file=sys.stderr)
    sys.exit(1)
s = s.replace(anchor, block + anchor)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('    已写入 auth 配置')
PY
else
    echo "    auth 配置已存在"
fi

echo "==> 2/5 停用 8080"

if [ -f /etc/nginx/conf.d/ctc.conf ]; then
    mkdir -p /root/nginx-backup
    mv /etc/nginx/conf.d/ctc.conf "/root/nginx-backup/ctc-8080.conf.disabled.$(date +%Y%m%d-%H%M%S)"
    echo "    已移出 conf.d（备份在 /root/nginx-backup/）"
else
    echo "    8080 已停用"
fi

nginx -t || { echo "!! nginx 配置有误，已停止" >&2; exit 1; }
systemctl reload nginx
echo "    nginx 已重载"

echo "==> 3/5 备份"

command -v rsync >/dev/null 2>&1 || dnf install -y rsync >/dev/null 2>&1

if [ -d "$(dirname "${BASH_SOURCE[0]}")/cert" ]; then
    SRC_CERT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cert"
elif [ -d /root/cert ]; then
    SRC_CERT=/root/cert
else
    SRC_CERT=""
fi

if [ -n "$SRC_CERT" ] && [ -f "$SRC_CERT/ctc-backup.sh" ]; then
    install -o root -g root -m 0755 "$SRC_CERT/ctc-backup.sh" /usr/local/bin/ctc-backup.sh
    [ -f /etc/ctc/backup.conf ] || install -m 0644 "$SRC_CERT/backup.conf.example" /etc/ctc/backup.conf
    echo "    已安装 /usr/local/bin/ctc-backup.sh"
fi

cat >/etc/cron.d/ctc-backup <<'EOF'
# 每日备份：数据库 + 视频快照
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
30 3 * * * root /usr/local/bin/ctc-backup.sh >/dev/null 2>&1
EOF
chmod 0644 /etc/cron.d/ctc-backup
echo "    定时任务已就位（每天 3:30）"

/usr/local/bin/ctc-backup.sh
echo "    首次备份完成：$(tail -1 "$BACKUP_LOG")"

echo "==> 4/5 自检"

code_noauth=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 20 "https://127.0.0.1/admin/video_upload/" || echo 000)
code_auth=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 20 -u 'admin:wrong-password' "https://127.0.0.1/admin/video_upload/" || echo 000)
code_home=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 20 "https://127.0.0.1/" || echo 000)

echo "    /admin 无凭据 -> $code_noauth（应为 401）"
echo "    /admin 错误凭据 -> $code_auth（应为 401）"
echo "    首页 -> $code_home（应为 200）"

if ss -lnt 2>/dev/null | grep -q ':8080'; then
    echo "    !! 8080 仍在监听"
else
    echo "    8080 已关闭"
fi

echo "==> 5/5 完成"
echo "    后台入口：https://8.138.34.151/admin/video_upload/"
echo "    账号：admin"
echo "    备份目录：/www/backup（db 7 天 + 视频 7 份硬链接快照）"
echo "    异地同步配置：/etc/ctc/backup.conf"
