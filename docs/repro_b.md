# 6　问题定位与解决记录

本章是整份文档的核心。下面 12 个问题全部是本次复现中真实出现的，不是假设。每条按“现象 → 根因 → 处置 → 可重复性”四段记录，其中根因部分给出判断依据，避免只记结论、下次换个环境又踩一遍。

## 6.1　Composer 安装卡在解压阶段

**现象**：`composer install` 进行到 69/70 时停滞，终端停在 `Installing tencentcloud/tencentcloud-sdk-php (3.0.889): Extracting archive`，约 5 分钟后抛出 `The process "unzip.EXE -qq ..." exceeded the timeout of 300 seconds`，安装中断。

**根因**：Composer 检测不到 PHP 的 `zip` 扩展时，会回退调用外部 `unzip` 命令。本次 PHP 7.3.33 的 Windows 包里恰好没有 `php_zip.dll`，于是 Composer 使用了 Git 自带的 `unzip.exe`；而 `tencentcloud-sdk-php` 解压后是数万个文件，叠加杀毒软件实时扫描，耗时远超 Composer 默认的 300 秒进程超时。

**处置**：把进程超时放大后重跑，已下载的包会复用缓存，实际只需要补装 1 个包：

> `set COMPOSER_PROCESS_TIMEOUT=1800` ； `C:\ctc\php\php.exe C:\ctc\dl\composer.phar install --no-dev --no-interaction --prefer-dist --no-progress`

**可重复性**：稳定复现。凡是同时满足“无 zip 扩展”和“含超大依赖包”两个条件，必然触发。若想根治，可换一个带 `php_zip.dll` 的 PHP 构建，让 Composer 走内置解压。

## 6.2　启动即 500：相对路径找不到引导文件

**现象**：访问首页返回 500，页面直接打印 `require(../bootstrap/Kernel.php): failed to open stream: No such file or directory`。

**根因**：`public/index.php` 使用相对路径引入引导文件，依赖进程的当前工作目录。若在 `C:\ctc\www` 下启动 `php -S ... -t public`，工作目录是 `www`，`../bootstrap` 就指向了不存在的 `C:\ctc\bootstrap`。

**处置**：把工作目录切到 `public` 再启动：

> `cd /d C:\ctc\www\public` ； `C:\ctc\php\php.exe -S 127.0.0.1:8000 ..\router.php`

**可重复性**：必然复现。判断依据是错误信息里的路径，只要看到 `C:\ctc\bootstrap` 而不是 `C:\ctc\www\bootstrap`，就是工作目录错了。

## 6.3　所有路由都返回首页

**现象**：`/`、`/course/list`、`/admin`、`/account/login` 返回的 HTML 长度完全相同（4354 字节），只有 CSRF token 不同，标题一律是“酷瓜云课堂”。

**根因**：Phalcon 的 Router 从 `$_GET['_url']` 读取“重写后的 URI”。官方部署依赖 Nginx 的 `rewrite ^(.*)$ /index.php?_url=$1 last;`，而 PHP 内置服务器不做任何重写，`_url` 为空，路由器便回落到默认的 `home/index/index`，于是所有地址都渲染首页。

**处置**：在 `router.php` 中手工模拟这条重写规则，把请求路径写入 `$_GET['_url']`，同时把 `PHP_SELF`、`SCRIPT_NAME` 统一改为 `/index.php`：

> `$_GET['_url'] = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);`

**可重复性**：必然复现，且症状极具迷惑性——页面能打开、样式正常，只是内容永远一样。识别方法是比对不同 URL 的响应长度，或直接看 `<title>`。

## 6.4　Redis 缓存后端与 Phalcon 签名不兼容

**现象**：首页 500，日志记录 `Declaration of App\Library\Cache\Backend\Redis::save($keyName = NULL, $content = NULL, $lifetime = NULL, bool $stopBuffer = true): bool must be compatible with Phalcon\Cache\Backend\Redis::save(..., $stopBuffer = NULL)`。

**根因**：子类在第四个参数上加了 `bool` 类型声明，父类 Phalcon 3.4.5 的同名方法没有类型。PHP 的参数类型规则不允许子类收窄参数类型，直接抛致命错误。这是项目代码与 3.4.5 这一具体补丁版本之间的签名差异，与配置无关。

