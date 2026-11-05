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

# 5) 定时器：scheduler.php 已含 exam_sync，重启调度进程生效
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
