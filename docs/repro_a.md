# 1　复现目标与环境基线

## 1.1　复现目标

本次复现的对象是开源网校系统**酷瓜云课堂（Course Tencent Cloud，简称 CTC）**。目标不是把项目跑起来看一眼，而是交付一套**可在任意一台干净的 Windows 机器上重复执行、结果一致**的落地流程，并回答三个问题：依赖到底要哪些版本、启动到底按什么顺序、出错时如何一次定位到位。

具体目标拆解为四条：

1. 在 Windows 上原生搭建 PHP 7.3 + Phalcon 3.4 + MySQL 5.7 + Redis 的运行时，不依赖 Docker、WSL 或虚拟机；
2. 用脚本完成建库、迁移与演示数据初始化，使平台具备可浏览的课程内容；
3. 验证课程浏览、用户登录、后台管理等核心链路，并留存可核对的证据；
4. 对过程中出现的每一个失败点给出根因与可重复的修复步骤，形成“照做即可”的操作手册。

## 1.2　复现对象

| 项目 | 内容 |
|---|---|
| 项目名称 | 酷瓜云课堂（Course Tencent Cloud） |
| 仓库地址 | https://gitee.com/koogua/course-tencent-cloud |
| 获取方式 | 仓库 master 分支归档包（`repository/archive/master.zip`），复现日期 2026-11-03 |
| 程序版本 | 后台首页显示 `CTC 1.8.3` |
| 开源协议 | GPL-2.0 |
| 技术栈 | Phalcon 3.4（C 扩展 MVC 框架）+ Layui 2.x + MySQL 5.7 + Redis 5.0 |
| 业务范围 | 点播、直播、专栏、问答、会员、积分、订单 |

> 说明：GPL-2.0 协议要求衍生分发同样开源。本次复现仅用于本地技术验证，未修改协议声明，也未对外分发二进制。

## 1.3　验收标准

复现是否成功，不以“能打开首页”为准，而以以下六条硬指标为准。全部满足才算通过。

| 编号 | 验收项 | 判定标准 |
|---|---|---|
| A-01 | 服务可启动 | MySQL、Redis、PHP 三个进程同时监听 3306 / 6379 / 8000 |
| A-02 | 首页可渲染 | `GET /` 返回 200，页面含课程卡片与站内导航 |
| A-03 | 课程可浏览 | `GET /course/list` 返回 200；分页接口返回 6 门课程；详情页 200 |
| A-04 | 前台可登录 | `POST /account/password/login` 返回 `code=0`，后续请求保持登录态 |
| A-05 | 后台可登录 | `POST /admin/login` 成功，仪表盘与课程管理页返回 200 |
| A-06 | 流程可重复 | 执行停止脚本后再执行启动脚本，A-01 至 A-05 全部复现 |

## 1.4　环境基线

| 项目 | 实测值 |
|---|---|
| 操作系统 | Windows 11（内核 10.0.22000），x64 |
| 处理器 / 内存 | x64 多核，≥ 8 GB（MySQL 与 PHP 常驻约 300 MB） |
| 磁盘可用空间 | ≥ 3 GB（实测占用约 2.8 GB，含 MySQL 数据目录与安装包缓存） |
| 运行时根目录 | `C:\ctc`（**必须是纯 ASCII 路径**） |
| 站点端口 | 8000（HTTP）、3306（MySQL）、6379（Redis） |
| Shell | 命令以 cmd 为准；Git Bash 亦可，但需注意同名命令冲突（见 6.9） |

关于路径有一条硬性约束：**不要把运行时放在含中文或空格的目录下**。Phalcon 的注解解析、Composer 的解压进程、MySQL 的 `--defaults-file` 在非 ASCII 路径下都出现过异常行为。项目源码本身可以放在中文目录，但运行副本必须落在 `C:\ctc`。

# 2　依赖清单与目录布局

## 2.1　依赖矩阵

