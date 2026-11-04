#!/bin/bash
# 修复存量播放地址：把开发机地址换成本站相对路径
# 本地 public/static/vod/<slug>/x.mp4 -> /www/media/vod/<slug>/x.mp4 -> URL /media/vod/<slug>/x.mp4
# 使用 root 本地 socket 认证，避免密码在命令行暴露

MYSQL="mariadb -uroot ctc"

echo "=== 修复前 ==="
printf '总记录: '
$MYSQL -N -e "SELECT COUNT(*) FROM kg_chapter_vod;"
printf '含开发地址: '
$MYSQL -N -e "SELECT COUNT(*) FROM kg_chapter_vod WHERE file_remote LIKE '%127.0.0.1%';"

echo "=== 执行替换 ==="
$MYSQL -e "UPDATE kg_chapter_vod
           SET file_remote = REPLACE(file_remote, 'http://127.0.0.1:8000/static/vod/', '/media/vod/')
           WHERE file_remote LIKE '%127.0.0.1:8000/static/vod/%';"

echo "=== 修复后 ==="
printf '仍含开发地址: '
$MYSQL -N -e "SELECT COUNT(*) FROM kg_chapter_vod WHERE file_remote LIKE '%127.0.0.1%';"

echo "=== 抽样 ==="
$MYSQL -N -e "SELECT chapter_id, LEFT(file_remote, 100) FROM kg_chapter_vod ORDER BY id LIMIT 3;"

echo "=== 校验地址对应的文件是否存在 ==="
MISS=0
TOTAL=0
for url in $($MYSQL -N -e "SELECT file_remote FROM kg_chapter_vod;" | grep -o '/media/vod/[^"]*'); do
    TOTAL=$((TOTAL+1))
    path="/www/media/vod/${url#/media/vod/}"
    if [ ! -f "$path" ]; then
        MISS=$((MISS+1))
        echo "  缺失: $url"
    fi
done
echo "共 $TOTAL 个地址，缺失 $MISS 个"
