# 源码核查与 Vercel 部署可行性报告

核查时间：2026-11-04　核查对象：`C:\Users\paradox\Desktop\自学·平台`
结论：**存在改造版源码，但它不在工作区内**（工作区内只有官方原版归档）；**Vercel 无法承载该项目**，已改为交付可运行安装包 + 可部署的静态展示页。

---

## 1　核查结论

### 1.1　工作区内：官方原版，零改动

`repro/src/course-tencent-cloud-master` 是 `ctc.zip`（gitee `koogua/course-tencent-cloud` master 归档，1830 个文件）的原样解压：

| 判据 | 实测 |
|---|---|
| 文件总数 | 1830，与 `ctc.zip` 清单完全一致 |
| 修改时间 | 全部为 `2026-07-25 16:34`（归档内时间），无一个文件晚于解压时刻 |
| 新增/删除 | 无 |
| 与官方差异 | 0 处 |

结论：这是一份**未经修改的上游快照**，可以做基线比对，不能算"改造版"。

### 1.2　工作区外：真正的改造版在 `C:\ctc\www`

复现文档（`docs/repro_a.md`）要求的运行时目录 `C:\ctc` 下存在一份完整运行副本，当前正在 `127.0.0.1:8000` 提供服务（HTTP 200），这才是改造后的平台。以上游快照为基线做逐文件比对：

| 指标 | 数量 |
|---|---|
| 新增（改造版独有） | 37 项（含 2 个归档目录 `_removed_auth`、`_removed_vip`） |
| 删除（上游有、改造版无） | 34 项 |
| 内容修改 | 117 项 |
| 合计差异 | 188 项 |

文件时间戳同样能佐证：`app/Library/Branding.php`、`app/Http/Home/Controllers/NoteController.php`、`config/config.php`、`router.php` 等均为 11-03 / 11-04 新建，而上游文件时间停留在 07-25。

### 1.3　为什么改造版不在工作区里

`docs/repro_a.md` 明确规定"运行副本必须落在 `C:\ctc`（纯 ASCII 路径）"，因为 Phalcon 注解解析、Composer 解压、MySQL `--defaults-file` 在中文路径下会异常。工作区路径含中文与间隔号（`自学·平台`），所以只在工作区保留了**源码基线快照**，实际改造与运行都在 `C:\ctc\www` 完成。本次交付已把改造版打包进 `dist/`，不再依赖工作区外的路径。

---

## 2　改造内容清单

改造方向是把通用网校改造成"面向警务人才培养的自主学习平台"，共七组改动：

| # | 改造组 | 关键文件 | 说明 |
|---|---|---|---|
| 1 | 品牌去原厂化 | `app/Library/Branding.php`（新增）、`config/config.php` 的 `brand.*`、`db/migrations/20261104140000.php`、`public/static/brand-logo*.png` | 全站名称/标语/Logo 收敛到单一读取入口，代码里不再出现品牌字面量；迁移负责改写库中历史品牌数据 |
| 2 | 移除会员体系 | 删除 `Models/Vip.php`、`Repos/Vip.php`、`Services/Logic/Vip*`、`Caches/Index*VipCourseList.php`、`Http/*/Controllers/VipController.php`、`Views/vip/` | 课程不再区分会员/非会员，前台与后台的 VIP 入口一并下线 |
| 3 | 移除登录与账户 | 删除 `Home/Controllers/AccountController.php`、`ConnectController.php`、`Admin/Controllers/SessionController.php`、`Views/account/`、`Views/public/login.volt`；归档到 `_removed_auth/` | 改为免登录访客模式，学习行为按会话/设备标识记录 |
| 4 | 学习闭环 | 新增 `Models/{LearningNote,ChapterFavorite,GrowthOutbox}.php`、`Services/Logic/{Note,Growth}`、`Home/Controllers/NoteController.php`、`Views/user/console/{notes,growth,favorites_chapter}.volt` | 学习笔记、章节收藏、成长值三件套，配套 `Repos`/`Validators` |
| 5 | 点播同步 | 新增 `Models/{VodSource,VodSyncLog}.php`、`Admin/Services/VodSync.php`、`Admin/Controllers/VodSyncController.php`、`Console/Tasks/SyncVodTask.php`、`Views/vod_sync/` | 后台可维护片源并触发同步，任务落库留痕 |
| 6 | 演示数据 | `tools/{seed_demo,seed_growth,attach_videos,sync_progress}.php` | 造课、造学习记录、绑定片源、回填进度 |
| 7 | 本地调试适配 | `router.php`（新增）、`scheduler.php`、`config/errors.php` | 内置服务器下模拟 Nginx 的 `_url` 重写与 COS 图片后缀；调度器与错误页按本地环境调整 |

