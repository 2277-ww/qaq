# 演示视频上传与免费 HTTPS 部署说明

> 部署对象：`8.138.34.151`（阿里云 Alinux 3，2C / 1.87G / 40G）
> 应用：`/www/ctc`（PHP 7.3.33 + Phalcon 3.4.5 + MariaDB 10.5 + Redis 6.2）
> 完成时间：2026-11-04

---

## 1　功能定位

原项目的视频走「腾讯云点播 + COS 转码」链路，本地改造版没有云账号，`public/static/vod` 一旦随代码包剔除，所有课时就变成 404。本次实现的是一个**独立的本地存储上传模块**，不依赖任何云服务：

- 后台独立入口，分片上传，带进度与断点重试
- 文件落在 **web 根目录之外**，升级代码不会丢视频
- 上传后可直接绑定到课程章节，播放器立即生效
- 同时把历史 28 个演示视频（1.3 GB）导入并修正了写死在数据库里的开发机地址

---

## 2　视频存储

### 2.1 位置

| 项 | 值 |
|---|---|
| 物理目录 | `/www/media/vod/` |
| 临时分片目录 | `/www/media/tmp/` |
| URL 前缀 | `/media/vod/` |
| 对外地址 | `https://8.138.34.151/media/vod/...` |
| 访问方式 | nginx `location ^~ /media/vod/ { alias /www/media/vod/; }` |
| 目录属主 | `apache:apache`，775 |

选择 web 根之外的原因：代码目录 `/www/ctc` 会被重新部署覆盖，媒体目录独立后可以单独备份、单独扩容、单独迁到对象存储，互不影响。

### 2.2 目录结构

新上传的文件按课程与月份归档：

```
/www/media/vod/
├── 1/202611/<32位upload_id>.mp4        # 课程 1，2026 年 11 月上传
├── 2/202611/<32位upload_id>.mp4
└── frontend/semantic-html.mp4          # 历史视频，保留原始 slug 层级
```

历史视频保持 `<slug>/<文件名>` 结构，是因为数据库里原本记录的就是 `/static/vod/frontend/semantic-html.mp4`，只需换前缀，不必重命名文件。

### 2.3 大小与容量

| 项 | 值 | 说明 |
|---|---|---|
| 单文件上限 | **500 MB** | 服务端硬校验，超限直接拒绝 |
| 分片大小 | 8 MB | 前端切片，末片可小于 8 MB |
| 单片请求上限 | 8 MB | 远低于 nginx 50m 与 PHP 50M，无需放宽 |
| 当前占用 | 1.3 GB / 28 个文件 | 磁盘 40 G，已用 12 G，剩余 27 G |
| 临时空间 | 上传会话 24 小时后自动清理 | 只在合并前占用 |

### 2.4 格式限制

| 层 | 规则 |
|---|---|
| 扩展名白名单 | `mp4` / `webm` / `m4v`，其余一律拒绝 |
| 容器魔数 | MP4 家族校验第 5–8 字节是否为 `ftyp`；WebM 校验前 4 字节是否为 `1A 45 DF A3` |
| 大小一致性 | 合并后字节数必须与申报值完全相等，否则丢弃 |
| 编码探测 | `ffprobe` 读真实轨道：H.264(+AAC/MP3) 或 WebM(VP8/VP9/AV1) 直通，其余自动转码 |
| 不信任的字段 | 上传时的 `Content-Type` 与文件名后缀都不作为判据 |

魔数校验是必需的：只改扩展名的文本文件能骗过前端，但过不了 `finish` 这一步。实测把 200 KB 随机数据命名为 `.mp4` 上传，返回「文件内容不是有效的 MP4 / WebM 视频」。

编码探测在本轮补上：`ffprobe` 走的是真实轨道信息，不是容器后缀。H.264 + AAC 直接落盘；HEVC / ProRes / AC-3 等浏览器不认的组合会在后台用 ffmpeg 转成 H.264 + AAC（详见 6.5）。需要转码且源时长超过 45 分钟的会被拒绝，提示先在本地转码——避免 2 核机器被一个两小时的文件占死。

---

## 3　上传入口与流程

### 3.1 入口