下表是本次实际落盘的版本，不是“建议版本”。每一项都标注了获取来源，便于离线复刻时逐个比对。

| 组件 | 版本 | 获取来源 | 落盘路径 | 作用 |
|---|---|---|---|---|
| PHP | 7.3.33（NTS，VC15，x64） | windows.php.net `/downloads/releases/archives/` | `C:\ctc\php` | 运行时 |
| Phalcon 扩展 | 3.4.5（build 4250，php7.3 nts vc15 x64） | GitHub `phalcon/cphalcon` Release v3.4.5 资产 | `php\ext\php_phalcon.dll` | MVC 框架本体 |
| redis 扩展 | 5.3.5（7.3 nts vc15 x64） | windows.php.net PECL releases | `php\ext\php_redis.dll` | 缓存与会话 |
| igbinary 扩展 | 3.2.4（7.3 nts vc15 x64） | windows.php.net PECL releases | `php\ext\php_igbinary.dll` | 缓存序列化 |
| MySQL | 5.7.38（免安装 zip） | 阿里云镜像 `mirrors.aliyun.com/mysql/MySQL-5.7/` | `C:\ctc\mysql` | 主数据库 |
| Redis | 5.0.14.1（Windows 移植版） | GitHub `tporadowski/redis` Release | `C:\ctc\redis` | 缓存/会话/队列 |
| Composer | 2.9.2 | 阿里云 Composer 镜像 | `C:\ctc\dl\composer.phar` | 依赖管理 |
| 项目依赖 | 33 个包目录（含 tencentcloud-sdk、phinx、workerman 等） | 阿里云 Composer 镜像 | `www\vendor` | 业务依赖 |

> 版本选择的关键是 **PHP 主次版本 + 线程安全 + 编译工具链三者必须与 Phalcon DLL 完全对齐**。Phalcon 3.4.5 只提供 PHP 7.0–7.3 的 Windows 预编译包，因此 PHP 只能锁在 7.3；后缀 `nts`（非线程安全）与 `vc15`（VS2017 工具链）也必须一致，装错任意一项都会在启动时报 "Unable to load dynamic library"。

## 2.2　目录布局

运行时目录与源码目录分离，是这套方案可维护的前提。源码在 `www`，其余都是“环境”，环境坏了可以整体重装而不动代码。

```
C:\ctc\
├─ php\                  PHP 7.3.33 + php.ini + ext\*.dll
├─ mysql\                MySQL 5.7.38（含 data\ 数据目录）
├─ redis\                Redis 5.0.14.1 + redis.conf
├─ www\                  项目源码（站点根目录为 www\public）
├─ logs\                 运行日志（php_error.log、mysql_error.log）
├─ dl\                   安装包与 composer.phar（可删）
├─ tmp\                  临时文件
├─ my.ini                MySQL 配置
└─ polyfill.php          Windows 兼容补丁（见 6.6）
```

## 2.3　关键配置

### 2.3.1　php.ini 要点

```ini
extension_dir = "C:\ctc\php\ext"
auto_prepend_file = "C:/ctc/polyfill.php"
date.timezone = Asia/Shanghai
memory_limit = 512M
upload_max_filesize = 64M
post_max_size = 64M
extension=php_curl.dll
extension=php_fileinfo.dll
extension=php_gd2.dll
extension=php_mbstring.dll
extension=php_openssl.dll
extension=php_pdo_mysql.dll
extension=php_mysqli.dll
extension=php_intl.dll
extension=php_phalcon.dll
extension=php_redis.dll
extension=php_igbinary.dll
opcache.enable = 0
```

`opcache.enable=0` 是刻意为之：复现阶段需要看到真实报错行号，开启 opcache 后部分错误提示会指向缓存文件，反而增加定位成本。验证通过后再开启可提升性能。

### 2.3.2　my.ini 要点

