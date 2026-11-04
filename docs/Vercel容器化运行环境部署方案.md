# 在 Vercel 上跑起完整运行环境：方案、配置与验证

面向问题：能不能不依赖"一台装好 PHP 的机器"，把整套平台（含 PHP 7.3 + Phalcon 3.4 扩展、MySQL、Redis）跑在 Vercel 上？

结论先说：

1. **纯 Serverless 函数（社区 vercel-php）不行**，缺 PHP 7.3 与 Phalcon C 扩展，这条路直接排除。
2. **官方 Container 运行时可以承载**：把环境封进 OCI 镜像，Vercel 构建并托管，镜像自带 PHP、扩展、vendor 与代码；MySQL / Redis / 对象存储必须外接。当前该运行时是 **Beta**。
3. 代价是**六项架构让步**（见第 8 节），其中最硬的是"没有公网 WebSocket"和"根文件系统只读"。若这三条不能接受，VPS 或容器托管平台更省事。

配套脚手架：`deploy/vercel-container/`（Dockerfile / nginx.conf / entrypoint.sh / vercel.json / .dockerignore / README）。

---

## 1　Vercel 三种承载形态对照

| 形态 | 能跑什么 | 对本项目 | 判定 |
|---|---|---|---|
| 社区 `vercel-php` 运行时 | PHP 7.4–8.5 的脚本 | 需要 7.3 + `ext-phalcon`（C 扩展），镜像里没有，构建期也不能注入 | ✗ 排除 |
| **Container 运行时** | 任意 OCI 镜像，监听 80/`$PORT` | 自己编 PHP 7.3 + Phalcon 3.4，全部打进镜像 | ✓ 可行（Beta） |
| Daemons | 常驻后台进程（队列消费者类） | 只能做调度/队列；**不提供公网 HTTP 入口**，替代不了 WebSocket 服务 | △ 仅辅助 |

---

## 2　目标架构

```
                    ┌──────────────────────────────────────┐
   浏览器 ──HTTPS──▶│ Vercel Container Function (hkg1)     │
                    │  nginx :80  ⇄  php-fpm 7.3           │
                    │  ├ phalcon 3.4.5 / redis / igbinary  │
                    │  ├ vendor (221MB) + app 代码          │
                    │  └ storage/cache → /tmp (只读根例外)  │
                    └───────┬───────────────┬──────────────┘
                            │               │
              ┌─────────────▼──┐   ┌────────▼─────────┐
              │ 托管 MySQL 5.7/8│   │ 托管 Redis       │
              │ 业务数据 + 迁移  │   │ 会话/缓存/队列    │
              └────────────────┘   └──────────────────┘
                            │
              ┌─────────────▼──────────┐   ┌──────────────────┐
              │ 对象存储 COS/S3（上传） │   │ 外部 WS 服务/关闭 │
              └────────────────────────┘   └──────────────────┘
```

一句话概括：**计算与环境进镜像，状态全部外置**。这样容器实例可以随时被缩容、替换，不丢数据。

---

## 3　环境依赖矩阵

| 层 | 依赖 | 版本 | 在 Vercel 上的来源 |
|---|---|---|---|
| OS | Debian 10 buster | — | `php:7.3-fpm-buster` 基础镜像（源已 EOL，需切 `archive.debian.org`） |
| Web | nginx | 1.14（buster 自带） | 镜像内 `apt install nginx-light` |
| PHP | php-fpm | 7.3.33 | 基础镜像 |
| PHP 扩展 | phalcon | 3.4.5 | **源码编译**（`./install`），composer 装不了 |
| | redis / igbinary | 5.3.7 / 3.2.5 | `pecl install` |
| | pdo_mysql / gd / zip / opcache | 内置 | `docker-php-ext-install` |
| 依赖 | Composer vendor | 33 个一级包 / 221MB | 构建期 `composer install --no-dev` |
| 数据 | MySQL | 5.7（8.0 亦可，需验 SQL 兼容） | **外接托管**（PlanetScale / Aiven / RDS / 腾讯云） |
| 缓存 | Redis | 5.x | **外接**（Upstash / Redis Cloud） |
| 文件 | 对象存储 | — | **外接** COS/S3（上传与静态资源） |
| 定时 | 调度 | — | Vercel Cron → 受保护 HTTP 入口 |

