#!/bin/bash
# 论坛账号登录 · HTTP 端到端验收（在生产机上执行）
#
# 用法：bash verify_forum_login_http.sh [账号] [密码] [BASE]
#   BASE 默认 https://127.0.0.1（生产机本机，避开公网证书与 vhost 差异）
#
# 覆盖：页面渲染与 CSRF、正确凭据登录与建号、错误密码提示、按 IP 限流、
#       原有页面回归、日志脱敏。不修改任何配置，不重启服务。
#
# 说明：CSRF token 是 encryptBase64 输出，可能含 '+'；必须用 --data-urlencode，
#       否则 '+' 会被解析成空格，表现为偶发的 /error/400。

set -u

ACCOUNT=${1:-admin@jspi.edu.cn}
PASS=${2:-Admin@12345}
BASE=${3:-https://127.0.0.1}

TMP=$(mktemp -d)
JAR="$TMP/cookie.txt"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILED=1; }
FAILED=0

get_page() {
    curl -sk -c "$JAR" -b "$JAR" "$BASE/account/forum-login" \
        -o "$TMP/form.html" -w "%{http_code}"
}

get_token() {
    grep -oP '(?<=name="csrf_token" value=")[^"]+' "$TMP/form.html" | head -1
}

post_login() {
    curl -sk -c "$JAR" -b "$JAR" -e "$BASE/account/forum-login" \
        --data-urlencode "account=$ACCOUNT" \
        --data-urlencode "password=$1" \
        --data-urlencode "csrf_token=$TOKEN" \
        -o "$TMP/resp.html" \
        -w "status=%{http_code} redirect=%{redirect_url}" \
        "$BASE/account/forum/login"
}

echo "=== 1. 登录页渲染与 CSRF ==="
STATUS=$(get_page)
[ "$STATUS" = "200" ] && pass "GET /account/forum-login -> 200" || fail "GET 返回 $STATUS"
TOKEN=$(get_token)
[ -n "$TOKEN" ] && pass "csrf_token 已输出（len=${#TOKEN}）" || fail "页面没有 csrf_token"
case "$TOKEN" in *+*) echo "  note: token 含 '+'，已走 URL 编码" ;; esac

echo "=== 2. 正确凭据 ==="
R=$(post_login "$PASS")
echo "  $R"
echo "$R" | grep -q "redirect=$BASE/" \
    && pass "302 -> 首页（登录成功）" || fail "未跳转到首页"

echo "=== 3. 错误密码 ==="
R=$(post_login "WrongPass123")
echo "  $R"
grep -q "论坛账号或密码不正确" "$TMP/resp.html" \
    && pass "显示统一提示（不区分账号不存在/密码错误）" || fail "错误提示缺失"

echo "=== 4. 按 IP 限流（10 次/60s）==="
KEY=$(php -r 'echo "throttle:forum_login:" . md5("127.0.0.1");')
redis-cli -n 3 del "$KEY" > /dev/null
for i in $(seq 1 10); do post_login "WrongPass123" > /dev/null; done
post_login "WrongPass123" > /dev/null
grep -q "尝试次数过多" "$TMP/resp.html" \
    && pass "第 11 次被限流" || fail "限流未生效"
redis-cli -n 3 del "$KEY" > /dev/null

echo "=== 5. 数据库映射 ==="
PW=$(php -r '$config=[]; require "/www/ctc/config/config.php"; echo $config["db"]["password"];')
ROWS=$(MYSQL_PWD="$PW" mysql -u ctc ctc -N -e \
    "select count(*) from kg_account where forum_uid is not null;" 2>/dev/null)
[ "$ROWS" -ge 1 ] && pass "kg_account 存在论坛映射（$ROWS 条）" || fail "未建号"

echo "=== 6. 原有功能回归 ==="
for p in / /api/v1/learning/peers; do
    S=$(curl -sk -o /dev/null -w "%{http_code}" "$BASE$p")
    [ "$S" = "200" ] && pass "$p -> 200" || fail "$p -> $S"
done

echo "=== 7. 日志脱敏 ==="
LOG=/www/ctc/storage/log/gateway-$(date +%Y-%m-%d).log
if [ -f "$LOG" ]; then
    HITS=$(grep -c "$PASS" "$LOG" 2>/dev/null || true)
    [ "$HITS" = "0" ] && pass "gateway 日志无密码明文" || fail "日志疑似含密码 $HITS 处"
    grep -q "Forum Login Succeeded" "$LOG" && pass "成功事件已记录" || fail "成功日志缺失"
    grep -q "Forum Login Rejected\|Forum Login Throttled" "$LOG" \
        && pass "拒绝/限流事件已记录" || fail "拒绝日志缺失"
else
    fail "未找到 $LOG"
fi

echo "=== 结果 ==="
[ "$FAILED" = "0" ] && echo "ALL PASS" || echo "SOME FAILED"
exit "$FAILED"
