# 论坛侧 · 学习进度接收端点

## 为什么需要它

网关的 `forum-internal` 路由把 `/api/v1/forum/internal/*` **原样转发**到论坛上游
9088（设计约束：业务路由不做路径重写）。论坛本体没有学习进度接收接口，因此
`POST /api/v1/forum/internal/learning/progress` 会被论坛当成未知路径。

这条端点补的就是这个缺口。**论坛本体的代码、配置、数据库都不需要改。**

## 部署形态

```
学习平台 ──L2 签名──> 网关 8.138.246.181
                        │
                        ├─ /api/v1/forum/internal/learning/*  ->  127.0.0.1:9082  ← 本端点
                        └─ /api/v1/forum/internal/*           ->  127.0.0.1:9088  ← 论坛本体，不变
```

APISIX 按最长前缀匹配，`learning/` 这条更长的前缀会优先命中，论坛自己的内部
API 完全不受影响。

## 三步上线

### 1. 放文件、配密钥

```bash
mkdir -p /root/gw-deploy/configs/forum_endpoint /etc/jingyuan-forum /var/lib/jingyuan-forum

cp forum_peer_endpoint.py add_forum_learning_route.py \
   /root/gw-deploy/configs/forum_endpoint/

# 内部签名密钥：取「网关 → 论坛」这一把，不是学习平台那把
python3 -c "import json;print(json.load(open('/etc/jingyuan-gateway/secrets.json'))['internal_sign_keys']['forum'])" \
  > /tmp/_k

cat > /etc/jingyuan-forum/peer.env <<EOF
FORUM_PEER_HOST=127.0.0.1
FORUM_PEER_PORT=9082
FORUM_PEER_DB=/var/lib/jingyuan-forum/learning_events.db
FORUM_INTERNAL_SIGN_KEY=$(cat /tmp/_k)
EOF

chmod 600 /etc/jingyuan-forum/peer.env
rm -f /tmp/_k
```

> 密钥段的键名以 `secrets.json` 实际结构为准。若该文件里内部签名按平台平铺
> （如 `internal_sign_keys` 下直接是 32 字节串），用对应平台的键即可；
> 验签失败时先对这一段，不要先去怀疑签名算法。

### 2. 起服务

```bash
cp jy-forum-peer.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now jy-forum-peer
systemctl status jy-forum-peer --no-pager
curl -s http://127.0.0.1:9082/api/v1/forum/internal/learning/health
# {"code":"OK","message":"success","data":{"status":"up"}}
```

### 3. 加网关路由

```bash
cd /root/gw-deploy/configs/forum_endpoint
python3 add_forum_learning_route.py --dry-run   # 先看要写什么
python3 add_forum_learning_route.py             # 幂等写入
```

脚本会拒绝在 `forum-internal` 缺少 `jy-l2-sign` 插件时创建路由——那条路由一旦
没有服务态鉴权，接收端点就等于公网裸奔。

## 验收

```bash
# 不带签名：必须 401 / 40105
curl -s -o /dev/null -w '%{http_code}\n' \
  -X POST http://8.138.246.181/api/v1/forum/internal/learning/progress \
  -H 'Content-Type: application/json' -d '{"eventId":"x","eventType":"course.completed"}'

# 用验收脚本（本地或服务器都可跑）
python3 verify_forum_link.py
```

## 已知边界

| 项 | 说明 |
| --- | --- |
| 签名字段顺序 | `SIGN_FIELDS` 按「自学平台」的七字段顺序实现。若网关 `jy-identity.lua` 的拼接顺序不同，改这一个列表即可，算法不用动。 |
| 数据库 | sqlite 单表，够验收不够生产。正式上线并入论坛现有库并加索引。 |
| 回执 | 本端点只做入库确认；`exam.progress.ack` 那套回执是学习平台→考试平台的方向，论坛不需要实现。 |
| 消费 | 入库后没有消费者。论坛要用这些数据（如「已结课」徽章、板块准入），需要另写任务读 `learning_event` 表。 |