版本锁定不是偏好，是硬约束：Phalcon 3.4 的 C 源码只兼容到 PHP 7.3，换 7.4 必须升 Phalcon 4，而 Phalcon 4 的 API 与现有 93 个控制器不兼容。**所以镜像必须自带 PHP 7.3，不能用平台默认版本。**

---

## 4　构建配置

Vercel 的容器运行时只认**项目根目录的 `Dockerfile`**（无其它框架时自动识别），构建完推到 Vercel Container Registry（VCR），流量全量路由到该镜像。

### 4.1　Dockerfile 的四个关键决策

1. **archive 源**：buster 已 EOL，`deb.debian.org` 的 buster 目录早已下线，不切源会在 `apt-get update` 直接 404。已写入 `Acquire::Check-Valid-Until "false"` 关闭过期校验。
2. **双阶段**：builder 装编译链、编扩展、跑 composer；runtime 只装 nginx，再从 builder 复制 `/usr/local/lib/php/extensions` 与 `conf.d`。同一基础镜像，ABI 一致，避免二次编译。
3. **符号链接 `/tmp`**：根文件系统只读，`storage/cache`、`storage/log` 在**构建期**改成指向 `/tmp/cache`、`/tmp/log` 的软链——运行时无法创建链接，必须提前做。这样 `app/Providers/Volt.php` 里的 `compiledPath = cache_path().'/volt/'` 一行都不用改。
4. **opcache 预编译**：`opcache.validate_timestamps=0` + `memory_consumption=192`，镜像内代码不变，省掉每请求的 stat 开销，是冷启动以外唯一的性能手段。

### 4.2　运行配置

- **nginx 重写**：Phalcon 依赖 `?_url=` 参数，配置为 `try_files $uri $uri/ /index.php?_url=$uri&$args`，与生产环境的 Nginx 规则一致。
- **端口**：默认监听 80；如需改，设 `PORT` 环境变量。
- **日志**：nginx 访问日志与 PHP 错误都重定向到 stdout/stderr，Vercel 才能采集（`vercel logs`）。
- **入口脚本**：建 `/tmp` 目录树 → 校验 phalcon/redis/igbinary 三个扩展在位（缺一个直接退出，不带病启动）→ 后台起 php-fpm → 前台跑 nginx。收到 SIGTERM 时转发给 fpm。

### 4.3　定时任务

`scheduler.php` 是常驻进程，在会被缩容的容器里不可靠。改为：

```json
{ "crons": [{ "path": "/cron/tick", "schedule": "*/5 * * * *" }] }
```

Vercel Cron 调用时自动带 `Authorization: Bearer $CRON_SECRET`，在新增的 `/cron/tick` 路由里校验该头，再调 `App\Console\Tasks\*` 的入口方法。这样定时逻辑不变，只是触发方式从"常驻循环"改成"平台定时 HTTP 调用"。

---

## 5　为什么这样就不依赖"完整项目"了

关键区别在于**依赖的边界**：

| 方式 | 目标机器需要什么 | 交付物 |
|---|---|---|
| 传统复现（`docs/repro_a.md`） | Windows 上装 PHP 7.3、Phalcon DLL、MySQL、Redis，配 php.ini，起三个进程 | 源码 + 一整套手工步骤 |
| 本方案 | 什么都不装，能访问 Vercel 即可 | 一个镜像（内含上述全部） |

镜像即环境：PHP 二进制、扩展 `.so`、vendor、业务代码、nginx 配置、启动脚本都在里面。换机器、换人、重装系统都不影响，版本漂移被 Dockerfile 钉死。外部只剩"有状态的东西"（数据库、Redis、文件），它们本来就是应该独立托管的部分。

---

## 6　必须改造的代码点（6 处）

