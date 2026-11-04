#!/bin/sh
# 容器入口：准备可写目录 → 起 php-fpm → 前台跑 nginx
# Vercel 在 5 分钟无流量后缩容，缩容时发 SIGTERM，nginx 会优雅退出。
set -eu

# 只读根文件系统，唯一可写区是 /tmp（上限 500MB）
mkdir -p /tmp/cache/volt \
         /tmp/cache/annotations \
         /tmp/cache/metadata \
         /tmp/cache/purifier \
         /tmp/log

chown -R www-data:www-data /tmp/cache /tmp/log 2>/dev/null || true

# PHP 侧确认扩展齐备，缺一个就直接失败，避免带病起服务
php -m | grep -qi 'phalcon'  || { echo '[fatal] phalcon extension missing' >&2; exit 1; }
php -m | grep -qi 'redis'    || { echo '[fatal] redis extension missing'   >&2; exit 1; }
php -m | grep -qi 'igbinary' || { echo '[fatal] igbinary extension missing' >&2; exit 1; }

echo "[boot] region=${VERCEL_REGION:-local} app_env=${APP_ENV:-production}"

php-fpm --nodaemonize --fpm-config /usr/local/etc/php-fpm.conf &
FPM_PID=$!

trap 'kill -TERM "$FPM_PID" 2>/dev/null || true' TERM INT

nginx -g 'daemon off;'
