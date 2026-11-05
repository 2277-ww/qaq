#!/bin/bash
# 转码链路端到端测试：上传 HEVC 视频 → 触发后台转码 → 轮询到完成 → 校验产物编码
# 用法: bash test_transcode.sh [视频路径] [course_id]
# 不传视频则用 ffmpeg 现场生成 6 秒 HEVC 样片

set -u

BASE=http://127.0.0.1:8080
SRC="${1:-/tmp/hevc_sample.mp4}"
COURSE="${2:-1}"
JAR=/tmp/ck_transcode.txt
WORK=/tmp/transcode_test

if [ ! -f "$SRC" ]; then
    echo "生成 HEVC 样片 $SRC"
    ffmpeg -hide_banner -loglevel error -y \
        -f lavfi -i testsrc2=size=640x360:rate=25:duration=6 \
        -f lavfi -i sine=frequency=440:duration=6 \
        -c:v libx265 -preset ultrafast -tag:v hvc1 -c:a aac -b:a 96k "$SRC" || exit 1
fi

echo "源文件编码："
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height -of csv=p=0 "$SRC"

rm -rf $WORK $JAR
mkdir -p $WORK

SIZE=$(stat -c%s "$SRC")
NAME=$(basename "$SRC")

TOKEN=$(curl -s -c $JAR -b $JAR "$BASE/admin/video_upload/" \
    | grep -o 'name="csrf-token" content="[^"]*"' | head -1 | sed 's/.*content="//; s/"$//')
[ -n "$TOKEN" ] || { echo "FAIL: 未取到 csrf token（登录态失效？）"; exit 1; }

HDR=(-H "X-Csrf-Token: $TOKEN" -H "Referer: $BASE/admin/video_upload/")

INIT=$(curl -s -c $JAR -b $JAR "${HDR[@]}" \
    -F "course_id=$COURSE" -F "filename=$NAME" -F "size=$SIZE" \
    "$BASE/admin/video_upload/init")
echo "init -> $INIT"

read -r UPLOAD_ID CHUNK_SIZE TOTAL <<< $(echo "$INIT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('upload_id',''), d.get('chunk_size',0), d.get('total_chunks',0))
")
[ -n "$UPLOAD_ID" ] || { echo "FAIL: 未拿到 upload_id"; exit 1; }

split -b "$CHUNK_SIZE" -d -a 3 "$SRC" $WORK/part_
i=0
for f in $WORK/part_*; do
    R=$(curl -s -c $JAR -b $JAR "${HDR[@]}" \
        -F "upload_id=$UPLOAD_ID" -F "index=$i" -F "chunk=@$f" \
        "$BASE/admin/video_upload/chunk")
    echo "$R" | grep -q '"code":0' || { echo "FAIL 第 $i 片: $R"; exit 1; }
    i=$((i+1))
done

FIN=$(curl -s -c $JAR -b $JAR "${HDR[@]}" \
    -F "upload_id=$UPLOAD_ID" "$BASE/admin/video_upload/finish")
echo "finish -> $FIN"

state=$(echo "$FIN" | python3 -c "import sys,json;print(json.load(sys.stdin).get('state',''))")
echo "首轮状态: $state"

# 转码中则轮询（finish 兼作进度查询）
n=0
while [ "$state" = "transcoding" ] && [ $n -lt 40 ]; do
    sleep 3
    n=$((n+1))
    FIN=$(curl -s -c $JAR -b $JAR "${HDR[@]}" \
        -F "upload_id=$UPLOAD_ID" "$BASE/admin/video_upload/finish")
    state=$(echo "$FIN" | python3 -c "import sys,json;print(json.load(sys.stdin).get('state',''))" 2>/dev/null)
    pct=$(echo "$FIN" | python3 -c "import sys,json;print(json.load(sys.stdin).get('percent',''))" 2>/dev/null)
    echo "轮询 $n: state=$state percent=$pct"
done

echo "最终响应 -> $FIN"

URL=$(echo "$FIN" | python3 -c "import sys,json;print(json.load(sys.stdin).get('url',''))" 2>/dev/null)
[ -n "$URL" ] || { echo "FAIL: 没有拿到播放地址"; exit 1; }

echo "--- 校验 $URL ---"
curl -s -o /dev/null -w 'HTTP %{http_code}  %{size_download} 字节  %{content_type}\n' "$BASE$URL"

echo "--- 产物编码 ---"
ffprobe -v error -select_streams v:0 \
    -show_entries stream=codec_name,width,height -of csv=p=0 "/www/media/vod${URL#/media/vod}" 2>/dev/null \
    || ffprobe -v error -show_entries stream=codec_name -of csv=p=0 "$BASE$URL"
echo "URL=$URL"
