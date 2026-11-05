#!/usr/bin/env bash
#
# 09_search_db.sh —— 把前台搜索从 XunSearch 切换到 MySQL
#
# 背景：前台 /search 依赖 XunSearch 服务端（xs-searchd:8383）与预建索引，
#       本机未安装该服务，且 config/ 下只有 xs.*.default.ini、没有代码要求的
#       xs.*.ini，任何搜索都会抛异常跳 /error/500。
#       改为直接查 MySQL（按标题/摘要/关键词/标签 LIKE），无需外部服务。
#
# 用法：
#   bash 09_search_db.sh                 # 使用脚本同目录下的 search/ 作为源
#   bash 09_search_db.sh /root/search    # 指定源目录（内含 app/Services/Logic/Search/*.php）
#
# 幂等，可重复执行。

set -euo pipefail

APP_DIR="${APP_DIR:-/www/ctc}"
SRC_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/search}"
DEST_DIR="$APP_DIR/app/Services/Logic/Search"

FILES=(Handler Course Article Question)

echo "==> 源目录：$SRC_DIR"
echo "==> 目标目录：$DEST_DIR"

if [ ! -d "$SRC_DIR/app/Services/Logic/Search" ]; then
    echo "!! 源目录结构不对，缺少 app/Services/Logic/Search" >&2
    exit 1
fi

# 备份原文件（仅首次，保留可回滚）
mkdir -p /root/ctc_search_backup

for name in "${FILES[@]}"; do
    src="$SRC_DIR/app/Services/Logic/Search/$name.php"
    dest="$DEST_DIR/$name.php"

    if [ ! -f "$src" ]; then
        echo "!! 缺少 $src" >&2
        exit 1
    fi

    if [ -f "$dest" ] && [ ! -f "/root/ctc_search_backup/$name.php.orig" ]; then
        cp -a "$dest" "/root/ctc_search_backup/$name.php.orig"
        echo "   已备份原文件 -> /root/ctc_search_backup/$name.php.orig"
    fi

    install -o apache -g apache -m 0644 "$src" "$dest"
    php -l "$dest" >/dev/null
    echo "   ok  $name.php"
done

# 模板未改动，但搜索页依赖的 pager 结构变了，清一次编译缓存最稳妥
rm -rf "$APP_DIR/storage/cache/volt/"* 2>/dev/null || true

systemctl restart php-fpm
echo "==> php-fpm 已重启"

sleep 1

# 自检：走 443 回环（8080 已于 2026-11-05 停用，证书是 IP 证书用 -k 跳过校验）
code=$(curl -sk -o /tmp/ctc_search_check.html -w '%{http_code}' \
    --max-time 20 "https://127.0.0.1/search/?query=python" || echo 000)

hits=$(grep -c 'search-course-card' /tmp/ctc_search_check.html 2>/dev/null || true)

echo "==> 自检：HTTP $code，命中卡片 $hits"

if [ "$code" != "200" ]; then
    echo "!! 自检失败，请查看 /www/ctc/storage/logs 与 /var/log/nginx/ctc.error.log" >&2
    exit 1
fi

echo "==> 完成。搜索地址：https://<域名或IP>/search/?query=关键词"
