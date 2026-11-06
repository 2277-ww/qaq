#!/bin/bash
# 登录功能 · HTTP 端到端验收（在生产机执行）
#
# 用法：bash verify_login.sh [账号] [密码] [BASE]
#   BASE 默认 https://127.0.0.1
#
# 覆盖：
#   1. 未登录访问 /uc/progress → 302 登录页且携带回跳地址
#   2. 登录页渲染（含 redirect 隐藏字段）
#   3. 正确凭据 → 302 回跳原地址，会话生效（/uc/progress 200、页头出现用户名）
#   4. 外站回跳地址被消毒（redirect=https://evil.com → 登录后跳首页）
#   5. 错误密码 → 表单重渲染 + 错误文案，不建立会话
#   6. 退出登录 → 会话清除，/uc/progress 重新 302
#   7. 回归：首页/课程列表匿名 200
#
# CSRF token 含 '+'，必须 --data-urlencode。

set -u

ACCOUNT=${1:-admin@jspi.edu.cn}
PASS=${2:-Admin@12345}
BASE=${3:-https://127.0.0.1}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILED=1; }
FAILED=0

JAR="$TMP/cookie.txt"

echo "=== 1. 未登录访问个人中心 ==="
R=$(curl -sk -o /dev/null -w '%{http_code} %{redirect_url}' "$BASE/uc/progress")
echo "  $R"
echo "$R" | grep -q "^302" \
    && echo "$R" | grep -q "redirect=%2Fuc%2Fprogress" \
    && pass "/uc/progress 302 登录页 + 回跳参数" \
    || fail "未登录未正确跳转: $R"

echo "=== 2. 登录页渲染 ==="
CODE=$(curl -sk -c "$JAR" -b "$JAR" "$BASE/account/forum-login?redirect=%2Fuc%2Fprogress" -o "$TMP/form.html" -w '%{http_code}')
[ "$CODE" = "200" ] && pass "GET /account/forum-login -> 200" || fail "登录页返回 $CODE"
grep -q 'name="redirect" value="/uc/progress"' "$TMP/form.html" \
    && pass "redirect 隐藏字段已输出" \
    || fail "缺少 redirect 隐藏字段"
grep -q 'name="csrf_token"' "$TMP/form.html" \
    && pass "csrf_token 已输出" \
    || fail "缺少 csrf_token"
TOKEN=$(grep -oP '(?<=name="csrf_token" value=")[^"]+' "$TMP/form.html" | head -1)

echo "=== 3. 正确凭据登录 + 回跳 ==="
R=$(curl -sk -c "$JAR" -b "$JAR" -e "$BASE/account/forum-login" \
    --data-urlencode "account=$ACCOUNT" \
    --data-urlencode "password=$PASS" \
    --data-urlencode "csrf_token=$TOKEN" \
    --data-urlencode "redirect=/uc/progress" \
    -o "$TMP/resp.html" -w '%{http_code} %{redirect_url}' \
    "$BASE/account/forum/login")
echo "  $R"
echo "$R" | grep -q "302 $BASE/uc/progress" \
    && pass "302 回跳 /uc/progress" \
    || fail "未回跳: $R"

CODE=$(curl -sk -b "$JAR" -c "$JAR" -o "$TMP/uc.html" -w '%{http_code}' "$BASE/uc/progress")
[ "$CODE" = "200" ] && pass "登录后 /uc/progress -> 200" || fail "登录后 /uc/progress 返回 $CODE"

grep -q '学习进度' "$TMP/uc.html" && pass "进度页内容渲染" || fail "进度页内容异常"

CODE=$(curl -sk -b "$JAR" -c "$JAR" -o "$TMP/home.html" -w '%{http_code}' "$BASE/")
[ "$CODE" = "200" ] || fail "登录后首页 $CODE"
grep -q '退出登录' "$TMP/home.html" && pass "页头有退出入口" || fail "页头无退出入口"
grep -q '>登录<' "$TMP/home.html" \
    && fail "登录后页头仍显示登录入口" \
    || pass "页头匿名登录入口已消失（已登录态）"

echo "=== 4. 回跳地址消毒 ==="
JAR2="$TMP/cookie2.txt"
CODE=$(curl -sk -c "$JAR2" -b "$JAR2" -o "$TMP/form2.html" -w '%{http_code}' "$BASE/account/forum-login")
TOKEN2=$(grep -oP '(?<=name="csrf_token" value=")[^"]+' "$TMP/form2.html" | head -1)
R=$(curl -sk -c "$JAR2" -b "$JAR2" -e "$BASE/account/forum-login" \
    --data-urlencode "account=$ACCOUNT" \
    --data-urlencode "password=$PASS" \
    --data-urlencode "csrf_token=$TOKEN2" \
    --data-urlencode "redirect=https://evil.com/x" \
    -o /dev/null -w '%{http_code} %{redirect_url}' \
    "$BASE/account/forum/login")
echo "  $R"
echo "$R" | grep -q "302 $BASE/$" \
    && pass "外站回跳被拒，落回首页" \
    || fail "外站回跳未消毒: $R"

echo "=== 5. 错误密码 ==="
JAR3="$TMP/cookie3.txt"
curl -sk -c "$JAR3" -b "$JAR3" -o "$TMP/form3.html" "$BASE/account/forum-login"
TOKEN3=$(grep -oP '(?<=name="csrf_token" value=")[^"]+' "$TMP/form3.html" | head -1)
R=$(curl -sk -c "$JAR3" -b "$JAR3" -e "$BASE/account/forum-login" \
    --data-urlencode "account=$ACCOUNT" \
    --data-urlencode "password=WrongPass123" \
    --data-urlencode "csrf_token=$TOKEN3" \
    -o "$TMP/bad.html" -w '%{http_code}' \
    "$BASE/account/forum/login")
[ "$R" = "200" ] && pass "错误密码重渲染表单(200)" || fail "错误密码返回 $R"
grep -q 'error_message\|论坛账号或密码不正确\|稍后重试\|错误' "$TMP/bad.html" \
    && pass "错误文案展示" || fail "未见错误文案"
CODE=$(curl -sk -b "$JAR3" -o /dev/null -w '%{http_code} %{redirect_url}' "$BASE/uc/progress")
echo "$CODE" | grep -q "^302" && pass "错误密码不建立会话" || fail "错误密码后 /uc 未跳登录页: $CODE"

echo "=== 6. 退出登录 ==="
R=$(curl -sk -b "$JAR" -c "$JAR" -o /dev/null -w '%{http_code} %{redirect_url}' "$BASE/account/logout")
echo "  $R"
echo "$R" | grep -q "^302" && pass "退出 302 首页" || fail "退出返回 $R"
CODE=$(curl -sk -b "$JAR" -o /dev/null -w '%{http_code} %{redirect_url}' "$BASE/uc/progress")
echo "$CODE" | grep -q "^302" \
    && pass "退出后 /uc/progress 重新 302 登录页" \
    || fail "退出后 /uc 仍可访问: $CODE"

echo "=== 7. 匿名回归 ==="
for path in "/" "/course/list" "/search"; do
    CODE=$(curl -sk -o /dev/null -w '%{http_code}' "$BASE$path")
    [ "$CODE" = "200" -o "$CODE" = "302" ] \
        && pass "匿名 $path -> $CODE" \
        || fail "匿名 $path -> $CODE"
done
CODE=$(curl -sk -o "$TMP/anon.html" -w '%{http_code}' "$BASE/")
grep -q '>登录<' "$TMP/anon.html" \
    && pass "匿名页头显示登录入口" \
    || fail "匿名页头无登录入口"

echo ""
if [ "$FAILED" = "0" ]; then
    echo "ALL PASS"
else
    echo "存在失败项"
    exit 1
fi
