#!/bin/bash
# 登录功能部署脚本（在生产机执行）
#
# 前置：deploy/login-feature 整个目录已上传到 /tmp/login-feature
#   scp -r deploy/login-feature root@8.138.34.151:/tmp/
#
# 动作：
#   1. php -l 语法校验全部 PHP 文件（任何一个失败即中止）
#   2. 备份 4 个原文件 + config 到 /root/backup/login-feature-<ts>/
#   3. 覆盖 4 个文件（cp 写入既有文件，保留原属主与权限）
#   4. 关闭内置身份模式 identity.enabled（patch_identity_off.py，自带备份与回滚）
#   5. 清缓存：volt 编译缓存 + redis db3 的注解/元数据缓存
#      （新增了路由注解 home.forum_login.logout，不清注解缓存会 404）
#
# 回滚：备份目录里有原文件，config 的 .bak.* 也在；按同名路径拷回即可。

set -euo pipefail

SRC=/tmp/login-feature
APP=/www/ctc/app
TS=$(date +%Y%m%d%H%M%S)
BAK=/root/backup/login-feature-$TS

fail() { echo "[FAIL] $1"; exit 1; }

echo "=== 1. 语法校验 ==="
for f in \
    "$SRC/app/Http/Home/Controllers/ForumLoginController.php" \
    "$SRC/app/Http/Home/Controllers/UserConsoleController.php" \
    "$SRC/patch_identity_off.py"; do
    test -f "$f" || fail "缺少文件 $f"
done
/usr/bin/php -l "$SRC/app/Http/Home/Controllers/ForumLoginController.php" >/dev/null || fail "ForumLoginController 语法错误"
/usr/bin/php -l "$SRC/app/Http/Home/Controllers/UserConsoleController.php" >/dev/null || fail "UserConsoleController 语法错误"

echo "=== 2. 备份 ==="
mkdir -p "$BAK/Controllers" "$BAK/Views/account" "$BAK/Views/partials"
cp -a "$APP/Http/Home/Controllers/ForumLoginController.php" "$BAK/Controllers/"
cp -a "$APP/Http/Home/Controllers/UserConsoleController.php" "$BAK/Controllers/"
cp -a "$APP/Http/Home/Views/account/forum_login.volt" "$BAK/Views/account/"
cp -a "$APP/Http/Home/Views/partials/header.volt" "$BAK/Views/partials/"
cp -a /www/ctc/config/config.php "$BAK/config.php"
echo "备份目录: $BAK"

echo "=== 3. 覆盖文件 ==="
# cp 覆盖既有文件时不改变目标文件的属主与权限
cp "$SRC/app/Http/Home/Controllers/ForumLoginController.php" "$APP/Http/Home/Controllers/"
cp "$SRC/app/Http/Home/Controllers/UserConsoleController.php" "$APP/Http/Home/Controllers/"
cp "$SRC/app/Http/Home/Views/account/forum_login.volt" "$APP/Http/Home/Views/account/"
cp "$SRC/app/Http/Home/Views/partials/header.volt" "$APP/Http/Home/Views/partials/"

echo "=== 4. 关闭内置身份模式 ==="
python3 "$SRC/patch_identity_off.py"

echo "=== 5. 清缓存 ==="
# volt 编译缓存
find /www/ctc/storage/cache/volt -type f -delete 2>/dev/null || true

# 注解/元数据缓存（redis db3；key 含反斜杠，必须 while read 循环，不能 xargs）
for pattern in '_PHCR_ANNOTATION_*' '_PHCR_METADATA_*'; do
    redis-cli -n 3 --scan --pattern "$pattern" \
        | while IFS= read -r key; do
            [ -n "$key" ] && redis-cli -n 3 DEL "$key" >/dev/null
          done
done

# opcache 有 2 秒重验窗口，等待后首请求即用新代码
sleep 3

echo "=== 6. 首屏自检 ==="
CODE=$(curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1/)
echo "GET / -> $CODE"
[ "$CODE" = "200" ] || fail "首页异常"

CODE=$(curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1/account/forum-login)
echo "GET /account/forum-login -> $CODE"
[ "$CODE" = "200" ] || fail "登录页异常"

echo "DONE: 登录功能部署完成，运行 verify_login.sh 做端到端验收"
