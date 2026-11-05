#!/bin/bash
#
# 10 —— 让系统优先使用 IPv4（修复 acme.sh 续期超时）
#
# 背景：本机只有链路本地 IPv6（无全局 IPv6 出口），而 acme-v02.api.letsencrypt.org
#       同时有 A 与 AAAA 记录。glibc 默认优先 IPv6，curl 会先连 AAAA 并一直等到超时，
#       表现为 acme.sh 续期失败、curl 返回 000（error 28），但 IPv4 直连正常。
#
# 做法：写入 /etc/gai.conf，把 IPv4 映射地址的优先级提到最高。
#       只影响新建进程的名字解析排序，不改路由、不动内核参数。
#
# 幂等：可重复执行
#
set -euo pipefail

GAI=/etc/gai.conf
STAMP=$(date +%Y%m%d-%H%M%S)

echo "== 1) 备份原配置 =="
if [ -f "$GAI" ]; then
    cp -a "$GAI" "$GAI.bak.$STAMP"
    echo "   已备份 -> $GAI.bak.$STAMP"
else
    echo "   $GAI 不存在，将新建"
fi

echo "== 2) 写入 gai.conf（IPv4 优先级 100） =="
cat >"$GAI" <<'EOF'
# /etc/gai.conf —— getaddrinfo(3) 地址排序规则
#
# 由 deploy/server/10_ipv4_pref.sh 生成。
# 本机无全局 IPv6 出口，故把 IPv4 映射地址（::ffff:0:0/96）的优先级提到最高，
# 避免 curl / git / acme.sh 等先尝试 IPv6 导致连接超时。

label  ::1/128       0
label  ::/0          1
label  2002::/16     2
label  ::/96         3
label  ::ffff:0:0/96 4

precedence  ::1/128       50
precedence  ::/0          40
precedence  2002::/16     30
precedence  ::/96         20
precedence  ::ffff:0:0/96 100
EOF
chmod 0644 "$GAI"
echo "   已写入 $GAI"

echo "== 3) 验证解析顺序（应 IPv4 在前） =="
FIRST=$(getent ahosts acme-v02.api.letsencrypt.org | awk 'NR==1{print $1}')
echo "   首选地址: $FIRST"
case "$FIRST" in
    *:*) echo "   [警告] 仍是 IPv6 优先" ; FAIL=1 ;;
    *)   echo "   [OK] IPv4 优先" ; FAIL=0 ;;
esac

echo "== 4) 验证 Let's Encrypt 接口可达 =="
CODE=$(curl -s -m 20 -o /dev/null -w '%{http_code}' https://acme-v02.api.letsencrypt.org/directory || true)
echo "   acme-v02 /directory -> HTTP ${CODE:-000}"
if [ "$CODE" != "200" ]; then
    echo "   [警告] 接口不可达，续期仍会失败"
    FAIL=1
else
    echo "   [OK] 接口可达"
fi

echo "== 5) 验证 GitHub 与普通站点未受影响 =="
for host in https://api.github.com https://www.cloudflare.com; do
    C=$(curl -s -m 15 -o /dev/null -w '%{http_code}' "$host" || true)
    printf '   %-30s -> %s\n' "$host" "${C:-000}"
done

echo
if [ "$FAIL" -eq 0 ]; then
    echo "结论：IPv4 优先已生效，acme.sh 续期通路正常。"
    exit 0
else
    echo "结论：仍存在问题，请检查出口网络。"
    exit 1
fi