```ini
[mysqld]
basedir=C:/ctc/mysql
datadir=C:/ctc/mysql/data
port=3306
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci
sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
log-error=C:/ctc/logs/mysql_error.log
log_syslog=0
```

有两个细节必须保留：`character-set-server=utf8mb4` 保证课程标题里的中文与 emoji 不乱码；`log_syslog=0` 避免在没有管理员权限时反复写 Windows 事件日志失败（表现为启动日志里出现 "Cannot open Windows EventLog" 的 ERROR 行，容易被误判为致命错误）。

### 2.3.3　config.php 改动

项目自带 `config/config.default.php` 模板，复制为 `config/config.php` 后修改以下 7 处，其余保持默认。

| 配置键 | 原值（容器环境） | 本地值 |
|---|---|---|
| `env` | `pro` | `dev`（显示错误，便于排障） |
| `db.host` | `mysql` | `127.0.0.1` |
| `db.username` | `ctc` | `root` |
| `db.password` | `1qaz2wsx3edc` | 空 |
| `redis.host` | `redis` | `127.0.0.1` |
| `redis.auth` | `1qaz2wsx3edc` | 空 |
| `websocket.connect_address` | `your_domain.com:8282` | `127.0.0.1:8282` |

### 2.3.4　redis.conf

```
port 6379
bind 127.0.0.1
protected-mode yes
save ""
appendonly no
```

关闭持久化是刻意的：缓存与会话都可重建，关掉 RDB/AOF 可以避免 Windows 下 `fork` 失败导致的抖动。

## 2.4　与官方部署方式的差异

官方推荐的是 Linux + Nginx + PHP-FPM 容器编排。本次改用“PHP 内置服务器 + 原生 MySQL/Redis”，差异集中在四处，每一处都在第 6 章有对应的踩坑记录。

| 差异点 | 官方方式 | 本次方式 | 影响 |
|---|---|---|---|
| Web 服务器 | Nginx + `?_url=` 重写 | PHP 内置服务器 + `router.php` 模拟重写 | 见 6.3 |
| 静态资源 | 腾讯云 COS 域名 | 本站静态目录 + 后缀拦截 | 见 6.8 |
| 进程模型 | 多进程 + 常驻 | 单进程，仅用于验证 | 不可压测 |
| 检索 | xunsearch 独立守护进程 | 未启用 | 搜索页不可用，见 7.1 |

# 3　分步搭建流程

以下命令均以 `cmd` 为例，工作目录按步骤注明。每一步末尾给出“验证动作”，验证不通过不要进入下一步，否则后面所有报错都是连锁反应。

## 3.1　第一步：安装 PHP 与扩展

1. 下载 `php-7.3.33-nts-Win32-VC15-x64.zip`，解压到 `C:\ctc\php`；
2. 下载 Phalcon 3.4.5 的 `phalcon_x64_vc15_php7.3_3.4.5-4250_nts.zip`，把其中的 `php_phalcon.dll` 放入 `C:\ctc\php\ext`；
3. 下载 `php_redis-5.3.5-7.3-nts-vc15-x64.zip` 与 `php_igbinary-3.2.5-7.3-nts-vc15-x64.zip`，同样放入 `ext`；
4. 按 2.3.1 编写 `php.ini`；
5. 验证扩展是否全部加载：

> `C:\ctc\php\php.exe -v` ； `C:\ctc\php\php.exe -m` ； `C:\ctc\php\php.exe -r "echo \Phalcon\Version::get();"`

验证动作：`php -v` 输出 `PHP 7.3.33 (cli) ( NTS MSVC15 )`；`php -m` 中同时出现 `phalcon`、`redis`、`igbinary`、`pdo_mysql`；Phalcon 版本输出 `3.4.5`。

> 注意：不要用 `php -r "echo PHALCON_VERSION;"` 验证。Phalcon 3 没有这个全局常量，PHP 会把未定义常量当字符串输出，导致误判为“已安装”。

## 3.2　第二步：安装 MySQL