**处置**：去掉参数类型声明，保留默认值与方法体逻辑：

> `public function save($keyName = null, $content = null, $lifetime = null, $stopBuffer = true)`

**可重复性**：必然复现。受影响的是所有经过 Redis 缓存的页面，因此它会在首页第一个请求就暴露，不会藏到深层功能里。

## 6.5　缓存序列化缺少 igbinary

**现象**：修好 6.4 后首页仍 500，日志为 `Call to undefined function igbinary_serialize()`，调用栈指向 `Phalcon\Cache\Frontend\Igbinary->beforeStore()`。

**根因**：项目的缓存前端指定使用 Igbinary 序列化器，而该能力由 PHP 扩展提供，默认不包含在 PHP 主包里。

**处置**：安装与 PHP 7.3 NTS VC15 x64 匹配的 `php_igbinary.dll`（3.2.5 包，扩展自报 3.2.4），在 `php.ini` 追加 `extension=php_igbinary.dll` 并重启 PHP。

**可重复性**：必然复现。注意 `igbinary` 与 `redis` 是两个独立扩展，只装 redis 不够。

## 6.6　后台首页 500：POSIX 函数缺失

**现象**：前台正常，进入 `/admin/main` 立即 302 跳到 `/error/500`，日志为 `Call to undefined function App\Library\Utils\sys_getloadavg()`。

**根因**：`sys_getloadavg()` 是 POSIX 接口，Windows 的 PHP 没有实现。后台仪表盘用它取系统负载，属于典型的“Linux 能跑、Windows 必崩”。

**处置**：两层兜底。第一层是 `C:\ctc\polyfill.php`，通过 `php.ini` 的 `auto_prepend_file` 在全局定义该函数，覆盖命令行任务（`scheduler.php`、`ServerMonitorTask`）；第二层是在调用点显式判断：

> `$load = function_exists('sys_getloadavg') ? sys_getloadavg() : [0, 0, 0];`

**可重复性**：必然复现。补充说明：在本次的内置服务器 SAPI 下，仅靠 `auto_prepend_file` 并未让命名空间内的调用解析到全局函数，因此最终以调用点判断为准；polyfill 保留给 CLI 任务使用。

## 6.7　后台服务器信息空白

**现象**：仪表盘“服务器信息”卡片的磁盘、内存、负载三项数值为空或为 0。

**根因**：三处平台假设。`disk('/')` 在 Windows 下 `/` 不是有效盘符，`disk_free_space()` 返回 false；`memory()` 直接读 `/proc/meminfo`，这是 Linux 专有文件；负载则依赖 6.6 的函数。

**处置**：`disk()` 的默认目录按分隔符判断，Windows 取 `C:/`；`memory()` 增加 Windows 分支，用 `wmic OS get TotalVisibleMemorySize,FreePhysicalMemory` 取值，取不到时返回 0 而不是报错。

**可重复性**：必然复现。**环境限制**：本机安全策略禁用了 `wmic.exe`，因此内存一项仍显示 0，磁盘与负载正常。这不是代码问题，换一台未禁用 wmic 的机器即可显示真实值。

## 6.8　课程封面全部 404

**现象**：课程卡片位置有图框无图，请求地址形如 `/static/cover/c1.png!cover_270`，返回 404。

**根因**：封面 URL 由“存储域名 + 对象键 + 样式后缀”拼接。项目默认把域名配成腾讯云 COS 桶，样式后缀 `!cover_270` 是 COS 的图片处理语法；本地既没有该桶，静态服务器也不认识这个后缀。

**处置**：两步。其一，把站点设置里的 `cos.protocol` 改为 `http`、`cos.domain` 改为 `127.0.0.1:8000/static`，让 URL 指向本站；其二，`router.php` 识别 `!style` 后缀，命中基础文件时直接输出并带正确的 `Content-Type`。

**可重复性**：必然复现。若跳过这一步，页面结构正常但所有封面是裂图，容易被误认为“图片上传功能坏了”。

## 6.9　课程目录章节顺序颠倒

**现象**：课程详情页的“目录”里，“第二章”排在“第一章”之上，课时顺序同样倒置。