| 入口 | 地址 |
|---|---|
| 上传页 | `https://8.138.34.151/admin/video_upload/` |
| 媒体库 | `https://8.138.34.151/admin/video_upload/list` |
| 后台菜单 | 管理后台 → 视频上传 → 上传演示视频 / 媒体库 |

后台入口已加 nginx basic auth（2026-11-05）：

| 项 | 值 |
|---|---|
| 用户名 | `admin` |
| 密码 | 见 `docs/运维加固与备份说明.md`，或执行 `bash /root/10_harden.sh --reset-pass` 重置 |

原因：改造版的 `App\Services\Auth\Admin` 是「内置身份模式」，不读会话、恒返回内置账号，公网上任何人打开 `/admin/` 都能上传和删除。basic auth 在 nginx 层兜住，不动业务代码。

### 3.2 操作流程

1. 选择**所属课程**（决定文件归档到哪个课程目录）
2. 点击或拖入视频文件，前端立刻校验扩展名与 500 MB 上限，不合规当场提示
3. 点「开始上传」，进度条显示当前片序号、已传字节、实时速度
4. 全部分片送达后自动进入合并，服务端校验大小与魔数
5. 成功后显示播放地址，可选择章节并「绑定到章节」，该课时播放器立即切换到新视频

### 3.3 接口协议

| 接口 | 方法 | 参数 | 作用 |
|---|---|---|---|
| `/admin/video_upload/init` | POST | `course_id` `filename` `size` | 建会话，返回 `upload_id` `chunk_size` `total_chunks` |
| `/admin/video_upload/chunk` | POST | `upload_id` `index` `chunk`(文件) | 收单片，落为 `{index}.part` |
| `/admin/video_upload/finish` | POST | `upload_id` | 校验完整性 → 合并 → 魔数校验 → 归档 → 返回 URL |
| `/admin/video_upload/attach` | POST | `course_id` `chapter_id` `url` | 写入 `kg_chapter_vod.file_remote` |
| `/admin/video_upload/chapters` | GET | `course_id` | 章节下拉数据 |
| `/admin/video_upload/delete` | POST | `url` | 删除媒体文件 |

所有 POST 都要求 `X-Csrf-Token` 头（后台 `common.js` 已全局注入）且 Referer 与 Host 一致，沿用项目原有安全中间件，没有为上传开后门。

### 3.4 为什么要分片

单请求传 500 MB 会撞上 `post_max_size`、`fastcgi_read_timeout` 和浏览器内存三重限制。分片后每片 8 MB，单请求耗时 1 秒左右，网络抖动只需重传 1 片；会话文件保留 24 小时，页面上也留了「取消」按钮，中断不会留下垃圾。

---

## 4　数据库写入

上传完成后的播放地址写入 `kg_chapter_vod.file_remote`，格式与原项目一致，播放器代码无需改动：

```json
{
  "hd": {"url": "/media/vod/1/202611/xxx.mp4"},
  "sd": {"url": "/media/vod/1/202611/xxx.mp4"},
  "fd": {"url": "/media/vod/1/202611/xxx.mp4"}
}
```

用相对路径而不是绝对 URL，好处是换域名、加 HTTPS、迁移主机时数据库不用动——浏览器会按当前页面的协议与主机自动补全。

历史数据修复：把 28 条记录里的 `http://127.0.0.1:8000/static/vod/` 统一替换为 `/media/vod/`，替换后 80 个播放地址（hd/sd/fd 各一份）全部校验过对应文件存在。

```sql
UPDATE kg_chapter_vod
SET file_remote = REPLACE(file_remote, 'http://127.0.0.1:8000/static/vod/', '/media/vod/')
WHERE file_remote LIKE '%127.0.0.1:8000/static/vod/%';
```

---

## 5　免费 HTTPS

### 5.1 证书类型

没有域名，用的是 Let's Encrypt 在 **2026-01-15 全面开放的 IP 地址证书**：

| 项 | 值 |
|---|---|
| 颁发者 | Let's Encrypt（链：YE2 → Root YE → ISRG Root X2 → X1） |
| 标识 | `IP Address:8.138.34.151`（写在 SAN 里，不是 CN） |
| 有效期 | **160 小时（约 6 天）**，短周期是 IP 证书的强制要求 |
| ACME profile | `shortlived`（IP 证书必须选它） |
| 验证方式 | http-01（DNS-01 不可用，IP 没有 TXT 记录可放） |
| 部署位置 | `/etc/nginx/ssl/8.138.34.151.crt` / `.key` |
| 客户端 | acme.sh v3.1.7 |

