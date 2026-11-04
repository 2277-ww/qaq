#!/bin/bash
# 阶段五：收尾（清理探针、数据库备份、运维脚本）
set -e

echo "===== [1/4] 清理调试文件 ====="
rm -f /www/ctc/public/_probe.php /tmp/diag.php /tmp/diag_run.php /tmp/run.php /tmp/diag.out /tmp/ap.log /tmp/ap2.log
echo "已清理"

echo "===== [2/4] 数据库每日备份 ====="
# 备份账号密码放到只有 root 可读的文件
cat > /root/.ctc_backup.cnf <<'EOF'
[client]
user=root
password=
default-character-set=utf8mb4
EOF
chmod 600 /root/.ctc_backup.cnf
mkdir -p /www/backup
cat > /usr/local/bin/ctc-backup.sh <<'EOF'
#!/bin/bash
# 每日备份 ctc 库，保留最近 7 天
set -e
D=/www/backup
mkdir -p "$D"
F="$D/ctc-$(date +%Y%m%d-%H%M).sql.gz"
mariadb-dump --defaults-file=/root/.ctc_backup.cnf --single-transaction --routines --triggers ctc | gzip > "$F"
find "$D" -name 'ctc-*.sql.gz' -mtime +7 -delete
echo "$(date '+%F %T') backup ok $(du -h "$F" | cut -f1)" >> "$D/backup.log"
EOF
chmod 755 /usr/local/bin/ctc-backup.sh
echo "30 3 * * * /usr/local/bin/ctc-backup.sh" > /etc/cron.d/ctc-backup
chmod 644 /etc/cron.d/ctc-backup
/usr/local/bin/ctc-backup.sh
ls -lh /www/backup/ | tail -3

echo "===== [3/4] 一键运维脚本 ====="
cat > /root/ctc_deploy/ops.sh <<'EOF'
#!/bin/bash
# 用法: ops.sh {status|restart|logs|smoke}
APP=/www/ctc
case "$1" in
  status)
    for s in nginx php-fpm mariadb redis; do printf "%-10s %s\n" "$s" "$(systemctl is-active $s)"; done
    echo "--- 端口 ---"; ss -lntp | grep -E ':8080|:3306|:6379' | awk '{print $4}'
    echo "--- 资源 ---"; free -m | sed -n 2p
    ;;
  restart)
    systemctl restart nginx php-fpm mariadb redis && echo "已重启全部服务"
    ;;
  logs)
    tail -n 50 /var/log/nginx/ctc.error.log
    tail -n 30 /var/log/php-fpm/www-error.log
    ;;
  smoke)
    for u in / /course/list /admin /course/1 /article/list; do
      printf "%-16s " "$u"
      curl -s -o /dev/null -w "%{http_code}\n" --max-time 30 "http://127.0.0.1:8080$u"
    done
    ;;
  *)
    echo "用法: ops.sh {status|restart|logs|smoke}"
    ;;
esac
EOF
chmod +x /root/ctc_deploy/ops.sh
/root/ctc_deploy/ops.sh status

echo "===== [4/4] 冒烟复测 ====="
/root/ctc_deploy/ops.sh smoke
echo "STAGE5_OK"