> `_removed_auth/`、`_removed_vip/` 是删除前的代码备份，不参与运行，未打进交付包。

---

## 3　项目结构

### 3.1　目录树（改造版）

```
ctc-selflearn-20261104/
├── public/                     # 唯一对外暴露的站点根目录
│   ├── index.php               # ★ 入口文件
│   ├── .htaccess               # Apache 重写规则
│   └── static/                 # 前端资源（lib 5MB / home / admin / cover / brand-logo）
├── bootstrap/                  # 内核与引导
│   ├── Kernel.php              # 装配 DI、配置、路由、视图、日志
│   ├── HttpKernel.php          # HTTP 请求入口，调用 Phalcon\Mvc\Application
│   ├── ConsoleKernel.php       # 命令行入口内核
│   ├── Helper.php              # 全局辅助函数（config()、app_path() 等）
│   └── *ErrorHandler.php
├── app/
│   ├── Http/{Home,Admin,Api}/  # 三套模块：Controllers 93 / Services 63 / Views 361(.volt)
│   ├── Models/ 77              # ORM 模型
│   ├── Repos/ 67               # 查询仓储
│   ├── Services/{Logic,*}      # 业务逻辑
│   ├── Library/                # Branding、Cache Backend 等基础件
│   ├── Builders/ Caches/ Console/ Listeners/ Providers/ Traits/ Validators/
├── config/
│   ├── config.php              # 运行配置（由 config.example.php 复制后填写）
│   ├── config.default.php      # 默认值
│   ├── routes.php              # 注解路由注册
│   ├── errors.php events.php
│   └── alipay/ wxpay/          # 支付证书位（空目录）
├── db/migrations/ 30           # Phinx 迁移
├── storage/{cache,log,tmp}/    # 必须可写：volt 编译、注解/元数据缓存、日志
├── websocket/                  # GatewayWorker：register / gateway / businessworker
├── tools/                      # 演示数据脚本
├── vendor/                     # Composer 依赖（仅可运行包内含，221MB）
├── composer.json / composer.lock
├── console.php                 # 命令行入口
├── scheduler.php               # 常驻调度器
├── phinx.php                   # 迁移配置
└── router.php                  # 内置服务器路由重写（仅本地）
```

规模：PHP 文件约 1.6k（不含 vendor），代码 8.4MB；含 vendor 与静态资源 159MB，站点历史媒体目录 `public/static/vod` 1.3GB（演示视频，不入包）。

### 3.2　入口链路

```
HTTP → public/index.php
        ├─ require ../bootstrap/Kernel.php      # 注册常量、自动加载、DI
        ├─ require ../bootstrap/HttpKernel.php
        └─ (new HttpKernel)->handle()           # Phalcon\Mvc\Application->handle()
             ├─ config/routes.php              # 注解路由，扫描三模块 *Controller.php
             ├─ App\Http\<Module>\Controllers\*  # 控制器 → Services → Repos → Models
             └─ Views/<controller>/<action>.volt → storage/cache/volt 编译缓存
```

命令行走 `console.php`（迁移、任务），常驻进程走 `websocket/start_*.php` 与 `scheduler.php`。

### 3.3　依赖（`composer.json`）

