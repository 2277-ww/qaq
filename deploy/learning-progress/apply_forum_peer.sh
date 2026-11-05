#!/usr/bin/env bash
# 把「学习平台」在网关上的两把密钥写进本平台配置
#
# 需要两把，来源不同、用途不同，不能互相替代：
#   app_secret           app_keys["jy-learning-svc"].secret   出站过网关 L2 用
#   internal_sign_secret internal_sign_keys["learning"]       入站验网关注入签名用
#
# 用法：
#   ./apply_forum_peer.sh --config /path/to/config/config.php
#   ./apply_forum_peer.sh --config ... --secrets /etc/jingyuan-gateway/secrets.json
#   ./apply_forum_peer.sh --config ... --dry-run
#
# 幂等：重复执行只会覆盖这两行，其他配置不动；每次改动前自动备份。

set -euo pipefail

CONFIG=""
SECRETS="/etc/jingyuan-gateway/secrets.json"
APP_KEY="jy-learning-svc"
PEER_KEY="learning"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)  CONFIG="$2"; shift 2 ;;
    --secrets) SECRETS="$2"; shift 2 ;;
    --app-key) APP_KEY="$2"; shift 2 ;;
    --peer-key) PEER_KEY="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
done

[[ -n "$CONFIG" ]] || { echo "必须指定 --config" >&2; exit 2; }
[[ -f "$CONFIG" ]] || { echo "配置文件不存在：$CONFIG" >&2; exit 2; }
[[ -r "$SECRETS" ]] || { echo "读不到密钥文件：$SECRETS（需要 root）" >&2; exit 2; }

read_secret() {
  python3 - "$SECRETS" "$1" "$2" "$3" <<'PY'
import json, sys
path, section, key, field = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
data = json.load(open(path, encoding="utf-8"))
node = data.get(section)
if not isinstance(node, dict):
    sys.exit("secrets.json 里没有 %s 段" % section)
value = node.get(key)
if value is None:
    sys.exit("secrets.json → %s.%s 不存在；已有键：%s" % (section, key, ", ".join(node.keys())))
# app_keys 的每一项通常是个对象 {"secret": "..."}，不是裸字符串；两种都兼容
if field:
    if not isinstance(value, dict):
        sys.exit("%s.%s 不是对象，无法取 %s" % (section, key, field))
    value = value.get(field)
if not value or not isinstance(value, str):
    sys.exit("%s.%s.%s 为空或不是字符串" % (section, key, field or ""))
print(value)
PY
}

APP_SECRET="$(read_secret app_keys "$APP_KEY" secret)"
# internal_sign_keys 通常是「平台名 -> 密钥串」的平铺结构，没有再套一层
INTERNAL_KEY="$(read_secret internal_sign_keys "$PEER_KEY" "")"

echo "app_key            = $APP_KEY"
echo "app_secret         = ${APP_SECRET:0:4}…${APP_SECRET: -4}（${#APP_SECRET} 字符）"
echo "internal_sign_key  = ${INTERNAL_KEY:0:4}…${INTERNAL_KEY: -4}（${#INTERNAL_KEY} 字符）"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] 未写入"
  exit 0
fi

BAK="${CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
cp -p "$CONFIG" "$BAK"
echo "已备份：$BAK"

python3 - "$CONFIG" "$APP_SECRET" "$INTERNAL_KEY" <<'PY'
import io, re, sys

path, app_secret, internal_key = sys.argv[1], sys.argv[2], sys.argv[3]

src = io.open(path, encoding="utf-8").read()

def set_line(text, key_path, value):
    """
    只替换 `$config['a']['b'] = '...';` 这一行的字面量，保留原有行结构与注释。
    用 re.sub 而不是整段重写，避免把用户的其它改动冲掉。
    """
    pattern = re.compile(
        r"(\$config\['" + key_path[0] + r"'\]\['" + key_path[1] + r"'\]\s*=\s*)'[^']*'(\s*;)"
    )
    new, n = pattern.subn(lambda m: m.group(1) + "'" + value + "'" + m.group(2), text)
    if n == 0:
        sys.exit("没找到配置行：$config['%s']['%s']，请确认 config 是标准模板" % key_path)
    return new, n

src, n1 = set_line(src, ("gateway", "app_secret"), app_secret)
src, n2 = set_line(src, ("gateway", "internal_sign_secret"), internal_key)

io.open(path, "w", encoding="utf-8", newline="").write(src)

print("已写入：gateway.app_secret（%d 处）、gateway.internal_sign_secret（%d 处）" % (n1, n2))
PY

# 语法自检：写坏了就回滚，绝不留一个起不来的配置
if command -v php >/dev/null 2>&1; then
  if php -l "$CONFIG" >/dev/null 2>&1; then
    echo "语法检查通过"
  else
    cp -p "$BAK" "$CONFIG"
    echo "语法检查失败，已回滚到 $BAK" >&2
    php -l "$CONFIG" >&2 || true
    exit 1
  fi
else
  echo "提示：本机没装 php CLI，跳过语法检查（请人工确认后再重载）"
fi

cat <<'EOF'

下一步：
  1) 确认 peers.forum.enabled = true、push_path = /api/v1/forum/internal/learning/progress
  2) 确认 gateway.verify_sign = true（生产必须；false 等于不校验网关注入的身份头）
  3) 重载 PHP：systemctl reload php-fpm   （或 apache2 / nginx+php-fpm 对应服务）
  4) 验证：python3 verify_forum_link.py --group platform --base http://127.0.0.1
EOF