1. 下载 `mysql-5.7.38-winx64.zip`，解压并将目录改名为 `C:\ctc\mysql`；
2. 按 2.3.2 编写 `C:\ctc\my.ini`；
3. 初始化数据目录（只需一次）：

> `C:\ctc\mysql\bin\mysqld.exe --defaults-file=C:/ctc/my.ini --initialize-insecure --console`

4. 启动服务（前台运行，便于观察日志）：

> `C:\ctc\mysql\bin\mysqld.exe --defaults-file=C:/ctc/my.ini --console`

5. 另开一个窗口创建数据库：

> `C:\ctc\mysql\bin\mysql.exe -h 127.0.0.1 -u root -e "CREATE DATABASE ctc DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"`

验证动作：`mysqladmin -h 127.0.0.1 -u root ping` 返回 `mysqld is alive`；`SHOW DATABASES` 中出现 `ctc`。

`--initialize-insecure` 会创建空口令的 root，仅限本机验证环境使用。若需对外暴露，务必先执行 `ALTER USER 'root'@'localhost' IDENTIFIED BY '强口令'` 并同步修改 `config.php`。

## 3.3　第三步：安装 Redis

1. 下载 `Redis-x64-5.0.14.1.zip`，解压到 `C:\ctc\redis`；
2. 按 2.3.4 编写 `redis.conf`；
3. 启动：

> `C:\ctc\redis\redis-server.exe C:\ctc\redis\redis.conf`

验证动作：`redis-cli -p 6379 ping` 返回 `PONG`；`redis-cli info server` 显示 `redis_version:5.0.14.1`。

## 3.4　第四步：获取源码并安装依赖

1. 解压源码到 `C:\ctc\www`；
2. 复制配置模板并修改：

> `copy C:\ctc\www\config\config.default.php C:\ctc\www\config\config.php`

3. 安装 Composer 依赖（**必须设置超时**，原因见 6.1）：

> `cd /d C:\ctc\www` ； `set COMPOSER_PROCESS_TIMEOUT=1800` ； `C:\ctc\php\php.exe C:\ctc\dl\composer.phar install --no-dev --no-interaction --prefer-dist`

验证动作：`www\vendor` 目录生成，`vendor\autoload.php` 存在，命令末尾输出 `Generating autoload files`。

`--no-dev` 会跳过 `phalcon/ide-stubs` 等开发依赖，不影响运行与迁移。整套依赖约 245 MB、33 个包目录，其中 `tencentcloud/tencentcloud-sdk-php` 单个就有 40 MB。

## 3.5　第五步：数据库迁移

项目使用 Phinx 管理表结构，`db/migrations` 下有 28 个迁移文件，必须在站点启动前执行。

> `cd /d C:\ctc\www` ； `C:\ctc\php\php.exe vendor\bin\phinx migrate -c phinx.php`

验证动作：输出以 `All Done. Took x.xxxxs` 结尾；`SHOW TABLES` 出现 68 张表（`kg_account`、`kg_course`、`kg_chapter`、`kg_setting` 等）。

迁移脚本会自动写入三类初始数据：一个官方账号（`10000@163.com`）、角色定义与导航菜单。**但不会写入任何课程数据**，所以迁移完成后首页是空的，这一步很容易被误判为“迁移失败”。

## 3.6　第六步：初始化演示数据

仓库没有提供 seed 文件，`db/seeds` 目录不存在。为了能验证课程浏览，本次编写了 `tools\seed_demo.php`，通过项目自身的 Model 写入数据（而不是直接 INSERT），以保证 `attrs`、时间戳、计数字段与业务逻辑一致。

> `cd /d C:\ctc\www` ； `C:\ctc\php\php.exe tools\seed_demo.php`

脚本做三件事：