**根因**：章节列表按 `priority` 升序排列，而种子脚本沿用了“数值越大越靠前”的直觉，写成递减（10、9、8…），结果正好相反。

**处置**：种子脚本改为递增（1、2、3…）；对已生成的数据执行 `UPDATE kg_chapter SET priority = id`，因为主键自增顺序恰好等于期望顺序。

**可重复性**：必然复现。这类问题不影响功能可用性，但会让人怀疑数据错乱，属于必须修掉的“低级错误”。

## 6.10　批处理脚本在 Git Bash 下失效

**现象**：在 Git Bash 里执行 `cmd //c start_all.bat`，输出 `find: '/I': No such file or directory`、`timeout: invalid time interval '/t'`，服务虽被拉起，但等待逻辑与重复启动判断全部失效。

**根因**：脚本里用了 `find /I`、`timeout /t` 这些 Windows 命令，而 Git Bash 的 PATH 中 `/usr/bin/find`、`/usr/bin/timeout` 优先级更高，被 Unix 同名程序接管。在资源管理器里双击运行则不受影响。

**处置**：脚本改为用 PowerShell 做进程存在性判断、端口占用判断与等待轮询，不再依赖 `find`/`timeout`；同时给 Redis 单独写 `redis.conf`，避免命令行传空字符串参数被吞。

**可重复性**：仅在“用 Git Bash 调 bat”这一组合下复现。修复后两种执行方式结果一致。

## 6.11　下载环节的两个坑

**现象一**：从 GitHub Release 直接下载 Phalcon 的 DLL 资产时，连接被重置（`curl: (52) Empty reply from server`）。

**处置**：改用 GitHub 加速镜像拼接原始地址下载，文件大小与 Release 页面标注一致（1.8 MB），校验后使用。

**现象二**：从 MySQL 官方 CDN 下载 5.7.44 安装包，速度仅约 47 KB/s，6 分钟只完成 17 MB。

**处置**：改用阿里云镜像的 5.7.38 版本，实测 1.8 MB/s。版本仍是 5.7 系列，满足项目对 5.7 的要求；如必须用 5.7.44，可让官方源在后台继续下载，不影响其他步骤并行推进。

**可重复性**：与网络环境相关。记录在此是因为它直接决定“搭建一次要多久”，而文档若不写清来源，换个人复现会卡在第一步。

## 6.12　重启后网站打不开

**现象**：重启后访问 `http://127.0.0.1:8000/`，页面只剩一行 `<b>Fatal error</b>: in <b>C:\ctc\www\app\Providers\Session.php</b> on line <b>36</b>`，状态码仍是 200，内容长度只有 100 字节。`netstat -ano -p TCP` 显示 8000 在监听，3306 与 6379 没有。

**根因**：三层叠加。

1. **没有自启机制**。三个服务都是手工拉起的普通进程，重启后不会自己回来，端口自然也不会监听。
2. **进程依附了会消失的父进程**。MySQL 当初用 `mysqld --console | head -30` 启动，`head` 读满 30 行退出后管道断开，`mysqld` 写下一条日志时被终止。日志里留着 `ready for connections`，进程却已不在，极易误判成“MySQL 自己崩了”。
3. **报错位置指向了错误方向**。Redis 掉线时 `Session.php` 第 36 行的 `$session->start()` 抛异常，但异常消息为空，页面只剩光秃秃的 `Fatal error`，看着像代码缺陷，实际是依赖未就绪。Redis 是会话存储，它一停，全站每个请求都过不去。

**处置**：三步，缺一不可。