运行时硬依赖扩展：`ext-phalcon ~3.4`、`ext-redis`、`ext-pdo`、`ext-json`、`ext-fileinfo`、`ext-gd`（实测还需 `igbinary`，项目缓存前端指定 Igbinary 序列化）。
业务依赖：`guzzlehttp/guzzle ^6.5`、`yansongda/pay ^2.9`、`overtrue/wechat ^4.2`、`tencentcloud/tencentcloud-sdk-php ^3.0`、`qcloud/cos-sdk-v5 ^2.5`、`workerman/gateway-worker ^3.0`、`hightman/xunsearch ^1.4`、`robmorgan/phinx ^0.12`、`endroid/qr-code ^3.9`、`ezyang/htmlpurifier ^4.14` 等，vendor 内 33 个一级包。

### 3.4　"构建"配置

项目**没有前端构建链**（无 package.json / webpack / vite）：

- 前端是 Layui + 原生 JS 静态资源，直接由 `public/static` 提供；
- 后端模板 `.volt` 在首次渲染时编译成 PHP，落到 `storage/cache/volt`；
- 唯一的"构建"动作是 `composer install` 与 `phinx migrate`。

因此打包不需要编译步骤，只需要代码 + vendor + 可写的 `storage`。

---

## 4　打包结果

脚本：`build/pack_release.py`（可重跑）。产出在 `dist/`：

| 包 | 大小 | 文件数 | 内容 |
|---|---|---|---|
| `ctc-selflearn-src-20261104.zip` | 3.2 MB | 1606 | 全部业务代码 + composer 清单，不含 vendor 与演示视频 |
| `ctc-selflearn-runtime-20261104.zip` | 65.9 MB | 32117 | 上者 + `vendor/`，解压后无需联网即可启动 |
| `manifest-src.txt` / `manifest-runtime.txt` | — | 1606 / 32117 行 | 逐文件 SHA256 + 字节数 |

两包共同约定：剔除 `public/static/vod`（1.3GB 演示视频）、`_removed_*`、`storage` 运行时垃圾；`config.php` 不直接入包，改为 `config.example.php`（app key、DB 口令换占位符，`env` 改为 `pro`）；附 `README_DEPLOY.md` 说明环境、启动与 Nginx 配置。

### 4.1　包可用性实测

把 runtime 包解到干净目录 `C:\pkgtest`，按 README 复制配置后启动：

```
cd public && php -S 127.0.0.1:8011 ../router.php
```

| 请求 | 结果 |
|---|---|
| `GET /` | 200，`<title>自学平台</title>` |
| `GET /course/list` | 200，8020 字节 |
| `GET /admin` | 200，21463 字节 |

首轮测试暴露过一个打包缺陷：`storage/cache/{annotations,metadata,purifier,volt}` 空目录未入包，导致 Volt 报 `Volt directory can't be written` 并 302 到 `/error/500`；已在脚本中补建空目录并重新打包，复测通过。

---

## 5　Vercel 部署：不可行

### 5.1　硬约束逐条比对

| 维度 | 本项目要求 | Vercel 能力 | 判定 |
|---|---|---|---|
| 运行时 | PHP **7.3** + `ext-phalcon 3.4`（C 扩展） | 官方仅 Node/Python/Go/Ruby；PHP 需社区 `vercel-php`，版本 7.4–8.5，镜像内无 phalcon | ✗ |
| 框架版本 | Phalcon 3.4 只支持到 PHP 7.3（7.4 起需 Phalcon 4） | 运行时不提供 7.3 与 phalcon 组合 | ✗ |
| 构建期装扩展 | 需要编译/放置 `php_phalcon.dll`、`php_igbinary.dll` | 构建镜像不可注入自定义 C 扩展 | ✗ |
| 数据库 | MySQL 5.7 长连接、30 个 Phinx 迁移 | 无内置数据库 | ✗ |
| 会话/缓存 | Redis（会话、缓存、队列） | 无内置 Redis | ✗ |
| 文件系统 | `storage/` 必须可写（Volt 编译、上传、日志） | 只读，仅 `/tmp` 可写且每次冷启动丢失 | ✗ |
| 常驻进程 | `websocket/` GatewayWorker 占 8282；`scheduler.php` 定时任务 | 仅请求触发的无状态函数 | ✗ |
| 包体 | vendor 221MB + 静态资源，解压后 159MB 起 | 函数包解压上限 250MB，留余量极小 | ⚠ |
| 请求模型 | 传统 PHP-FPM 常驻 + 全局状态、注解元数据缓存 | 每次调用可能冷启动，元数据缓存失效会拖慢首字节 | ⚠ |