1. 把存储配置 `cos.protocol` / `cos.domain` 指向本站静态目录，使封面不再依赖外网 CDN；
2. 创建 7 个一级分类（警务业务知识、网络安全、数据库、容器与部署、计算机视觉、Python 与算法、前端开发，`priority` 越小越靠前）；
3. 创建 6 门课程，每门 2 章、每章 2 课时，共 12 章 24 课时。

验证动作：输出 6 行 `created: ...`；执行 `SELECT COUNT(*) FROM kg_course` 得到 6。

> 脚本是幂等的：同名课程已存在时输出 `skip:` 并跳过，重复执行不会产生重复数据。

## 3.7　第七步：启动站点

1. 编写 `www\router.php`（内容见附录 A），作用是把内置服务器的请求转交给 Phalcon；
2. 启动时必须把工作目录切到 `public`：

> `cd /d C:\ctc\www\public` ； `C:\ctc\php\php.exe -S 127.0.0.1:8000 ..\router.php`

验证动作：浏览器访问 `http://127.0.0.1:8000/` 出现课程卡片；控制台无 `Fatal error`。

工作目录是硬要求。`public/index.php` 用相对路径 `require '../bootstrap/Kernel.php'`，在 `www` 根目录启动会去找 `C:\ctc\bootstrap`，直接 500。

## 3.8　第八步：重置演示账号口令

迁移脚本写入的初始口令哈希无法反推。用项目自带的维护命令重置，避免手工改库：

> `cd /d C:\ctc\www` ； `C:\ctc\php\php.exe console.php maintain reset_password 10000@163.com 123456`

验证动作：输出 `------ reset password success ------`；`kg_account` 中该行的 `salt` 与 `password` 已变化。该账号同时具备学员与管理员身份（`edu_role=2`、`admin_role=1`），前后台都能登录，适合做端到端验证。

# 4　启动、停止与日常复用

## 4.1　一键脚本

手工开三个窗口对新手不友好，因此提供三个脚本。`repro` 目录下的启停脚本是薄封装，真正的实现放在 `C:\ctc\start_stack.ps1` 与 `stop_stack.ps1`，避免两份逻辑各自演化。

| 脚本 | 位置 | 作用 |
|---|---|---|
| `start_all.bat` | `repro`（封装）+ `C:\ctc` | 启动三个服务并做健康检查 |
| `stop_all.bat` | 同上 | 优雅停止三个服务 |
| `install_autostart.bat` | `repro` | 安装或重装登录自启项 |

启动脚本做四件事，顺序固定为 Redis → MySQL → PHP：

1. **先探测端口**，已在监听就跳过，重复执行不会起两份进程；
2. **按端口轮询等就绪**（Redis 15 秒、MySQL 45 秒、PHP 20 秒），不靠固定 `sleep` 猜时间；
3. **失败时自动取证**，MySQL 起不来直接打印 `mysql_error.log` 末 8 行，不用再去翻文件；
4. **健康检查看正文大小，不只看状态码**。应用在 Redis 或 MySQL 掉线时仍然返回 HTTP 200，但正文是一个 100 字节的 `Fatal error` 存根，只看 200 会把故障判成正常。

成功时的输出：

```
[1/3] Redis    already listening on 6379
[2/3] MySQL    ready
[3/3] PHP      ready
[4/4] HTTP     OK (7384 bytes)
RESULT: all services up
```

停止脚本不能用 `taskkill /F` 直接杀 `mysqld`。强杀会导致 InnoDB 进入恢复流程，下次启动时间变长，极端情况下丢事务。脚本里改用 `mysqladmin shutdown`，走的是正常关闭路径。

## 4.2　手工启动（排障用）

自动化脚本掩盖细节，排障时要能手动复现。三个进程的启动顺序固定为 Redis → MySQL → PHP，因为 PHP 启动后立刻会连 Redis 与 MySQL，顺序反了首页会 500。