客户端为什么不是 certbot：这台机器 `python3` 是 3.6.8，而 certbot 5.x 要求 Python ≥ 3.9，pip 也只有 9.0.3，dnf 里的 certbot 是 1.22（不支持 `--ip-address`）。acme.sh 是纯 shell，无依赖，直接可用。

### 5.2 申请过程

```bash
# 1. 安装（raw.githubusercontent.com 不通，走 GitHub 归档）
cd /opt && curl -sL https://github.com/acmesh-official/acme.sh/archive/refs/heads/master.tar.gz -o acme.tar.gz
tar xzf acme.tar.gz && cd acme.sh-master && ./acme.sh --install -m 2074467091@qq.com

# 2. 准备 webroot 验证目录
mkdir -p /var/www/acme/.well-known/acme-challenge && chmod -R 755 /var/www/acme

# 3. 80 端口放行验证路径（nginx 里加精确匹配，Halo 不受影响）
#    location ^~ /.well-known/acme-challenge/ { root /var/www/acme; default_type text/plain; }

# 4. 先 staging 试签，避免浪费生产配额
/root/.acme.sh/acme.sh --issue -d 8.138.34.151 -w /var/www/acme \
  --server letsencrypt_test --cert-profile shortlived --days 3 \
  --force --accountemail 2074467091@qq.com

# 5. 正式签发
/root/.acme.sh/acme.sh --issue -d 8.138.34.151 -w /var/www/acme \
  --server letsencrypt --cert-profile shortlived --days 3 \
  --force --accountemail 2074467091@qq.com

# 6. 安装到 nginx 并绑定重载命令
/root/.acme.sh/acme.sh --install-cert -d 8.138.34.151 --ecc \
  --key-file /etc/nginx/ssl/8.138.34.151.key \
  --fullchain-file /etc/nginx/ssl/8.138.34.151.crt \
  --reloadcmd "systemctl reload nginx"
```

两个坑：

- **邮箱不能用 `.local` 域名**。首次用 `admin@selflearn.local` 注册被 ACME 拒绝：`contact email has invalid domain`。必须用有效 TLD 的邮箱。
- **`pkill -f acme.sh` 会杀掉执行它的那个 shell**，因为命令行本身含 `acme.sh`，匹配上了自己。要停进程就得写更精确的 pattern。

### 5.3 自动续期

acme.sh 安装时已写入 crontab：

```
0 3,9,15,21 * * * /root/.acme.sh/acme.sh --cron --home /root/.acme.sh > /dev/null
```

| 项 | 值 |
|---|---|
| 检查频率 | 每天 4 次（03/09/15/21 点） |
| 续期阈值 | `Le_RenewalDays=3`，即到期前 3 天开始续 |
| 下次续期时间 | 2026-11-06 11:14 UTC（证书 11-11 到期） |
| 续期后动作 | `install-cert` 记录的 `reloadcmd` 自动执行，nginx 平滑重载 |
| ARI 支持 | 有，LE 建议窗口为 11-07 17:07–20:18 UTC，acme.sh 会在窗口内执行 |

**为什么每天 4 次**：证书只有 6 天寿命，如果一天只查一次且恰好那天网络故障，余量会很紧张。4 次意味着单次失败还有十几次机会。

**实测过续期链路**（不是只看配置）：手动强制续期一次，日志显示新证书 notBefore 从 `10:15:51` 变为 `10:21:21`，随后自动写入 `/etc/nginx/ssl/` 并执行 `Reload successful`，站点持续 200。

### 5.4 443 站点

`/etc/nginx/conf.d/ctc-ssl.conf`：

| 端口 | 内容 | 状态 |
|---|---|---|
| 80 | Halo 博客「警院成果展示广场」 | 未改动，仅增加 ACME 验证路径 |
| 443 | 课程平台（HTTPS） | 唯一入口 |
| 8080 | 课程平台（HTTP 备用） | **2026-11-05 已停用**，配置移到 `/root/nginx-backup/ctc-8080.conf.disabled.*` |