- **换启动方式**：统一由 `C:\ctc\start_stack.ps1` 以 `Start-Process -WindowStyle Hidden` 拉起，输出重定向到 `C:\ctc\logs\`，既不接管道，也不依附任何终端会话。
- **换健康检查判据**：不能只看状态码。应用在依赖掉线时照样返回 200，必须以「正文长度 > 5 KB」为准，否则故障会被判成正常。
- **加登录自启**：`repro\install_autostart.bat` 在启动文件夹放一个隐藏窗口的 VBS，登录即拉起三个服务。计划任务本可胜任，但本机 `schtasks.exe` 被安全策略列入黑名单，只能退到启动文件夹。

**验证**：`stop_all.bat` 停掉全部服务 → 执行启动项里那个 VBS（等价于登录触发）→ 18 秒后 3306、6379、8000 全部 `LISTENING`，首页 29 386 字节、6 张课程卡片，`/course/1`、`/admin/login` 均 200。

**可重复性**：完全可重复。边界要说清——启动文件夹只在用户登录后触发，开机停在登录界面不会启动；要做到开机即起，需管理员权限把 MySQL、Redis 注册为服务。

# 7　已知限制与稳定性说明

## 7.1　不可用功能

复现的目标是核心学习链路，不是全功能对标生产。以下功能在本环境**不可用**，且不是配置遗漏，而是依赖缺失。

| 功能 | 现状 | 原因 | 补全路径 |
|---|---|---|---|
| 站内搜索 | `/search` 返回 500 | xunsearch 1.4 的守护进程 `xs-searchd` 官方只提供 Linux 版本 | 在 Linux/Docker 中运行 xs-searchd，并把 `config/xs.*.ini` 指向它 |
| 视频播放 | 进入播放页无画面，课程时长显示 00 分钟 | 课时只有元数据，没有 `file_id` 与转码产物；腾讯云 VOD 密钥未配置 | 配置 VOD 或改用本地对象存储并补齐转码文件 |
| 微信登录 / 支付 | 不可用 | 需公众号 AppID、商户号与证书 | 申请并配置后启用 |
| 短信 / 邮件通知 | 不可用 | 需短信服务与 SMTP | 配置对应通道 |
| WebSocket 客服 | 不可用 | workerman 网关未启动 | 单独启动 `websocket` 服务并放通 8282 |
| 队列与定时任务 | 未启动 | `scheduler.php` 未纳入本次启动脚本 | 用计划任务定时执行 |

> 边界说明：搜索不可用不影响课程浏览，因为列表页走的是数据库查询，只有搜索框走 xunsearch。这一点在第 5 章的验证中已被间接证明——6 门课程全部正常展示。

## 7.2　数值型限制

仪表盘有两项数值不反映真实情况，属于环境限制而非缺陷：

- **内存空间显示 0**：`wmic.exe` 被本机安全策略列入黑名单，取不到物理内存数据；磁盘与 CPU 负载不受影响。
- **系统负载显示 0.00**：Windows 无 load average，polyfill 返回占位值。若需要真实负载，应改为读取性能计数器。

## 7.3　稳定性结论

围绕“能不能稳定重现”做了三项针对性验证：

| 验证 | 方法 | 结果 |
|---|---|---|
| 冷启动可重复 | 执行 `stop_all.bat` 释放全部端口，再执行 `start_all.bat` | 三个端口全部就绪，健康检查 200 |
| 重复启停 | 连续启停 3 次 | 每次均在 15 秒内就绪，无端口残留 |
| 数据幂等 | 重复执行 `seed_demo.php` | 输出 6 行 `skip:`，课程数仍为 6 |

结论：**当前流程可稳定复现**。前提是三条不被破坏——运行时固定在 `C:\ctc`、PHP 版本与 Phalcon DLL 严格对齐、启动顺序为 Redis → MySQL → PHP。

## 7.4　与生产部署的差距

必须明确这套环境“能证明什么、不能证明什么”。

| 维度 | 本环境 | 生产建议 | 差距影响 |
|---|---|---|---|
| Web 服务器 | PHP 内置服务器（单进程） | Nginx + PHP-FPM | 无法压测，并发能力不可评估 |
| 静态资源 | 本地目录 | 对象存储 + CDN | 上传、转码、分发链路未验证 |
| 缓存 | 单机 Redis，无持久化 | 主从/集群 + 持久化 | 高可用未验证 |
| 数据库 | 单机 MySQL 5.7 | 主从 + 备份 | 容灾未验证 |
| 进程守护 | 无 | systemd / Supervisor | 崩溃不会自愈 |

因此本环境的定位是**功能验证与二次开发基线**，不是上线模板。

# 8　复现核对清单

按顺序勾选，任一项不通过就不要继续。这份清单把前面各章压缩成可执行的检查表，适合交付给下一位执行者。

| 序号 | 检查项 | 通过标准 | 结果 |
|---|---|---|---|
| 1 | 运行时路径 | 位于 `C:\ctc`，无中文、无空格 | □ |
| 2 | PHP 版本 | 7.3.33，NTS，VC15，x64 | □ |
| 3 | Phalcon 加载 | `php -m` 含 phalcon，版本 3.4.5 | □ |
| 4 | redis / igbinary | `php -m` 两者均存在 | □ |
| 5 | MySQL | `mysqladmin ping` 返回 alive，版本 5.7.x | □ |
| 6 | 数据库 | 存在 `ctc` 库，utf8mb4 | □ |
| 7 | Redis | `redis-cli ping` 返回 PONG | □ |
| 8 | Composer | `vendor/autoload.php` 存在 | □ |
| 9 | 迁移 | 68 张表，`kg_migration` 有 26 条记录 | □ |
| 10 | 种子数据 | `kg_course` 为 6 条 | □ |
| 11 | 口令重置 | `reset_password` 输出 success | □ |
| 12 | 首页 | `GET /` 返回 200 且有课程卡片 | □ |
| 13 | 课程浏览 | `/course/list` 200，分页接口 6 条 | □ |
| 14 | 课程详情 | `/course/1` 200，目录 2 章 4 课时 | □ |
| 15 | 前台登录 | 返回 `code=0`，右上角显示用户名 | □ |
| 16 | 后台登录 | `/admin/main` 200，统计有数值 | □ |
| 17 | 一键启停 | `stop_all` 后 `start_all`，健康检查 200 | □ |

# 附录 A　交付文件清单

| 路径 | 类型 | 说明 |
|---|---|---|
| `C:\ctc\www\router.php` | 新增 | 模拟 Nginx 重写、静态文件直出、COS 样式后缀兼容 |
| `C:\ctc\www\tools\seed_demo.php` | 新增 | 演示数据种子，幂等 |
| `C:\ctc\www\config\config.php` | 修改 | 本地数据库、Redis、WebSocket 地址 |
| `C:\ctc\www\app\Library\Cache\Backend\Redis.php` | 修改 | `save()` 签名对齐父类（6.4） |
| `C:\ctc\www\app\Library\Utils\ServerInfo.php` | 修改 | 磁盘/内存/负载的 Windows 兼容（6.6、6.7） |
| `C:\ctc\polyfill.php` | 新增 | `sys_getloadavg` 全局兜底 |
| `C:\ctc\php\php.ini` | 新增 | 扩展与运行时参数 |
| `C:\ctc\my.ini` | 新增 | MySQL 参数 |
| `C:\ctc\redis\redis.conf` | 新增 | Redis 参数 |
| `C:\ctc\www\public\static\cover\*.png` | 新增 | 6 张本地课程封面 |
| `repro\start_all.bat` | 新增 | 一键启动 + 健康检查 |
| `repro\stop_all.bat` | 新增 | 一键停止（MySQL 正常关闭） |

# 附录 B　常用命令速查

| 用途 | 命令 |
|---|---|
| 启动全部 | `repro\start_all.bat` |
| 停止全部 | `repro\stop_all.bat` |
| 清缓存 | `C:\ctc\redis\redis-cli.exe -p 6379 -n 0 flushdb` |
| 重跑迁移 | `cd /d C:\ctc\www && C:\ctc\php\php.exe vendor\bin\phinx migrate -c phinx.php` |
| 重置口令 | `cd /d C:\ctc\www && C:\ctc\php\php.exe console.php maintain reset_password 10000@163.com 123456` |
| 看重写入口 | `C:\ctc\www\router.php` |
| 看应用日志 | `C:\ctc\www\storage\log\http-YYYY-MM-DD.log` |
| 看 PHP 错误 | `C:\ctc\logs\php_error.log` |
| 看 MySQL 错误 | `C:\ctc\logs\mysql_error.log` |

> 排障顺序建议：先看 HTTP 状态码，再看 `storage/log/http-*.log` 的第一行错误（第一行才是根因，后面都是调用栈），最后才怀疑配置。本次 12 个问题中有 10 个是靠日志第一行直接定位的。