| # | 位置 | 现状 | 改法 |
|---|---|---|---|
| 1 | `config/config.php` | `db.host=127.0.0.1`、`redis.host=127.0.0.1`、`key` 硬编码 | 改为 `getenv('DB_HOST') ?: '127.0.0.1'` 形式，保留本地默认值 |
| 2 | `scheduler.php` | 常驻循环 | 新增 `/cron/tick` 路由 + `CRON_SECRET` 校验，复用现有 Task 类 |
| 3 | 上传（`Admin/Controllers/UploadController.php`） | 可落本地 `storage` 或 COS | 强制走 COS；本地 `/tmp` 会在缩容时丢失，且请求体上限 4.5MB |
| 4 | `config['websocket']['connect_address']` | `127.0.0.1:8282` | 改为外部 WS 服务地址；或前端降级为轮询/关闭实时功能 |
| 5 | `storage/cache`、`storage/log` | 目录 | 不改代码，靠镜像内软链到 `/tmp`（已处理） |
| 6 | `public/static/vod`（1.3GB 演示视频） | 随仓库走 | 移到对象存储 + CDN，镜像内不放（`.dockerignore` 已排除） |

第 1、2 条是**必须**，否则跑不起来或定时任务失效；第 3、4、6 条是**必须接受的设计变更**。

---

## 7　限制与风险

### 7.1　平台硬限制（官方文档，2026-11 核对）

| 项 | 限制 | 对本项目的影响 |
|---|---|---|
| 运行状态 | Container Runtime **Beta**，全套餐可用 | 生产可用性无 SLA 承诺 |
| 文件系统 | 根只读，仅 `/tmp` 可写，上限 500MB | 缓存可放，上传不可放 |
| 请求体 | **4.5MB** | 大文件上传必须直传对象存储；超出返回 413 |
| 内存 / CPU | Hobby 2GB / 1 vCPU；Pro 4GB / 2 vCPU | php-fpm 需限 worker 数（建议 4–6） |
| 单次时长 | Hobby 300s；Pro 默认 300s、可到 800s | 导出、批量同步类任务要拆批 |
| 缩容 | 生产 5 分钟无流量即缩到零 | 冷启动频繁，首屏变慢 |
| 区域 | 默认 `iad1`，单区域 | 国内访问建议 `hkg1`；数据库要放同区 |
| 网络 | 不支持 Secure Compute / 静态 IP | 若数据库有 IP 白名单，需走公网 + 强口令 |
| WebSocket | 容器函数不提供公网长连接入口 | GatewayWorker 必须外置或砍掉 |
| 镜像 | VCR 对镜像条目数有优化上限 | vendor 3.2 万文件、镜像约 900MB，需实测是否触顶 |

### 7.2　工程风险

| 风险 | 说明 | 缓解 |
|---|---|---|
| 冷启动 | 镜像大 + php-fpm 启动 + Volt 编译，首次请求可能 3–10s | 精简镜像、预热 `/cron/tick`、把 Volt 编译结果预生成进镜像 |
| Volt 编译放大 | 冷启动后 `/tmp` 为空，模板需重新编译（361 个 .volt） | 构建期预编译到 `/opt/volt-seed`，入口脚本拷进 `/tmp` |
| PHP 7.3 已 EOL | 2021-12 停止安全支持；Phalcon 3.4 同样 | 长期不如直接升级框架，短期需网络层 WAF + 最小暴露面 |
| 数据库版本 | 托管 MySQL 多为 8.0，本项目按 5.7 编写 | 先跑 `phinx migrate` + 关键 SQL 回归，注意 `sql_mode` |
| 成本模型 | 按 Active CPU + Provisioned Memory 计费，不是按请求 | 低流量下便宜；常驻内存时间才是账单主体 |
| GPL-2.0 | 上游协议，分发衍生作品需开源 | 镜像内保留 LICENSE 与来源声明 |

---

## 8　替代方案对比

| 方案 | 环境自包含 | 改造量 | 稳定性 | 适用 |
|---|---|---|---|---|
| **A. Vercel Container（本方案）** | ✓ 镜像 | 中（6 处改造） | Beta，冷启动明显 | 想要"一条命令上线"、流量波动的展示/试用环境 |
| **B. 单台 VPS** | 需装环境或用同一镜像 | 小（包已就绪） | 最稳，可常驻 WS/调度 | 正式对外运营，预算可控 |
| **C. Render / Fly.io / Railway** | ✓ 镜像 | 小（同一 Dockerfile 直接用） | 比 Vercel 更适合常驻进程 | 想托管又不想管服务器，且需要 WS |
| **D. 前台静态化 + API 分离** | 部分 | 大（模板与路由重写） | 中 | 不推荐，工作量远超收益 |
| **E. 纯静态展示页** | — | 无 | 高 | 只要对外展示（已上线） |

