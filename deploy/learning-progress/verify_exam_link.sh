#!/bin/bash
# 考试平台对接接口自检（服务态签名模式）
# 用法：bash verify_exam_link.sh
# 说明：脚本会临时给 exam 配测试密钥、临时启用 training 做越权校验，退出时自动复原。

set -u

B="https://127.0.0.1"
H="Host: 8.138.34.151"
CFG="/www/ctc/config/config.php"
SECRET="test-secret-exam-2026"
MYSQL="mysql -uctc -pbyU1McsVMUAd8y6hRIlOebiT ctc"

cp -a "$CFG" /tmp/config.php.peer_bak

restore() {
  cp -a /tmp/config.php.peer_bak "$CFG"
  rm -f /tmp/config.php.peer_bak
  # php-fpm 的 opcache.revalidate_freq=2，复原后同样要等一轮才能生效
  sleep 3
}
trap restore EXIT

python3 - "$SECRET" <<'PY'
import io, sys
secret = sys.argv[1]
p = '/www/ctc/config/config.php'
s = io.open(p, encoding='utf-8').read()
s = s.replace("    'secret' => '',", "    'secret' => '" + secret + "',", 1)
s = s.replace("$config['peers']['training'] = [\n    'enabled' => false,",
              "$config['peers']['training'] = [\n    'enabled' => true,", 1)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
PY

# opcache.revalidate_freq=2：改完配置必须等过一个校验周期，否则 fpm 仍用旧脚本，
# 会出现「配了密钥却没校验」，让自检结论失真。
sleep 3

sign() {
python3 - "$1" "$2" "$3" "$4" "$SECRET" <<'PY'
import sys, hmac, hashlib
app, rid, ts, body, secret = sys.argv[1:6]
canon = app + "\n" + rid + "\n" + ts + "\n" + hashlib.sha256(body.encode()).hexdigest()
print(hmac.new(secret.encode(), canon.encode(), hashlib.sha256).hexdigest())
PY
}

call() {
  local desc=$1 url=$2 body=${3:-} app=${4:-exam}
  local ts=$(date +%s)
  local rid="req_${ts}_${RANDOM}"
  local sig=$(sign "$app" "$rid" "$ts" "$body")
  local out="/tmp/vout.$$"
  local code

  if [ -n "$body" ]; then
    code=$(curl -sk -o "$out" -w '%{http_code}' -X POST "$url" -H "$H" \
      -H "X-App-Code: $app" -H "X-Request-Id: $rid" -H "X-Timestamp: $ts" \
      -H "X-Internal-Sign: $sig" -H 'Content-Type: application/json' -d "$body")
  else
    code=$(curl -sk -o "$out" -w '%{http_code}' "$url" -H "$H" \
      -H "X-App-Code: $app" -H "X-Request-Id: $rid" -H "X-Timestamp: $ts" \
      -H "X-Internal-Sign: $sig")
  fi

  printf '[%s] %s %s\n' "$desc" "$code" "$(head -c 190 "$out")"
  rm -f "$out"
}

echo "===== A. 免鉴权入口 ====="
curl -sk "$B/api/v1/learning/peers/exam/handshake" -H "$H" -H 'X-App-Code: exam' \
  | python3 -c '
import json, sys
r = json.load(sys.stdin)
d = r.get("data")
if not isinstance(d, dict):
    print("[握手-失败]", json.dumps(r, ensure_ascii=False)[:220])
else:
    print("[握手] contract=%s auth=%s appCodeMatched=%s query=%s" % (
        d["contract"], d["auth"]["mode"], d["appCodeMatched"], d["capabilities"]["query"]["enabled"]))
'

curl -sk "$B/api/v1/learning/peers/exam/handshake" -H "$H" -H 'X-App-Code: oops' \
  | python3 -c '
import json, sys
r = json.load(sys.stdin)
d = r.get("data")
if not isinstance(d, dict):
    print("[握手-错编码/失败]", json.dumps(r, ensure_ascii=False)[:220])
else:
    print("[握手-错编码] appCodeMatched=%s declared=%s" % (d["appCodeMatched"], d["declaredAppCode"]))
'

echo "===== B. 签名校验 ====="
out="/tmp/vout.b"
code=$(curl -sk -o "$out" -w '%{http_code}' "$B/api/v1/learning/peers/exam/pull?userId=usr_10000&limit=1" -H "$H" -H 'X-App-Code: exam' -H "X-Request-Id: req_nosig_$RANDOM" -H "X-Timestamp: $(date +%s)")
printf '[无签名] %s %s\n' "$code" "$(head -c 140 "$out")"

ts=$(date +%s)
out="/tmp/vout.b"
code=$(curl -sk -o "$out" -w '%{http_code}' "$B/api/v1/learning/peers/exam/pull?userId=usr_10000&limit=1" -H "$H" -H 'X-App-Code: exam' -H "X-Request-Id: req_badsig_$RANDOM" -H "X-Timestamp: $ts" -H 'X-Internal-Sign: deadbeef')
printf '[错签名] %s %s\n' "$code" "$(head -c 140 "$out")"

echo "===== C. 正常调用（正确签名）====="
call "拉取" "$B/api/v1/learning/peers/exam/pull?userId=usr_10000&limit=2"
call "学生进度" "$B/api/v1/learning/peers/exam/students/usr_10000/progress"
call "准入判定" "$B/api/v1/learning/peers/exam/students/usr_10000/completion/2"

EID=$($MYSQL -N -e "SELECT event_id FROM kg_exam_outbox WHERE target='exam' AND event_type='course.completed' ORDER BY id DESC LIMIT 1;" 2>/dev/null)
TS=$(date +%s)
BODY="{\"eventId\":\"rcpt_link_$TS\",\"eventType\":\"exam.progress.ack\",\"correlationId\":\"$EID\",\"payload\":{\"status\":\"accepted\",\"remoteId\":\"EXAM-LINK-$TS\"}}"
call "回执" "$B/api/v1/learning/peers/exam/receipts" "$BODY"
call "回执幂等重发" "$B/api/v1/learning/peers/exam/receipts" "$BODY"

echo "===== D. 越权与边界 ====="
call "training 调 exam 通道" "$B/api/v1/learning/peers/exam/pull?userId=usr_10000&limit=1" "" training
call "不存在的对端" "$B/api/v1/learning/peers/ghost/pull?userId=usr_10000"
call "不存在的学生" "$B/api/v1/learning/peers/exam/students/usr_999999/progress"

echo "===== 用例结束，脚本退出时自动复原配置 ====="