8080 停用后，所有自检脚本改走 `https://127.0.0.1`（`curl -sk`）。要恢复见 `docs/运维加固与备份说明.md` 第 3 节。

TLS 配置：`TLSv1.2` + `TLSv1.3`，ECDHE 套件，会话缓存 10m。

**没有开 HSTS**。6 天证书一旦续期失败，HSTS 会让浏览器在一段时间内强制走 HTTPS 且无法点击绕过，等于把可用性绑在续期成功率上。IP 场景不值得。

---

## 6　验证步骤

### 6.1 证书层

```bash
# 有效期与 SAN
openssl x509 -in /etc/nginx/ssl/8.138.34.151.crt -noout -dates -text | grep -A1 'Alternative Name'
# 期望：IP Address:8.138.34.151

# 链验证（用系统 CA，模拟客户端）
echo | openssl s_client -connect 127.0.0.1:443 \
  -CAfile /etc/pki/tls/certs/ca-bundle.crt -verify_ip 8.138.34.151 2>/dev/null \
  | grep 'Verify return code'
# 期望：Verify return code: 0 (ok)
```

实测结果：链验证 `0 (ok)`，IP 匹配 `0 (ok)`，协商 `TLSv1.3 / TLS_AES_256_GCM_SHA384`。

### 6.2 站点层

```bash
for u in / /course/list /chapter/2 /admin/video_upload/; do
  curl -s -o /dev/null -w "$u -> %{http_code}\n" https://8.138.34.151$u
done
```

实测全部 200，标题分别为「自学平台」「课程 - 自学平台」「章节 - 页面骨架与语义化标签…」「自学平台 - 管理后台」。

**关键判据：curl 不加 `-k` 也返回 200**，说明证书被系统信任且 IP 匹配，不是自签绕过。

### 6.3 视频层

```bash
# Range 请求（进度条拖动依赖它）
curl -s -o /dev/null -D - -r 0-2047 https://8.138.34.151/media/vod/frontend/semantic-html.mp4
```

实测返回 `206`，`Content-Range: bytes 0-2047/95266932`，`Content-Type: video/mp4`。

章节页 `/chapter/2` 的 `chapter.play_urls` 值为 `/media/vod/frontend/semantic-html.mp4`，页面内已无 `127.0.0.1` 开发地址。

### 6.4 上传层

```bash
# 拒绝：非法扩展名
-f 'filename=a.txt'         -> 仅支持 mp4 / webm / m4v 格式
# 拒绝：超限
-f 'size=600000000'         -> 文件 572.2 MB 超过 500 MB 上限
# 拒绝：课程不存在
-F 'course_id=99999'        -> 课程不存在或已删除
# 拒绝：伪造视频
200KB 随机数据改名 .mp4      -> 文件内容不是有效的 MP4 / WebM 视频（已校验容器魔数）
# 通过：真实视频 5.7 MB / 1 片  -> 200，URL /media/vod/1/202611/xxx.mp4，大小一致
# 通过：真实视频 12.5 MB / 2 片 -> 200，13134847 字节完全一致
```

### 6.5 转码与防盗链（补充实施）

上传合并后会做两件事：先用 `ffprobe` 读真实编码，再决定直通还是转码。脚本 `deploy/server/video-upload/test_transcode.sh` 覆盖了三种结果：

| 场景 | 期望 | 实测 |
|---|---|---|
| HEVC/H.265（`libx265` 生成 6 秒样片） | 识别为需转码，后台转成 H.264 | `finish` 首轮返回 `state=transcoding`，3 秒后轮询到 `state=done`，`video_codec=h264`，URL 200，506507 字节 |
| H.264 + AAC | 直通，不占 CPU | 首轮即 `state=done`，`transcoded=false`，无等待 |
| MPEG-4 part2 且时长 46 分 | 超过 45 分上限，拒绝 | `视频编码为 MPEG4，需要转码，但时长 46 分 0 秒 超过自动转码上限 45 分 0 秒`，临时目录随即清空 |

防盗链实测（`valid_referers none blocked server_names 8.138.34.151`）：

