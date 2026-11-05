#!/bin/bash
# 考试平台预留接口自检：回执 / 拉取 / 重放
B="https://127.0.0.1"
H="Host: 8.138.34.151"
J="Content-Type: application/json"
P="/api/v1/learning/peers/exam"

echo "=== 1. 回执 accepted ==="
curl -sk -o /tmp/o1 -w "HTTP %{http_code}\n" -X POST "$B$P/receipts" -H "$H" -H "$J" -d @/root/receipt.json
cat /tmp/o1; echo

echo "=== 2. 回执重放（幂等）==="
curl -sk -o /tmp/o2 -w "HTTP %{http_code}\n" -X POST "$B$P/receipts" -H "$H" -H "$J" -d @/root/receipt.json
cat /tmp/o2; echo

echo "=== 3. 回执指向不存在事件 ==="
curl -sk -o /tmp/o3 -w "HTTP %{http_code}\n" -X POST "$B$P/receipts" -H "$H" -H "$J" \
  -d '{"eventId":"rcpt_bad_0001","eventType":"exam.progress.ack","correlationId":"evt_NOT_EXIST","payload":{"status":"accepted"}}'
cat /tmp/o3; echo

echo "=== 4. 回执事件类型非法 ==="
curl -sk -o /tmp/o4 -w "HTTP %{http_code}\n" -X POST "$B$P/receipts" -H "$H" -H "$J" \
  -d '{"eventId":"rcpt_bad_0002","eventType":"exam.other","correlationId":"evt_CE26FAD850750B24BF18"}'
cat /tmp/o4; echo

echo "=== 5. 增量拉取（afterId=0）==="
curl -sk -o /tmp/o5 -w "HTTP %{http_code}\n" "$B$P/pull?userId=usr_10000&afterId=0&limit=2" -H "$H"
cat /tmp/o5; echo

echo "=== 6. 增量拉取（游标续拉）==="
curl -sk -o /tmp/o6 -w "HTTP %{http_code}\n" "$B$P/pull?userId=usr_10000&afterId=2&limit=10" -H "$H"
cat /tmp/o6; echo

echo "=== 7. 拉取缺 userId ==="
curl -sk -o /tmp/o7 -w "HTTP %{http_code}\n" "$B$P/pull" -H "$H"
cat /tmp/o7; echo

echo "=== 8. 重放（缺 Idempotency-Key）==="
curl -sk -o /tmp/o8 -w "HTTP %{http_code}\n" -X POST "$B$P/replay" -H "$H" -H "$J" \
  -d '{"eventIds":["evt_CE26FAD850750B24BF18"]}'
cat /tmp/o8; echo

echo "=== 9. 重放单条 ==="
curl -sk -o /tmp/o9 -w "HTTP %{http_code}\n" -X POST "$B$P/replay" -H "$H" -H "$J" \
  -H "Idempotency-Key: replay-test-0001" -d '{"eventIds":["evt_CE26FAD850750B24BF18"]}'
cat /tmp/o9; echo
