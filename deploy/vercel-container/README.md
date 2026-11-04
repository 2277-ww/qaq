# Vercel Container 运行时部署脚手架

把 PHP 7.3 + Phalcon 3.4 的完整运行环境打进一个 OCI 镜像，由 Vercel 的
Container Runtime（Beta，所有套餐可用）承载。镜像自包含 PHP、扩展、vendor 与业务代码，
目标机器上不需要安装任何 PHP 组件。

> 状态：脚手架已按官方文档与本机实际配置编写，**尚未在真实 Docker / Vercel 上构建验证**
> （本机没有 Docker，Vercel 构建需要推送镜像）。验证步骤见本文第 4 节。

## 1. 放置位置

Vercel 的容器运行时要求**项目根目录**存在 `Dockerfile`。因此使用方式是把应用本体作为仓库根：

```
<仓库根>/                     ← 就是 C:\ctc\www 的内容
├── Dockerfile                ← 从本目录复制
├── nginx.conf                ← 从本目录复制
├── entrypoint.sh             ← 从本目录复制
├── vercel.json               ← 从本目录复制
├── .dockerignore             ← 从本目录复制
├── app/ bootstrap/ config/ db/ public/ storage/ vendor/ ...
└── composer.json ...
```

`.dockerignore` 已排除演示视频（1.3GB）、`_removed_*`、运行时缓存与本地配置。

## 2. 必须先在项目里补的两处改造

1. **配置改为读环境变量**：`config/config.php` 里的 `db.*`、`redis.*`、`key` 目前是硬编码的本地值，
   容器里必须来自平台环境变量（否则连不上托管数据库）。
2. **调度器改成 HTTP 入口**：`scheduler.php` 是常驻进程，容器里的函数实例会被缩容（5 分钟无流量），
   无法可靠常驻。改为新增一个受保护的 `/cron/tick` 路由，由 Vercel Cron 定时调用。

## 3. 部署

```bash
# 首次：项目框架需显式设为 container，否则可能被识别成其它框架
vercel project update --framework container --yes

# 构建并发布（镜像在 Vercel 侧构建，本地不需要 Docker）
vercel deploy --prod
```

环境变量（项目 Settings → Environment Variables）：

| 变量 | 示例 | 说明 |
|---|---|---|
| `APP_ENV` | `production` | 关掉调试输出 |
| `APP_KEY` | 32 位随机串 | 原 `config.key` |
| `DB_HOST` / `DB_PORT` | `xxx.mysql.rds...` / `3306` | 托管 MySQL |
| `DB_NAME` / `DB_USER` / `DB_PASS` | `ctc` / `ctc` / `***` | |
| `REDIS_HOST` / `REDIS_PORT` / `REDIS_AUTH` | | 会话与缓存 |
| `COS_*` | | 对象存储，上传必须外置 |
| `CRON_SECRET` | 随机串 | Vercel Cron 会以 `Authorization: Bearer <值>` 调用 |

## 4. 验证

本地（需要 Docker）：

```bash
docker build -t ctc:local .
docker run --rm -p 8080:80 \
  -e APP_ENV=production -e APP_KEY=... \
  -e DB_HOST=host.docker.internal -e DB_NAME=ctc -e DB_USER=root -e DB_PASS= \
  -e REDIS_HOST=host.docker.internal \
  ctc:local
```

必过项：

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/            # 200
curl -s http://127.0.0.1:8080/ | grep -o '<title>[^<]*</title>'             # 自学平台
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/course/list  # 200
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/admin        # 200
docker exec -it <id> php -m | grep -E 'phalcon|redis|igbinary'              # 三个扩展
```

线上同上，域名替换为 `<project>.vercel.app`，另加：

- 冷启动：连续两次 `curl -w '%{time_total}'`，第二次应显著下降
- 缩容后冷启动：闲置 6 分钟后首次请求耗时应 < 5s（否则调大镜像精简度）
- 日志：`vercel logs <deployment>` 能看到 `[boot] region=...` 与 nginx 访问日志
- 上传：>4MB 的文件应返回 413（这是平台限制，不是 bug）

## 5. 已知限制（务必先读）

| 限制 | 数值/说明 |
|---|---|
| 运行状态 | Container Runtime 仍是 **Beta** |
| 文件系统 | 根只读，仅 `/tmp` 可写且上限 500MB，冷启动即丢 |
| 请求体 | 4.5MB 上限，超过 413 |
| 内存/CPU | Hobby 2GB / 1 vCPU，Pro 4GB / 2 vCPU |
| 时长 | Hobby 单次 300s 上限 |
| 缩容 | 5 分钟无流量缩到零，下次冷启动 |
| 区域 | 单区域；Pro 才可多区域 |
| WebSocket | 容器函数不提供公网长连接入口，GatewayWorker 必须外置或关闭 |
| 镜像条目 | VCR 对镜像内条目数有优化上限，vendor 3.2 万文件需实测是否触顶 |

### 基础镜像若已下架

`php:7.3-fpm-buster` 属于 EOL 版本，Docker Hub 保留历史 tag 但不再维护。若拉取失败，按优先级换：

1. `php:7.3-fpm-alpine`（体积小，但 apk 源同样需切 archive，编译链改 `apk add --virtual .build`）
2. `debian:bullseye` 上源码编译 PHP 7.3（最可控，构建时间约 15 分钟）
3. 放弃容器方案，改用 VPS 或 Render（同一 Dockerfile 思路，但可自由选基础镜像）


完整论证与替代方案见 `docs/Vercel容器化运行环境部署方案.md`。
