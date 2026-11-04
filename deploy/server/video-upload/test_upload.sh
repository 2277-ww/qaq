#!/bin/bash
# 通过真实 HTTP 接口测试分片上传全流程
# 用法: bash test_upload.sh <本地视频路径> <course_id>

set -u

BASE=http://127.0.0.1:8080
SRC="$1"
COURSE="${2:-1}"
JAR=/tmp/ck_upload.txt
WORK=/tmp/upload_test

rm -rf $WORK $JAR
mkdir -p $WORK

SIZE=$(stat -c%s "$SRC")
NAME=$(basename "$SRC")

echo "文件: $NAME  大小: $SIZE 字节  课程: $COURSE"

# 1. 取 CSRF token（同时建立会话）
TOKEN=$(curl -s -c $JAR -b $JAR "$BASE/admin/video_upload/" \
    | grep -o 'name="csrf-token" content="[^"]*"' | head -1 | sed 's/.*content="//; s/"$//')
echo "csrf: ${TOKEN:0:16}..."

HDR=(-H "X-Csrf-Token: $TOKEN" -H "Referer: $BASE/admin/video_upload/")

# 2. init
INIT=$(curl -s -c $JAR -b $JAR "${HDR[@]}" \
    -F "course_id=$COURSE" -F "filename=$NAME" -F "size=$SIZE" \
    "$BASE/admin/video_upload/init")
echo "init -> $INIT"

read -r UPLOAD_ID CHUNK_SIZE TOTAL <<< $(echo "$INIT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('upload_id',''), d.get('chunk_size',0), d.get('total_chunks',0))
")

if [ -z "$UPLOAD_ID" ]; then
    echo "FAIL: 未拿到 upload_id"
    exit 1
fi

echo "upload_id=$UPLOAD_ID  chunk=$CHUNK_SIZE  总片数=$TOTAL"

# 3. 切片
split -b "$CHUNK_SIZE" -d -a 3 "$SRC" $WORK/part_
PARTS=$(ls $WORK/part_* | wc -l)
echo "实际切出 $PARTS 片"

# 4. 逐片上传
i=0
for f in $WORK/part_*; do
    R=$(curl -s -c $JAR -b $JAR "${HDR[@]}" \
        -F "upload_id=$UPLOAD_ID" -F "index=$i" -F "chunk=@$f" \
        "$BASE/admin/video_upload/chunk")
    CODE=$(echo "$R" | grep -o '"code":[0-9]*' | head -1)
    if [ "$CODE" != '"code":0' ]; then
        echo "FAIL 第 $i 片: $R"
        exit 1
    fi
    i=$((i+1))
done
echo "分片全部送达"

# 5. finish
FIN=$(curl -s -c $JAR -b $JAR "${HDR[@]}" \
    -F "upload_id=$UPLOAD_ID" "$BASE/admin/video_upload/finish")
echo "finish -> $FIN"

URL=$(echo "$FIN" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('url',''))
")

if [ -z "$URL" ]; then
    echo "FAIL: 未拿到播放地址"
    exit 1
fi

# 6. 验证可访问性与大小
echo "--- 校验 $URL ---"
curl -s -o /dev/null -w 'HTTP %{http_code}  %{size_download} 字节  %{content_type}\n' \
    --max-time 30 "$BASE$URL"

echo "期望大小: $SIZE"
echo "URL=$URL"
