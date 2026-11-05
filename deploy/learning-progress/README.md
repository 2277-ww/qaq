# 学习进度窗口 · 上线包

对应说明文档：`docs/学生学习进度窗口与考试平台对接说明_V1.0.md`

## 目录

| 路径 | 说明 |
| --- | --- |
| `exam_outbox.sql` | 发件箱建表语句（幂等，可重复执行） |
| `patches/*.diff` | 对既有文件的增量补丁（相对线上版本） |
| `server-snapshot/**` | 改动后线上文件的完整快照，直接覆盖即可 |

## 上线顺序

```bash
# 0) 备份（务必先做）
ssh root@<host> 'mkdir -p /root/ctc_learning_progress_backup && cp -a /www/ctc/app /www/ctc/config /www/ctc/scheduler.php /root/ctc_learning_progress_backup/'

# 1) 建表
mysql -uctc -p*** ctc < exam_outbox.sql

# 2) 覆盖文件
#    新增：repro/src/course-tencent-cloud-master 下的 12 个新文件
#    修改：server-snapshot 下 5 个文件
#    注意 owner 必须是 apache（php-fpm 运行用户）
chown -R apache:apache /www/ctc/app /www/ctc/config /www/ctc/scheduler.php

# 3) 清路由注解缓存（新控制器必须清，否则 url() 取不到路由名）
redis-cli -n 3 eval "local ks=redis.call('keys',ARGV[1]); for i=1,#ks do redis.call('del',ks[i]) end; return #ks" 0 '_PHCR_ANNOTATION_*'

# 4) 清模板缓存 + 重载
rm -f /www/ctc/storage/cache/volt/_www_ctc_app_http_home_views_user_console_progress.volt.php
systemctl reload php-fpm

# 5) 定时器：exam_sync / sync_learning 靠 scheduler.php 触发
#    注意 scheduler.php 不是常驻进程，必须由 cron 每分钟拉起；
#    直接执行 deploy/server/11_scheduler.sh 即可（会修 $bin 路径、停用失效的
#    XunSearch 索引任务、安装 /etc/cron.d/ctc-scheduler 并自检）
bash deploy/server/11_scheduler.sh
```

## 配置

上线后按需改 `config/config.php`：

- `gateway.base_uri` 留空 → 本地直连模式（演示用，页面会标注）；
- 填网关地址 + `gateway.internal_sign_secret`，并把 `gateway.verify_sign` 置 `true` → 生产模式。

## 回滚

```bash
cp -a /root/ctc_learning_progress_backup/app /www/ctc/
cp -a /root/ctc_learning_progress_backup/config /www/ctc/
cp -a /root/ctc_learning_progress_backup/scheduler.php /www/ctc/
mysql -uctc -p*** ctc -e 'DROP TABLE IF EXISTS kg_exam_outbox'   # 可选，保留不影响旧功能
redis-cli -n 3 eval "local ks=redis.call('keys',ARGV[1]); for i=1,#ks do redis.call('del',ks[i]) end; return #ks" 0 '_PHCR_ANNOTATION_*'
systemctl reload php-fpm
```

## 自检

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://<host>/uc/progress          # 200
curl -s https://<host>/api/v1/learning/completion/usr_10000/1                # code=OK
cd /www/ctc && php console.php exam_sync main                                 # sent/failed/dead
```

---

# 第二轮：多对端与实训/论坛预留接口（2026-11-05 22:45）

## 变更内容

把"只对接考试平台"抽象成对端注册表，考试/实训/论坛共用同一条链路：

- 新增 `$config['peers']`：每个对端的启用状态、网关路径、事件白名单、扩展通道、入站白名单
- `kg_exam_outbox` 增列 `target`（exam|training|forum）、`channel`（official|extension）
- 新增 `kg_peer_inbox`：接收实训/论坛回传事件，(source,event_id) 唯一
- 新增接口：`GET /api/v1/learning/peers`、`POST /peers/{source}/events`、`GET /peers/{source}/events/{eventId}`
- 新增任务：`peer_reconcile`（每日 03:47 对账补缺口）
- 修复：`learning.progress.updated` 不再走正式通道（接入说明 8.1 纪律）

## 上线顺序

```bash
# 1. 数据库（幂等，可重复执行）
mysql -uctc -p*** ctc < deploy/learning-progress/peer_inbox_and_target.sql