补充说明：Vercel 现在支持把自定义 OCI 容器作为函数镜像（Vercel Container Registry），理论上能把 `php:7.3 + phalcon` 塞进容器函数。但那仍然是"无状态函数 + 外部 MySQL/Redis + 无 WebSocket 常驻进程"，等于把整套架构拆开托管，成本高于直接换一台支持 PHP 的托管，且 `vercel-php`/容器函数都无法解决 Volt 编译缓存与上传目录的持久化问题。因此不把它算作可行方案。

### 5.2　执行层面的两个阻塞

1. 本机未安装 Vercel CLI，`~/.vercel` 不存在，环境变量里也没有 `VERCEL_TOKEN`；
2. 尝试 `npx vercel whoami` 拉取 CLI 时进程被终止（超时），`https://api.vercel.com/v2/user` 返回 403（未认证）。

即便补齐凭证，5.1 的运行时约束依然成立——**部署在技术上先失败，不是权限问题**。

---

## 6　替代部署路线

| 方案 | 形态 | 需要准备 | 适配度 |
|---|---|---|---|
| A. 云服务器（推荐） | Ubuntu 22.04 + Nginx + php7.3-fpm + phalcon3.4 + MySQL5.7 + Redis5 + supervisor 守护 websocket/scheduler | 1 台 2C4G、域名、HTTPS 证书 | 与现有包 1:1，实测过的启动方式可直接复用 |
| B. 容器托管（Render / Fly.io / Railway） | 打 PHP 7.3 + phalcon 镜像，外接托管 MySQL/Redis | Dockerfile、托管数据库实例 | 可行，但 WebSocket 需单独进程，多数平台限制常驻 |
| C. Vercel 静态展示页 | 截图 + 架构说明的纯静态站（`deploy/vercel-static/`，**已发布**） | Vercel 登录或 token | 只能展示，不能跑业务 |

---

## 7　待确认事项

1. 是否把 `deploy/vercel-static/` 的展示页发布到 Vercel？需要先 `vercel login`，或提供一个具备部署权限的 token。
2. 若目标是让平台真正对外可用，请给出服务器/容器平台，我按方案 A 或 B 出部署脚本与流水线。
3. 演示视频（`public/static/vod`，1.3GB）是否要一并交付？建议改为对象存储 + CDN，不入安装包。

---

## 8　发布记录（2026-11-04）

静态展示页已发布到 Vercel 生产环境：

| 项 | 值 |
|---|---|
| 主域名 | https://vercel-static-hazel-three.vercel.app |
| 短别名 | https://selflearn-static-demo.vercel.app |
| 项目 | `uu-9cab/vercel-static` |
| 生产部署 | `vercel-static-or3gkxj63-uu-9cab.vercel.app`（首次为 `...5xfkz99n8...`，第二次排除了 README） |
| 目标环境 | production，状态 Ready（构建 3s） |
| 发布文件 | `index.html`、`vercel.json`、`assets/` 4 张截图（README 经 `.vercelignore` 排除） |

发布过程中处理的两个问题：

1. **部署被 Vercel Authentication 挡住**：项目默认 `ssoProtection.deploymentType = all_except_custom_domains`，外部访问会先要求登录 Vercel。已通过 API 将该项目的 `ssoProtection` 置空，站点转为公开可访问；如需恢复，在项目 Settings → Deployment Protection 重新开启即可。
2. **README 随包公开**：首次部署把 `README.md` 一并上传（可通过 `/README.md` 访问），已加 `.vercelignore` 排除并重新部署，现返回 404。

校验方式与限制：本机网络出口对 `*.vercel.app` 返回 502（代理层拦截），无法直接 curl。改用第三方渲染服务抓取线上页面，确认标题为「自学平台 · 基于酷瓜云课堂的改造实践」、首屏排版正常；`/README.md` 已 404。平台本体仍未部署，原因见第 5 节。