判断标准很简单：**要不要 WebSocket、能不能接受冷启动**。两条都要 → 选 C 或 B；只要一个能跑的演示站 → 选 A。

---

## 9　验证运行效果的具体方式

分四层，每层都有明确的通过标准。

### 9.1　镜像层（本地，需 Docker）

```bash
docker build -t ctc:local .
docker run --rm -p 8080:80 \
  -e APP_ENV=production -e APP_KEY=*** \
  -e DB_HOST=host.docker.internal -e DB_NAME=ctc -e DB_USER=root -e DB_PASS= \
  -e REDIS_HOST=host.docker.internal ctc:local
```

| 检查 | 命令 | 通过标准 |
|---|---|---|
| 扩展齐全 | `docker exec -it <id> php -m \| grep -E 'phalcon\|redis\|igbinary'` | 三行都有 |
| PHP 版本 | `docker exec -it <id> php -v` | 7.3.33 |
| 伪静态生效 | `curl -s -o /dev/null -w '%{http_code}' localhost:8080/course/list` | 200（不是 302/404） |
| 首页渲染 | `curl -s localhost:8080/ \| grep title` | `<title>自学平台</title>` |
| 只读根 | `docker exec -it <id> touch /app/x` | 失败（Read-only file system）为正确 |
| 缓存可写 | `docker exec -it <id> ls /tmp/cache/volt` | 有编译产物 |

### 9.2　线上功能层

| 检查 | 通过标准 |
|---|---|
| `GET /`、`/course/list`、`/admin` | 均 200，标题含"自学平台" |
| 课程详情 + 章节 | 200，目录条数与数据库一致 |
| 播放页 | HTML 含 `.m3u8` 或 `.mp4` 源地址 |
| 笔记/收藏写入 | 提交后 Redis 会话内可见，刷新不丢（验证会话在 Redis 而非本地） |
| 后台列表分页 | 200，翻页正常（验证 MySQL 长连接可用） |
| 上传 5MB 文件 | 返回 413（确认这是平台上限，而非应用 bug） |
| 缩容后首请求 | 闲置 6 分钟后 `time_total` < 5s |

### 9.3　运行时可观测

```bash
vercel logs <deployment-url>          # 应能看到 [boot] region=hkg1 app_env=production
vercel inspect <deployment-url>       # 状态 Ready、区域、构建耗时
```

关注三类信号：`[fatal] xxx extension missing`（构建或入口失败）、`502`（fpm 未起或端口不对）、`504 FUNCTION_INVOCATION_TIMEOUT`（超 300s）。

### 9.4　可自动化的冒烟脚本（建议入库）

```bash
BASE=$1
for p in / /course/list /admin /course/1; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE$p")
  echo "$p -> $code"; [ "$code" = 200 ] || exit 1
done
curl -s "$BASE/" | grep -q '<title>自学平台</title>' || exit 1
echo "smoke ok"
```

这条脚本即"是否可运行"的客观定义：4 个关键路由 200 + 标题正确。任一失败即未达标。

---

## 10　建议的推进顺序

如果决定走这条路线，按此顺序做，最快暴露致命问题：

1. **先验证镜像能编出来**（最高风险）：只跑到 `docker build`，确认 Phalcon 3.4.5 在 buster + PHP 7.3 下编译通过。这一步不过，后面都无意义。
2. **接一个托管 MySQL + Redis**，跑 `phinx migrate` 与种子数据，确认 SQL 兼容。
3. **改配置读环境变量**（`config/config.php`），本地 `docker run` 打通首页/课程/后台三页。
4. **推上 Vercel**，量冷启动与镜像条目是否触顶。
5. 再补 cron 入口、上传外置、WS 取舍。

前两步建议在一台有 Docker 的机器上做（本机当前没有 Docker，所以脚手架未实测）。若第 1 步就卡住（例如基础镜像已不可拉取），改用 VPS 或 Render 方案，成本更低。

---

## 附：与"已经上线的静态展示页"的关系

`deploy/vercel-static/` 是纯静态介绍页，已发布在 `https://vercel-static-hazel-three.vercel.app`，与本文的容器方案互不影响：前者是"门面"，后者才是"可运行的平台"。两者可以共存于同一账号下不同项目。