# 2. 代码
cp -a /tmp/stage/app /www/ctc/        # 或逐文件覆盖，见 patches-round2/
cp -a /tmp/stage/config /www/ctc/
cp /tmp/stage/scheduler.php /www/ctc/
chown -R apache:apache /www/ctc/app /www/ctc/config /www/ctc/scheduler.php

# 3. 清缓存（三个都要）
redis-cli -n 3 eval "local ks=redis.call('keys',ARGV[1]); for i=1,#ks do redis.call('del',ks[i]) end; return #ks" 0 '_PHCR_ANNOTATION_*'
redis-cli -n 3 eval "local ks=redis.call('keys',ARGV[1]); for i=1,#ks do redis.call('del',ks[i]) end; return #ks" 0 '_PHCR_METADATA_:*'
rm -f /www/ctc/storage/cache/volt/*.php && chown -R apache:apache /www/ctc/storage/cache/volt
systemctl reload php-fpm
```

> `_PHCR_METADATA_` 必须清：新增字段后模型元数据仍按旧列缓存，会报
> `Column 'target' doesn't belong to any of the selected models`。

## 自检

```bash
curl -s https://<host>/api/v1/learning/peers | head -c 300      # 三个对端
curl -s -o /dev/null -w '%{http_code}\n' https://<host>/uc/progress   # 200，页面有「对接通道」
cd /www/ctc && php console.php peer_reconcile main              # checked/repaired/dead
cd /www/ctc && php console.php exam_sync main                   # sent 按 target 分组
```

## 回滚

本轮备份在服务器 `/root/ctc_bak_20261105224515/`（按相对路径还原即可）。
数据库回滚：`ALTER TABLE kg_exam_outbox DROP COLUMN channel, DROP COLUMN target;` + `DROP TABLE kg_peer_inbox`。

---

# 第三轮：考试平台反向接口（回执 / 拉取 / 重放）（2026-11-05 23:05）

## 变更内容

出站推送过去只到"网关收下了"，本轮补齐考试平台侧的三个反向接口，形成闭环：

- 新增 `POST /api/v1/learning/peers/exam/receipts`：接收 `exam.progress.ack`，把发件箱记录标记为已确认并回填对端单号
- 新增 `GET /api/v1/learning/peers/exam/pull`：按 `afterId` 游标增量拉取，用于漏推补偿
- 新增 `POST /api/v1/learning/peers/exam/replay`：对账后重放失败/死信事件，需 `Idempotency-Key`
- `kg_exam_outbox` 增列 `acked_at`、`remote_id`、`ack_status`，及索引 `idx_target_acked`
- `$config['peers']['exam']` 新增 `ack` / `pull` / `pull_limit` / `replay` 四个开关
- 新增服务：`Services/Learning/Receipt.php`、`Pull.php`、`Replay.php`
- 页面：同步记录表增加「对端单号」列，状态列区分「已确认」与「已推送」
- 一致性加固：拉取与重放都按 `channel=official` + 事件目录白名单双重过滤，避免中间态事件漏给对端

## 上线顺序

```bash
# 1. 数据库（幂等，可重复执行）
mysql -uctc -p*** ctc < deploy/learning-progress/exam_outbox_ack.sql

# 2. 代码（9 个文件，见 patches-round3/）
#    app/Services/Learning/{Peers,Receipt,Pull,Replay}.php
#    app/Models/ExamOutbox.php  app/Repos/ExamOutbox.php
#    app/Services/Logic/Learning/Progress.php
#    app/Http/Api/Controllers/LearningController.php
#    app/Http/Home/Views/user/console/progress.volt  config/config.php
chown -R apache:apache /www/ctc/app /www/ctc/config

# 3. 清缓存（三样都清，缺一个就 500）
redis-cli -n 3 eval "local ks=redis.call('keys',ARGV[1]); for i=1,#ks do redis.call('del',ks[i]) end; return #ks" 0 '_PHCR_ANNOTATION_*'
redis-cli -n 3 eval "local ks=redis.call('keys',ARGV[1]); for i=1,#ks do redis.call('del',ks[i]) end; return #ks" 0 '_PHCR_METADATA_:*'
rm -f /www/ctc/storage/cache/volt/*.php && chown -R apache:apache /www/ctc/storage/cache/volt
```

## 自检

```bash
bash deploy/learning-progress/verify_peer_api.sh     # 9 个用例，含契约码与幂等
curl -s https://<host>/api/v1/learning/peers | grep receipts   # exam 下 receipts/pull/replay 应 enabled=true
```

## 回滚

本轮备份在服务器 `/root/ctc_ack_backup/`：

```bash
cp -a /root/ctc_ack_backup/app /www/ctc/ && cp -a /root/ctc_ack_backup/config /www/ctc/
redis-cli -n 3 eval "local ks=redis.call('keys',ARGV[1]); for i=1,#ks do redis.call('del',ks[i]) end; return #ks" 0 '_PHCR_METADATA_:*'
```

数据库列可保留（旧代码不读这三列，不影响运行）；若要彻底回退：
`ALTER TABLE kg_exam_outbox DROP COLUMN acked_at, DROP COLUMN remote_id, DROP COLUMN ack_status;`

---

# 第四轮：考试平台对接接口（服务态鉴权 / 握手 / 查询）（2026-11-05 23:55）

## 变更内容

| 项 | 说明 |
| --- | --- |
| 服务态鉴权 | 新增 `App\Services\Learning\PeerAuth`，按 `X-App-Code` 识别对端，支持 `signature`(HMAC) / `token` / `none` 三档 |
| 双通道鉴权 | `beforeExecuteRoute` 先走网关用户态，再走对端服务态；对端身份只能访问自己的 `/peers/{自己}/*` |
| 握手 | `GET /peers/{source}/handshake`，免鉴权，返回契约版本、签名规范、能力开关、`outboundReady` |
| 查询接口 | `GET /peers/{source}/students/{userId}/progress`、`.../completion/{courseId}`，服务态可查 |
| 越权防护 | `peerGuard()` 统一拦截：未登记 404、跨对端 403、能力未开 403 |
| 出站鉴权 | `peers.<对端>.access_token` / `headers`，适配 APISIX jwt-auth / key-auth |
| 页面 | 「已确认」计数、「入站仅编码校验」等鉴权档位徽标、「考试平台回源」标签 |
| 文档 | 新增 `docs/考试平台对接接口契约_V1.0.md`（可直接发考试平台） |

无数据库变更，**不需要执行迁移**。

## 上线顺序

```bash
# 1. 备份
cp -a /www/ctc/app /root/ctc_bak_peer2_app && cp -a /www/ctc/config /root/ctc_bak_peer2_config

# 2. 打补丁（在 /www/ctc 下）
patch -p1 --dry-run < deploy/learning-progress/patches-round4/app.diff
patch -p1 < deploy/learning-progress/patches-round4/app.diff
patch -p1 < deploy/learning-progress/patches-round4/config.diff

# 3. 语法检查（缺文件会在这里报出来）
php -l app/Services/Learning/PeerAuth.php
php -l app/Http/Api/Controllers/LearningController.php

# 4. 清缓存（三样都清，缺一个就 500 / 路由不存在）
redis-cli -n 3 eval "local ks=redis.call('keys','_PHCR_ANNOTATION_:*'); for i,k in ipairs(ks) do redis.call('del',k) end; return #ks" 0
redis-cli -n 3 eval "local ks=redis.call('keys','_PHCR_METADATA_:*'); for i,k in ipairs(ks) do redis.call('del',k) end; return #ks" 0
rm -f storage/cache/volt/*.php && chown -R apache:apache storage/cache/volt
```

## 配置

```php
$config['peers']['exam']['inbound_app_code'] = 'exam';   // 对端调我们时带的 X-App-Code
$config['peers']['exam']['secret'] = '';                 // 填上即强制签名校验
$config['peers']['exam']['auth_mode'] = 'auto';          // auto：有 secret 就签名
$config['peers']['exam']['query'] = true;                // 允许按学生查进度/准入
```

`secret` 留空时页面显示「入站仅编码校验」，此时**只校验 `X-App-Code`**，仅适用于联调。上线前必须与考试平台交换密钥并填入。

## 自检

```bash
bash deploy/learning-progress/verify_exam_link.sh
```

覆盖 11 个用例：握手（正确/错误编码）、无签名 401、错签名 401、正确签名下的拉取/进度/准入/回执/回执幂等、跨对端 403、未登记对端 404、不存在学生 404。

> 脚本会临时给 exam 配测试密钥、临时启用 training 做越权校验，退出时自动复原。
> 内含 3 秒等待：`php-fpm` 的 `opcache.revalidate_freq=2`，改完配置立即请求仍走旧配置。

## 回滚

```bash
cp -a /root/ctc_bak_peer2_app /www/ctc/app && cp -a /root/ctc_bak_peer2_config /www/ctc/config
redis-cli -n 3 eval "local ks=redis.call('keys','_PHCR_ANNOTATION_:*'); for i,k in ipairs(ks) do redis.call('del',k) end; return #ks" 0
rm -f /www/ctc/storage/cache/volt/*.php && chown -R apache:apache /www/ctc/storage/cache/volt
```

新增的 `app/Services/Learning/PeerAuth.php` 可直接删除；其余为本轮追加字段，旧代码不读，不影响运行。

## 仍需对方提供

1. 考试平台的正式 `push_path`（当前 `/api/v1/exam/learning/progress` 为占位）
2. 统一网关地址，填入 `peers.exam.base_uri`（当前为空 = 本地演示，事件只入箱不外发）
3. 双方共享密钥（填入 `peers.exam.secret`）
4. 若网关要求 Bearer 或 `X-API-Key`，填入 `peers.exam.access_token` / `headers`

---

# 第五轮：接入论坛平台（8.138.246.181 统一网关）（2026-11-06 00:15）

## 背景

网关方交付了部署报告与验收脚本，确认：

- 论坛是网关后**唯一的真实业务系统**（`127.0.0.1:9088`），其余四平台是桩服务；
- 网关有 19 条路由，`/api/v1/forum/internal/*` 与 `/api/v1/learning/internal/*` 都走 **L2 服务签名**；
- `/api/v1/forum/*` 与 `/api/v1/learning/*` 走 **L1 会话鉴权**，服务态调用会被 40101。

## 核心发现：签名是两套，原来一套都对不上

| | 网关 L2（过网关用） | X-Internal-Sign（注入上游用） |
| --- | --- | --- |
| 头 | `X-App-Key` `X-Timestamp` `X-Nonce` `X-Sign-Alg` `X-Signature` | `X-Internal-Sign` |
| canonical | 7 段：appKey/ts/nonce/METHOD/path/query/sha256(body) | 7 段：user/role/client/tokenExp/requestId/authMode/timestamp |
| 谁签 | 本平台签 | 网关签 |
| 谁验 | 网关 | 本平台 |

原实现只有一套「四段 + `X-App-Code`」的对端签名，**两套都不是**，打过去必 40105。
本轮补齐 L2，同时保留内部签名（网关会剥离重算，本地直连对端时仍需它）。

## 变更内容

| 文件 | 改动 |
| --- | --- |
| `app/Services/Learning/GatewaySign.php` | **新增**。L2 canonical / 签名 / nonce / 错误码映射 |
| `app/Services/Learning/Gateway.php` | 出站挂 L2 五头；密钥缺失时直接失败；网关数字码转可读原因 |
| `app/Services/Learning/Peers.php` | 新增 `app_key` / `app_secret` 字段；`describe()` 下发双栈规范 |
| `app/Http/Api/Controllers/LearningController.php` | 识别 `X-Auth-Mode=service`；`peerGuard` 按 AppKey 收紧；握手下发 `gatewayEntry` |
| `config/routes.php` | `/api/v1/learning/internal/peers/*` 别名路由（9 条） |
| `config/config.php` | `gateway.app_key`；`peers.forum` 启用并纠正 `push_path` |
| `config/config.default.php` | 同上（模板同步） |

配套新增：

```
deploy/learning-progress/
├── apply_forum_peer.sh              两把密钥从 secrets.json 注入 config.php
├── verify_forum_link.py             验收：A 网关组 / B 平台组
└── forum_endpoint/
    ├── forum_peer_endpoint.py       论坛侧接收端点（参考实现，可线上跑）
    ├── add_forum_learning_route.py  网关新增路由（复制 forum-internal 策略）
    ├── jy-forum-peer.service        systemd 单元
    └── README.md                    论坛侧部署三步
```

## 上线顺序

```bash
# 0. 备份
cp -a /www/ctc/app /root/ctc_bak_peer3_app
cp -a /www/ctc/config /root/ctc_bak_peer3_config

# 1. 打补丁（GatewaySign.php 是新文件，必须先传）
#    patches-round5/ 下按文件路径覆盖

# 2. 注入密钥（两把，来源不同）
./apply_forum_peer.sh --config /www/ctc/config/config.php

# 3. 语法检查
for f in app/Services/Learning/GatewaySign.php app/Services/Learning/Gateway.php \
         app/Services/Learning/Peers.php app/Http/Api/Controllers/LearningController.php \
         config/routes.php config/config.php; do php -l $f; done

# 4. 清缓存（三样都清）
redis-cli -n 3 eval "local ks=redis.call('keys','_PHCR_ANNOTATION_:*'); for i,k in ipairs(ks) do redis.call('del',k) end; return #ks" 0
rm -f /www/ctc/storage/cache/volt/*.php
systemctl reload php-fpm

# 5. 论坛侧（在 8.138.246.181 上）
cd /root/gw-deploy/configs/forum_endpoint
systemctl enable --now jy-forum-peer
python3 add_forum_learning_route.py --dry-run && python3 add_forum_learning_route.py
```

## 自检

```bash
# A 网关组：验签名能否过网关（不需要论坛上线）
python3 verify_forum_link.py --group gateway --secrets secrets.json

# B 平台组：验握手、入站鉴权、跨对端隔离
python3 verify_forum_link.py --group platform --base http://127.0.0.1
```

已完成的验证：

| 项 | 结果 |
| --- | --- |
| PHP ↔ 网关 Python 基准签名比对 | **8/8 一致**（含 query 排序、空格 `+`、中文、空值、同名参数） |
| 论坛接收端点本地用例 | **8/8 通过** |
| 公网 `/api/v1/learning/internal/peers/forum/handshake` | 40105（证明走 L2，路由存在） |
| 公网 `/api/v1/learning/peers/forum/handshake` | 40101（L1 拦，确认不能用旧前缀） |

## 回滚

```bash
cp -a /root/ctc_bak_peer3_app /www/ctc/app && cp -a /root/ctc_bak_peer3_config /www/ctc/config
redis-cli -n 3 eval "local ks=redis.call('keys','_PHCR_ANNOTATION_:*'); for i,k in ipairs(ks) do redis.call('del',k) end; return #ks" 0
rm -f /www/ctc/storage/cache/volt/*.php && chown -R apache:apache /www/ctc/storage/cache/volt
systemctl reload php-fpm
```

`GatewaySign.php` 可直接删除；`peers.forum` 改回 `enabled => false` 即停用推送。
论坛侧 `systemctl disable --now jy-forum-peer` 并 `add_forum_learning_route.py --delete`。

## 仍待执行

1. `apply_forum_peer.sh` 注入两把密钥（当前为空，出站会以 `gateway_app_secret_missing` 失败，不会静默降级）
2. 网关新增 `forum-learning-events` 路由
3. 本平台部署到网关后的 8080（当前是桩服务）
4. 核实 `jy-identity.lua` 的七字段拼接顺序（论坛端点按本平台顺序实现，不一致需改 `SIGN_FIELDS`）

---

# 第六轮：论坛账号确认接入（2026-11-06）

## 这次接的是身份，不是推送

论坛上线了账号确认接口 `POST /answer/api/v1/account/verify`（v2.2.0，只读、不签发 token）。本平台用它做「论坛账号登录」，与学习进度推送是两条独立链路，只共用 `GatewaySign` 这一套 L2 签名实现。

接口文档第 159 行顺带确认了四个预置 AppKey，其中 `jy-learning-svc` 与本平台配置一致——上一轮标记为阻塞的「AppKey 真名未确认」因此解除。

## 变更

| 文件 | 改动 |
| --- | --- |
| `app/Services/Gateway/AccountVerify.php` | 新增。调用账号确认接口，3s 超时，错误码映射 |
| `app/Services/Gateway/LoginThrottle.php` | 新增。IP 固定窗口限流，Redis Lua 原子计数 |
| `app/Services/Logic/Account/ForumLogin.php` | 新增。建号/复用、角色映射、失败分流 |
| `app/Http/Home/Views/account/login_by_forum.volt` | 新增。登录页第三个 tab |
| `db/migrations/20261106002000.php` | 新增。`kg_account` 加 `forum_uid` / `forum_name` |
| `app/Models/Account.php`、`app/Repos/Account.php` | 字段与 `findByForumUid()` |
| `app/Http/Home/Services/Account.php` | `loginByForum()` |
| `app/Http/Home/Controllers/AccountController.php` | `POST /account/forum/login` |
| `config/config.php`、`config.default.php` | 5 个 `gateway.account_*` |
| `config/errors.php` | 5 条文案 |
| `deploy/learning-progress/verify_account_link.py` | 新增。A 网关组 / B 平台组 |

## 三个决定

1. **首次登录自动建号**：统一身份不该要求先在本平台注册。只插 `kg_account`，`kg_user` 由 `afterCreate` 自动生成。
2. **建的号没有可用密码**：写 `hash(random_bytes(32), salt)` 而非空串。本平台是 `md5(md5(pwd).md5(salt))`，空串会让哈希只取决于 salt。
3. **不映射管理员**：论坛 `admin` 只当学员，`admin_role` 保持 0；`teacher` 映射到 `edu_role=2`（只影响教学内容，不涉及后台）。

## 上线

```bash
# ① 迁移（必须先于代码）
php vendor/bin/phinx migrate

# ② 代码 + 清缓存
redis-cli -n 3 eval "local ks=redis.call('keys','_PHCR_ANNOTATION_:*'); for i,k in ipairs(ks) do redis.call('del',k) end; return #ks" 0
rm -f /www/ctc/storage/cache/volt/*.php
systemctl reload php-fpm

# ③ 密钥（与推送同一把，已注入则跳过）
./apply_forum_peer.sh --config /www/ctc/config/config.php --secrets /etc/jingyuan-gateway/secrets.json

# ④ 验收
python3 verify_account_link.py --group gateway --secrets /etc/jingyuan-gateway/secrets.json \
        --login <账号> --password '<密码>'
python3 verify_account_link.py --group platform --base http://127.0.0.1
```

## 已验证

| 项 | 结果 |
| --- | --- |
| 公网路由存在 | 无签名返回 40105（非 40300） |
| 缺签名 / 篡改 | 40105 |
| 时间戳超窗 | 40106 |
| 未知 AppKey | 40108 |
| 与论坛客户端签名对拍 | 5/5 一致（ASCII、中文、转义、斜杠、空体） |

## 未验证（需真实账号）

正确凭据 → confirmed、错误密码与不存在账号同结论、首次建号写 `forum_uid`、二次登录不重复建号、论坛不可达时的降级提示。

详见 `docs/论坛账号登录对接说明_V1.0.md`。
