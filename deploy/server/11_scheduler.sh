#!/usr/bin/env bash
#
# 11_scheduler.sh —— 常驻调度器（scheduler.php）安装与自检
#
# 背景：
#   本平台部署时漏掉了 scheduler.php 的运行方式，导致 exam_sync / sync_learning /
#   deliver / notice 等任务从未执行（学习进度事件只是"入箱"，无人投递）。
#   同时 scheduler.php 里 $bin 写死 /usr/local/bin/php，而本机 php 在 /usr/bin/php，
#   即便配了 cron 也会因找不到解释器而静默失败。
#
#   本脚本做四件事：
#     1. 修正 $bin 路径
#     2. 停用三个 XunSearch 索引任务（搜索已改为 MySQL LIKE，XunSearch 未部署，
#        这三个任务每小时抛 "Missing field of type ID"）
#     3. 安装 /etc/cron.d/ctc-scheduler（每分钟拉起，flock 防重入）
#     4. 自检：语法、单轮执行、cron 触发
#
# 用法：bash 11_scheduler.sh
# 幂等：可重复执行。
#
set -uo pipefail

APP_DIR=${APP_DIR:-/www/ctc}
PHP_BIN=${PHP_BIN:-/usr/bin/php}
CRON_FILE=${CRON_FILE:-/etc/cron.d/ctc-scheduler}
LOG_FILE=${LOG_FILE:-/var/log/ctc-scheduler.log}

log() { printf '\n=== %s ===\n' "$*"; }

[ "$(id -u)" = "0" ] || { echo "需要 root 执行"; exit 1; }

# ---------- 1. 前置检查 ----------
log "前置检查"
[ -x "$PHP_BIN" ] || { echo "找不到 $PHP_BIN"; exit 1; }
"$PHP_BIN" -r 'exit(extension_loaded("phalcon") ? 0 : 1);' \
    || { echo "php 缺少 phalcon 扩展"; exit 1; }
echo "php  : $("$PHP_BIN" -v | head -1)"
echo "phalcon: $("$PHP_BIN" -r 'echo Phalcon\Version::get();')"

# ---------- 2. 修正 scheduler.php ----------
log "修正 scheduler.php"
if grep -q "'/usr/local/bin/php'" "$APP_DIR/scheduler.php"; then
    cp -a "$APP_DIR/scheduler.php" "/root/scheduler.php.bak.$(date +%Y%m%d%H%M%S)"
    sed -i "s#'/usr/local/bin/php'#'$PHP_BIN'#" "$APP_DIR/scheduler.php"
    echo "已把 \$bin 改为 $PHP_BIN"
else
    echo "\$bin 已是 $PHP_BIN（跳过）"
fi

# 停用 XunSearch 索引任务：整块注释掉，保留原行便于以后恢复
for t in sync_course_index sync_article_index sync_question_index; do
    if grep -q "^\$scheduler->php(\$script, \$bin, \['--task' => '$t'" "$APP_DIR/scheduler.php"; then
        sed -i "/'--task' => '$t', '--action' => 'main'\])/{
            N
            s#.*#// [停用 $t] 搜索已改为 MySQL LIKE，XunSearch 未部署，该任务会抛 Missing field of type ID#
        }" "$APP_DIR/scheduler.php"
        echo "已停用 $t"
    else
        echo "$t 已停用（跳过）"
    fi
done

"$PHP_BIN" -l "$APP_DIR/scheduler.php" || exit 1

# ---------- 3. 安装 cron 与日志轮转 ----------
log "安装 cron"
install -o root -g root -m 644 /dev/stdin "$CRON_FILE" <<'CRON'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# 酷瓜云课堂：常驻调度器（GO\Scheduler 每次调用只执行到期任务后退出，需每分钟拉起）
# flock 防止上一轮未结束时重入；timeout 兜底，避免个别任务卡死拖住整轮
* * * * * root cd /www/ctc && flock -n /var/lock/ctc-scheduler.lock timeout 300 /usr/bin/php scheduler.php >> /var/log/ctc-scheduler.log 2>&1
CRON

install -o root -g root -m 644 /dev/stdin /etc/logrotate.d/ctc-scheduler <<'LOGROTATE'
/var/log/ctc-scheduler.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    copytruncate
}
LOGROTATE

touch "$LOG_FILE"; chmod 644 "$LOG_FILE"
systemctl is-active crond >/dev/null || systemctl start crond
echo "cron: $(systemctl is-active crond)"

# ---------- 4. 自检 ----------
log "单轮执行自检"
cd "$APP_DIR" || exit 1
"$PHP_BIN" scheduler.php && echo "scheduler.php 退出码 0"
sleep 3
running=$(ps -eo cmd | grep -c '[c]onsole.php')
echo "尚有 $running 个子任务在跑（0 也正常，任务很快）"

log "等待下一次 cron 触发（最多 70 秒）"
before=$(grep -c ctc-scheduler /var/log/cron 2>/dev/null || echo 0)
for _ in $(seq 1 14); do
    sleep 5
    now=$(grep -c ctc-scheduler /var/log/cron 2>/dev/null || echo 0)
    [ "$now" -gt "$before" ] && { echo "cron 已触发（累计 $now 次）"; break; }
done
grep ctc-scheduler /var/log/cron 2>/dev/null | tail -2

log "完成"
echo "查看日志：tail -f $LOG_FILE"
echo "手动跑一轮：cd $APP_DIR && $PHP_BIN scheduler.php"
