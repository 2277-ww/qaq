#!/bin/bash
#
# ctc-backup.sh —— 每日备份（数据库 + 教学视频）
#
# 数据库：/www/backup/ctc-YYYYmmdd-HHMM.sql.gz          保留 7 天
# 视频：  /www/backup/vod/YYYY-MM-DD/                   保留 7 份，硬链接快照
#
# 视频用 rsync --link-dest 做硬链接快照：同一分区内未变更的文件只增加一个目录项，
# 不复制数据，所以 1.3G 视频留 7 份也几乎不占额外空间（du 会去重硬链接）。
#
# 异地同步（可选）：在 /etc/ctc/backup.conf 里配置
#   REMOTE_TARGET="user@host:/path"      或  "oss://bucket/ctc"（需 ossutil 封装）
# 配置后每次备份完成会 rsync 一份过去。
#
# 手动执行：/usr/local/bin/ctc-backup.sh

set -uo pipefail

D=/www/backup
VOD=/www/media/vod
SNAP=$D/vod
LOG=$D/backup.log
CONF=/etc/ctc/backup.conf

KEEP_DAYS=7
KEEP_SNAPSHOTS=7

mkdir -p "$D" "$SNAP"

# rsync 是视频增量快照的前提，缺了会静默跳过，必须显式拦下
if ! command -v rsync >/dev/null 2>&1; then
    echo "$(date '+%F %T') FAIL 未安装 rsync，视频快照未执行（dnf install -y rsync）" >>"$LOG"
    exit 1
fi

ts=$(date +%Y%m%d-%H%M)
F="$D/ctc-$ts.sql.gz"

# ---------- 1. 数据库 ----------
if mariadb-dump --defaults-file=/root/.ctc_backup.cnf \
        --single-transaction --routines --triggers --events ctc \
        2>"$D/.dump.err" | gzip > "$F.tmp"; then
    mv "$F.tmp" "$F"
else
    echo "$(date '+%F %T') FAIL db dump: $(tail -1 "$D/.dump.err" 2>/dev/null)" >>"$LOG"
    rm -f "$F.tmp"
    exit 1
fi

if ! gzip -t "$F" 2>/dev/null; then
    echo "$(date '+%F %T') FAIL db dump 损坏: $F" >>"$LOG"
    exit 1
fi

# ---------- 2. 视频快照 ----------
today="$SNAP/$(date +%F)"

prev=$(ls -1d "$SNAP"/20* 2>/dev/null | sort | grep -v "^${today}$" | tail -1)

mkdir -p "$today"

if [ -n "$prev" ]; then
    # 增量：未变更文件硬链接到上一份，变更文件才复制
    if ! rsync -a --delete --link-dest="$prev" "$VOD/" "$today/" 2>>"$LOG"; then
        echo "$(date '+%F %T') FAIL 视频快照 rsync 失败（prev=$prev）" >>"$LOG"
        exit 1
    fi
else
    # 首份：直接硬链接整棵树，瞬间完成、不占额外空间
    cp -al "$VOD/." "$today/" 2>/dev/null || rsync -a "$VOD/" "$today/"
fi

# ---------- 3. 保留策略 ----------
ls -1d "$SNAP"/20* 2>/dev/null | sort | head -n -"$KEEP_SNAPSHOTS" | while IFS= read -r old; do
    rm -rf "$old"
done

find "$D" -maxdepth 1 -name 'ctc-*.sql.gz' -mtime +"$KEEP_DAYS" -delete

# ---------- 4. 记账 ----------
db_size=$(du -h "$F" 2>/dev/null | cut -f1)
vod_size=$(du -sh "$VOD" 2>/dev/null | cut -f1)
snap_total=$(du -sh "$SNAP" 2>/dev/null | cut -f1)
snap_count=$(ls -1d "$SNAP"/20* 2>/dev/null | wc -l)

echo "$(date '+%F %T') backup ok db=$db_size vod=$vod_size snapshots=$snap_count($snap_total)" >>"$LOG"

# ---------- 5. 异地（可选） ----------
if [ -f "$CONF" ]; then
    # shellcheck disable=SC1090
    . "$CONF"

    if [ -n "${REMOTE_TARGET:-}" ]; then
        # 默认只同步数据库：视频快照是硬链接，rsync 到远端会被展开成完整文件
        if rsync -a "$D"/ctc-*.sql.gz "$REMOTE_TARGET"/ >>"$LOG" 2>&1; then
            echo "$(date '+%F %T') remote db sync ok -> $REMOTE_TARGET" >>"$LOG"
        else
            echo "$(date '+%F %T') FAIL remote db sync -> $REMOTE_TARGET" >>"$LOG"
        fi
    fi

    if [ -n "${REMOTE_VOD_TARGET:-}" ]; then
        if rsync -a --delete "$VOD/" "$REMOTE_VOD_TARGET"/ >>"$LOG" 2>&1; then
            echo "$(date '+%F %T') remote vod sync ok -> $REMOTE_VOD_TARGET" >>"$LOG"
        else
            echo "$(date '+%F %T') FAIL remote vod sync -> $REMOTE_VOD_TARGET" >>"$LOG"
        fi
    fi
fi

exit 0