| 顺序 | 命令 | 工作目录 |
|---|---|---|
| 1 | `redis-server.exe C:\ctc\redis\redis.conf` | `C:\ctc\redis` |
| 2 | `mysqld.exe --defaults-file=C:/ctc/my.ini --console` | `C:\ctc` |
| 3 | `php.exe -S 127.0.0.1:8000 ..\router.php` | `C:\ctc\www\public` |

手工启动有两个坑，都踩过：

- **不要把输出接管道**。`mysqld --console | head -30` 这种写法，`head` 读满 30 行退出后管道关闭，`mysqld` 下一次写日志就会因管道断开而终止。日志里能看到 `ready for connections`，进程却已消失，非常容易误判。要看输出就用重定向写文件。
- **不要让它依附在会被回收的终端上**。远程会话、脚本任务、IDE 内置终端关闭时，子进程可能被一并结束。日常使用走 4.1 的脚本或 4.4 的自启项，进程由系统托管，与终端无关。

## 4.3　重启与清缓存

改动课程数据、分类或站点设置后，如果页面没有变化，先清 Redis 再刷新。缓存键没有统一前缀，逐条删不如整库清空：

> `C:\ctc\redis\redis-cli.exe -p 6379 -n 0 flushdb`

清空会同时清掉会话，需要重新登录。这在验证时是优点（能顺便复测登录），在日常使用时要留意。

## 4.4　开机自启与重启后恢复

本机没有常驻机制时，重启一次网站就打不开：三个服务都是手工拉起的普通进程，谁能活下来取决于当初怎么启动。要做到「重启后打开链接就能用」，必须让系统在登录时自动拉起。

### 采用方案：启动文件夹

本机安全策略把 `schtasks.exe` 列入程序黑名单，创建计划任务会直接返回「拒绝访问」，因此改用用户级启动文件夹，效果等价、不需要管理员权限：

> `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\CTC-Web-Stack.vbs`

这个 VBS 只有一行有效代码，用隐藏窗口调用 `C:\ctc\start_stack.ps1`，登录后自动拉起三个服务且不弹黑窗。安装或重装执行：

> `repro\install_autostart.bat`

### 与计划任务、Windows 服务的差别（如实说明）

| 方式 | 触发时机 | 是否需要管理员 | 本机是否采用 |
|---|---|---|---|
| 启动文件夹 | 用户**登录后** | 否 | 是 |
| 计划任务 | 可设为开机或登录 | 部分场景需要 | 否，`schtasks.exe` 被策略拦截 |
| 注册为 Windows 服务 | 开机即起，不依赖登录 | 是（`mysqld --install`） | 否，当前账户无提权 |

差别在于：如果机器重启后停在登录界面、没人登录，启动文件夹不会触发。要彻底做到「开机即起」，需要用管理员权限把 MySQL、Redis 注册成服务（`mysqld --install`、`redis-server --service-install`），再把 PHP 内置服务器包一层。这一步没有提权做不了，因此当前方案以「登录后自动恢复」为准。

### 重启后四步自查

| 步骤 | 命令 | 通过判据 |
|---|---|---|
| 1 查端口 | `netstat -ano -p TCP` | 3306、6379、8000 三行 `LISTENING` |
| 2 查正文 | `curl.exe -s -o NUL -w "%{size_download}" http://127.0.0.1:8000/` | 大于 5000 字节 |
| 3 查日志 | `C:\ctc\logs\mysql_error.log`、`php_error.log` 尾部 | 无 `connection refused`、无 `Fatal error` |
| 4 重拉 | `repro\start_all.bat` | 输出 `RESULT: all services up` |

第 2 步是关键。服务没起来时页面仍返回 200，正文只有 100 字节：

> `<b>Fatal error</b>: in <b>C:\ctc\www\app\Providers\Session.php</b> on line <b>36</b>`

这行报错看着像代码缺陷，实际含义是 Redis 会话初始化失败——`Session.php` 第 36 行调用 `$session->start()`，连不上 Redis 就抛异常，而异常消息为空，所以只剩光秃秃的 `Fatal error`。遇到它先查 6379 端口，不要改代码。