```bash
U=/media/vod/frontend/semantic-html.mp4
curl -s -o /dev/null -w '%{http_code}\n' -H 'Referer: https://8.138.34.151/' https://8.138.34.151$U   # 200
curl -s -o /dev/null -w '%{http_code}\n' -H 'Referer: https://evil.example/' https://8.138.34.151$U   # 403
curl -s -o /dev/null -w '%{http_code}\n' https://8.138.34.151$U                                       # 200（空 Referer 放行）
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' -H 'Range: bytes=0-1023' \
     -H 'Referer: https://8.138.34.151/chapter/2' https://8.138.34.151$U                              # 206 1024
```

443 站点加了这段规则（8080 停用前两个站点都有）。空 Referer 放行的原因是：部分播放器、下载工具、微信内置浏览器不带 Referer，全拦会把正常播放也挡掉；拦的是「别的网站嵌你的视频」。

证书看门狗状态端点：

```bash
curl -s https://8.138.34.151/_status/cert.txt
# state=ok / days_left=7 / not_after=Nov 11 02:21:20 2026 GMT / last_renew=skipped / checked_at=...
```

---

## 7　运维手册

### 7.1 常用命令

```bash
# 证书状态
/root/.acme.sh/acme.sh --list

# 手动续期（不强制，未到期会跳过）
/root/.acme.sh/acme.sh --renew -d 8.138.34.151 --ecc

# 强制续期（演练用，会消耗一张配额）
/root/.acme.sh/acme.sh --renew -d 8.138.34.151 --ecc --force

# 模拟定时任务
/root/.acme.sh/acme.sh --cron

# 证书看门狗（含剩余天数检查、必要时自动续期、告警）
/usr/local/bin/ctc-cert-watch.sh; echo "exit=$?"     # 0 正常 / 2 已告警
RENEW_AT=10 /usr/local/bin/ctc-cert-watch.sh         # 演练：把续期阈值临时调到 10 天

# 告警通道配置（企业微信 / 钉钉 / Slack webhook）
vi /etc/ctc/alert.conf

# 媒体目录
du -sh /www/media/vod
find /www/media/vod -type f | wc -l

# 清理未完成的上传会话
rm -rf /www/media/tmp/*

# 服务重载
nginx -t && systemctl reload nginx
systemctl restart php-fpm
```

### 7.2 新增控制器后必须清注解缓存

这是本次踩得最久的一个坑，写在这里避免重复：

生产环境（`env=pro`）下 Phalcon 的注解读取器用的是 **Redis 适配器**，不是文件缓存。缓存键前缀实际为 `_PHCR_ANNOTATION_:`，有效期 7 天。如果新控制器的注解第一次没写对（例如 `@RoutePrefix` 放在了 namespace 之前的文件级注释里，Phalcon 不会把它当类注解），这个「解析不到前缀」的结果会被缓存 7 天——之后即便改对代码、清空 `storage/cache/annotations`、重启 php-fpm，路由依然是 404。

正确做法：

```bash
redis-cli -n 3 keys '_PHCR_ANNOTATION_*' | while IFS= read -r k; do
  redis-cli -n 3 del "$k" > /dev/null
done
```

注意别用 `xargs`：类名里带反斜杠，`xargs` 会把它当转义符，删不掉任何键。

### 7.3 续期失败怎么查

```bash
cat /var/www/acme-status/cert.txt             # 结构化状态：state / days_left / last_renew / hint
tail -20 /var/log/ctc/cert-watch.log          # 看门狗每次巡检与告警记录
tail -50 /root/ctc_deploy/acme_renew.log      # 最近一次续期日志
tail -20 /var/log/nginx/ctc-ssl.error.log     # 站点错误
```

续期失败最常见的原因是 80 端口验证路径不可达（安全组变动、Halo 配置被改）。把探针文件放回 `/var/www/acme/.well-known/acme-challenge/` 从外网访问一次即可确认。

另一类失败是**网络卡住**：本机到 `acme-v02.api.letsencrypt.org` 偶尔会出现单次请求挂数分钟的情况。因此看门狗调用续期时套了 `timeout 240`，acme.sh 自己的 crontab 也改成了 `timeout 600`，避免进程堆积把机器拖垮；超时会被记为 `last_renew=failed` 并触发告警。

### 7.4 转码任务排障

