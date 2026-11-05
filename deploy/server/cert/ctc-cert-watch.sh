#!/bin/bash
#
# 证书看门狗 —— Let's Encrypt IP 证书（shortlived profile，寿命约 6 天）
#
# 每次运行：
#   1. 读取 /etc/nginx/ssl/8.138.34.151.crt 的到期时间，算出剩余天数
#   2. 剩余 <= 3 天时主动触发 acme.sh --cron --force（续期成功后 acme.sh 自己 reload nginx）
#   3. 续期后仍 <= 2 天则告警（写日志 + 可选 webhook），并把状态写进
#      /var/www/acme-status/cert.txt（nginx 以 /_status/cert.txt 暴露，供外部拨测）
#
# 用法：
#   /usr/local/bin/ctc-cert-watch.sh            # 常规巡检
#   CERT_FILE=/path/to.crt /usr/local/bin/ctc-cert-watch.sh
#
set -u

CERT_FILE="${CERT_FILE:-/etc/nginx/ssl/8.138.34.151.crt}"
ACME_SH="${ACME_SH:-$HOME/.acme.sh/acme.sh}"
DOMAIN="${DOMAIN:-8.138.34.151}"
STATUS_FILE="${STATUS_FILE:-/var/www/acme-status/cert.txt}"
LOG_FILE="${LOG_FILE:-/var/log/ctc/cert-watch.log}"
ALERT_CONF="${ALERT_CONF:-/etc/ctc/alert.conf}"

# 剩余天数低于该值时尝试续期（可用环境变量覆盖，便于演练）
RENEW_AT="${RENEW_AT:-3}"
# 剩余天数低于该值时告警
ALERT_AT="${ALERT_AT:-2}"

mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$STATUS_FILE")"

log() {
    printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE"
}

# 发送告警：日志必写，webhook 有配置才发
notify() {
    local msg="$1" payload code
    log "ALERT $msg"
    if [ ! -f "$ALERT_CONF" ]; then
        log "未配置告警通道（$ALERT_CONF 不存在），仅记录日志"
        return 0
    fi
    # shellcheck disable=SC1090
    . "$ALERT_CONF" 2>/dev/null
    if [ -z "${ALERT_WEBHOOK_URL:-}" ]; then
        log "ALERT_WEBHOOK_URL 为空，仅记录日志"
        return 0
    fi
    case "${ALERT_WEBHOOK_TYPE:-wecom}" in
        wecom|dingtalk)
            payload=$(printf '{"msgtype":"text","text":{"content":"%s"}}' "$msg")
            ;;
        *)
            payload=$(printf '{"text":"%s"}' "$msg")
            ;;
    esac
    code=$(curl -s -o /dev/null -w '%{http_code}' -m 10 \
        -H 'Content-Type: application/json' -d "$payload" "${ALERT_WEBHOOK_URL}" 2>/dev/null)
    log "webhook type=${ALERT_WEBHOOK_TYPE:-wecom} http=${code:-000}"
}

# 剩余秒数（取不到返回空）
seconds_left() {
    local end now
    end=$(openssl x509 -in "$CERT_FILE" -noout -enddate 2>/dev/null | cut -d= -f2)
    [ -n "$end" ] || return 1
    end=$(date -d "$end" +%s 2>/dev/null) || return 1
    now=$(date +%s)
    echo $((end - now))
}

write_status() {
    local state="$1" left="$2" not_after="$3" renew="$4" hint="$5"
    {
        echo "state=${state}"
        echo "domain=${DOMAIN}"
        echo "days_left=${left}"
        echo "not_after=${not_after}"
        echo "last_renew=${renew}"
        echo "checked_at=$(date -Iseconds)"
        if [ -n "$hint" ]; then
            echo "hint=${hint}"
        fi
    } >"$STATUS_FILE.tmp"
    mv -f "$STATUS_FILE.tmp" "$STATUS_FILE"
    chmod 0644 "$STATUS_FILE" 2>/dev/null
}

if [ ! -f "$CERT_FILE" ]; then
    notify "【证书告警】$DOMAIN 证书文件不存在：$CERT_FILE"
    write_status fail -1 "" missing "证书文件缺失"
    exit 1
fi

secs=$(seconds_left) || {
    notify "【证书告警】$DOMAIN 证书无法解析：$CERT_FILE"
    write_status fail -1 "" unknown "openssl 解析失败"
    exit 1
}

not_after=$(openssl x509 -in "$CERT_FILE" -noout -enddate 2>/dev/null | cut -d= -f2)
# 向上取整，避免剩 0.4 天显示成 0 天
left=$(( (secs + 86399) / 86400 ))

log "检查 $CERT_FILE：剩余 ${left} 天（$not_after）"

renew_state=skipped
hint=""

if [ "$left" -le "$RENEW_AT" ]; then
    if [ -x "$ACME_SH" ]; then
        log "剩余 ${left} 天 <= ${RENEW_AT}，触发续期：$ACME_SH --cron --force"
        # 加超时：Let's Encrypt API 网络异常时 acme.sh 会无限重试，不能让 cron 堆积
        out=$(timeout 240 "$ACME_SH" --cron --force 2>&1)
        rc=$?
        log "续期退出码 ${rc}：$(printf '%s' "$out" | tail -n 5 | tr '\n' '|')"
        secs=$(seconds_left) || secs=0
        left=$(( (secs + 86399) / 86400 ))
        not_after=$(openssl x509 -in "$CERT_FILE" -noout -enddate 2>/dev/null | cut -d= -f2)
        if [ "$rc" -eq 0 ] && [ "$left" -gt "$RENEW_AT" ]; then
            renew_state=ok
            log "续期成功，新证书剩余 ${left} 天（$not_after）"
        else
            renew_state=failed
            if [ "$rc" -eq 124 ]; then
                hint="续期请求超时（240s），多为与 Let's Encrypt API 的网络问题，请检查出口连通性"
            else
                hint="acme.sh 续期失败，见 /var/log/ctc/cert-watch.log 与 ~/.acme.sh/acme.log"
            fi
        fi
    else
        renew_state=failed
        hint="acme.sh 不存在或不可执行：$ACME_SH"
        log "$hint"
    fi
fi

if [ "$left" -le "$ALERT_AT" ]; then
    notify "【证书告警】$DOMAIN HTTPS 证书仅剩 ${left} 天（到期 $not_after），续期状态 ${renew_state}。门户将出现证书错误，请立即处理。"
    write_status fail "$left" "$not_after" "$renew_state" "${hint:-证书即将过期}"
    log "告警已发出：剩余 ${left} 天"
    exit 2
fi

if [ "$left" -le "$RENEW_AT" ]; then
    write_status warn "$left" "$not_after" "$renew_state" "${hint:-已触发续期但尚未生效}"
    exit 0
fi

write_status ok "$left" "$not_after" "$renew_state" ""
exit 0