# 5　核心功能验证

## 5.1　验证方法

验证不只看截图，而是三条证据链交叉印证：**HTTP 状态码**（服务是否响应）、**页面文本**（内容是否正确渲染）、**数据库计数**（数据是否真正落库）。截图作为最终呈现，附在 5.3 节。

## 5.2　验证结果

| 编号 | 验证项 | 方法 | 预期 | 实测 | 结论 |
|---|---|---|---|---|---|
| V-01 | 首页 | `GET /` | 200 且含课程卡片 | 200，29 KB，6 张卡片 | 通过 |
| V-02 | 课程列表页 | `GET /course/list` | 200 | 200，含方向/类型/难度筛选 | 通过 |
| V-03 | 课程分页接口 | `GET /course/pager` | 返回课程条目 | 200，6 门课程、6 个标题 | 通过 |
| V-04 | 课程详情 | `GET /course/1` | 200 且标题正确 | 200，标题“前端开发实战：从页面到交互” | 通过 |
| V-05 | 课程目录 | 详情页“目录”标签 | 2 章 4 课时 | 第一章/第二章各 2 课时，顺序正确 | 通过 |
| V-06 | 前台登录 | `POST /account/password/login` | `code=0` | `{"location":"/","msg":“登录账号成功”,"code":0}` | 通过 |
| V-07 | 登录态保持 | 登录后访问 `/` | 显示用户名 | 右上角显示“酷瓜云课堂”，出现发布/消息入口 | 通过 |
| V-08 | 后台登录 | `POST /admin/login` | `code=0` | `{"location":"/admin","code":0,"msg":""}` | 通过 |
| V-09 | 后台仪表盘 | `GET /admin/main` | 200 且统计正确 | 200，用户数 1、课程数 6、磁盘 455 GB | 通过 |
| V-10 | 后台课程管理 | `GET /admin/course/list` | 200 且列出课程 | 200，6 行，含分类/讲师/课时/上下架开关 | 通过 |
| V-11 | 后台分类管理 | `GET /admin/category/list` | 200 | 200，7 个分类 | 通过 |
| V-12 | 静态资源 | `GET /static/...` | 200 | 200，CSS/JS/封面均正常 | 通过 |

数据一致性核对：`kg_course` 6 条、`kg_category` 6 条、`kg_chapter` 一级 12 条 / 二级 24 条、`kg_account` 1 条，与页面呈现一致。

## 5.3　界面证据

首页是整站可用性的第一道体检。下面的截图同时验证了三件事：模板引擎（Volt）编译正常、静态资源可访问、数据库查询有结果。

[IMG:repro_home.png]　图 5-1　首页：6 门课程卡片、封面图与课时数均正常渲染

课程列表页的筛选条来自分类表，卡片来自分页接口。这一页能正常显示，说明“控制器 → 服务层 → 模型 → 视图”整条链路是通的。

[IMG:repro_list.png]　图 5-2　课程列表：方向/类型/难度筛选与 AJAX 分页均生效

详情页的“目录”标签是二级联动，点开后才请求章节接口。它比详情页本身更能说明数据模型是否正确。

[IMG:repro_detail.png]　图 5-3　课程详情：2 章 4 课时，章节与课时顺序正确

登录成功后页面右上角的“登录/注册”会被用户名替换，这是会话生效的直接证据，比看 Cookie 更直观。

[IMG:repro_login.png]　图 5-4　登录后：右上角显示用户名与发布、消息入口

后台与前台共用同一账号体系，但走独立的 SessionService。仪表盘能出统计数据，说明后台的权限校验、模板与统计查询都正常。

[IMG:repro_admin.png]　图 5-5　后台仪表盘：用户数、课程数、磁盘空间等统计正常

[IMG:repro_admin_course.png]　图 5-6　后台课程管理：6 门课程及分类、讲师、课时、上下架状态