```bash
# 正在转码的任务（每个会话目录里都有 job.json / progress.txt / rc）
ls -lt /www/media/tmp | head
cat /www/media/tmp/<upload_id>/job.json
tail -20 /www/media/tmp/<upload_id>/run.log   # ffmpeg 原始输出，失败原因都在这

# 手工验证一个文件能不能播
ffprobe -v error -show_entries stream=codec_name,width,height -of csv=p=0 /www/media/vod/1/202611/x.mp4
```

`rc` 文件是收尾标记：`0` 表示转码成功且已 `mv` 到媒体目录，`1` 表示失败。`finish` 接口在 `job.json` 存在时兼作进度查询，前端每 3 秒轮询一次；页面关掉不影响后台转码，完成后文件照样出现在媒体库。

转码参数：`libx264 -preset veryfast -crf 23 -pix_fmt yuv420p`，长边超过 1920 时等比缩到 1920，音轨统一 `aac 128k 双声道`，`-movflags +faststart` 保证 moov 前置可边下边播。2 核机器上 720p 大致 2~3 倍速，500MB 以内一般在几分钟内完成。

---

## 8　已知限制

| 项 | 说明 | 影响 |
|---|---|---|
| 转码有上限 | 非 H.264 走后台转码，源时长 > 45 分直接拒绝 | 长课时需先在本地转 H.264 |
| 单机转码 | 2 核共用，转码时上传/页面会略慢 | 同时多个大文件转码会排队占 CPU |
| 证书 6 天 | IP 证书强制短周期 | 续期连续失败超过 6 天即全站证书失效（已有看门狗告警） |
| 单机存储 | 视频在本机磁盘 | 磁盘满则上传失败，无自动告警 |
| 防盗链非强制 | 只拦外站 Referer，空 Referer 放行 | 直接粘贴 URL 仍可下载，教学场景可接受 |
| 单区域 | 无 CDN | 跨地域访问速度取决于服务器带宽 |
| 无 HSTS | 有意不开 | 首次访问需手动输入 https:// |

转码与防盗链都已落地；剩下真正影响长期稳定的是**证书要域名**（IP 证书 6 天一轮，长期靠 acme.sh + 看门狗兜着）和**磁盘容量**（40G 盘目前用 12G，视频多了要扩）。

---

## 9　文件清单

| 文件 | 作用 |
|---|---|
| `deploy/server/video-upload/app/Http/Admin/Services/VideoUpload.php` | 上传业务逻辑（校验、分片、合并、归档、入库） |
| `deploy/server/video-upload/app/Http/Admin/Controllers/VideoUploadController.php` | 上传控制器，8 个路由 |
| `deploy/server/video-upload/app/Http/Admin/Views/video_upload/index.volt` | 上传页（拖拽、进度、绑定章节） |
| `deploy/server/video-upload/app/Http/Admin/Views/video_upload/list.volt` | 媒体库页 |
| `deploy/server/video-upload/patch_authnode.py` | 后台菜单节点注入（幂等） |
| `deploy/server/video-upload/ctc-8080.conf.disabled` | 原 8080 站点配置（已停用，保留备查） |
| `deploy/server/video-upload/ctc-ssl.conf` | 443 HTTPS 站点配置（含证书状态端点） |
| `deploy/server/07_video_upload.sh` | 一键部署脚本 |
| `deploy/server/08_transcode_and_watchdog.sh` | ffmpeg、看门狗、防盗链一键部署（幂等） |
| `deploy/server/cert/ctc-cert-watch.sh` | 证书看门狗：剩余天数检查 + 自动续期 + 告警 + 状态文件 |
| `deploy/server/cert/alert.conf.example` | 告警通道模板（企业微信 / 钉钉 / Slack webhook） |
| `deploy/server/acme_nginx_patch.py` | 80 端口 ACME 验证路径注入 |
| `deploy/server/fix_vod_url.sh` | 存量播放地址修复与文件校验 |
| `deploy/server/video-upload/test_upload.sh` | 分片上传端到端测试脚本 |
| `deploy/server/video-upload/test_transcode.sh` | 转码链路测试（HEVC 样片生成 → 上传 → 轮询 → 校验产物编码） |
| `build/import_vod.py` | 历史视频批量导入 |
