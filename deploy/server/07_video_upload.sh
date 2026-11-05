#!/bin/bash
# 部署演示视频上传模块
# 前置：/root/ctc_deploy/video-upload/ 下已放好源码

set -e

APP=/www/ctc
MEDIA=/www/media
SRC=/root/ctc_deploy/video-upload

echo "=== 1. 媒体目录 ==="
mkdir -p $MEDIA/vod $MEDIA/tmp
chown -R apache:apache $MEDIA
chmod 775 $MEDIA $MEDIA/vod $MEDIA/tmp
ls -ld $MEDIA/vod $MEDIA/tmp

echo "=== 2. 部署代码 ==="
mkdir -p $APP/app/Http/Admin/Views/video_upload

cp -f $SRC/app/Http/Admin/Services/VideoUpload.php           $APP/app/Http/Admin/Services/
cp -f $SRC/app/Http/Admin/Controllers/VideoUploadController.php $APP/app/Http/Admin/Controllers/
cp -f $SRC/app/Http/Admin/Views/video_upload/index.volt     $APP/app/Http/Admin/Views/video_upload/
cp -f $SRC/app/Http/Admin/Views/video_upload/list.volt      $APP/app/Http/Admin/Views/video_upload/

chown apache:apache $APP/app/Http/Admin/Services/VideoUpload.php \
                    $APP/app/Http/Admin/Controllers/VideoUploadController.php
chmod 644 $APP/app/Http/Admin/Services/VideoUpload.php \
          $APP/app/Http/Admin/Controllers/VideoUploadController.php
chown -R apache:apache $APP/app/Http/Admin/Views/video_upload
chmod 644 $APP/app/Http/Admin/Views/video_upload/*.volt

echo "--- 语法检查 ---"
php -l $APP/app/Http/Admin/Services/VideoUpload.php
php -l $APP/app/Http/Admin/Controllers/VideoUploadController.php

echo "=== 3. 菜单节点 ==="
python3 $SRC/patch_authnode.py
php -l $APP/app/Http/Admin/Services/AuthNode.php
chown apache:apache $APP/app/Http/Admin/Services/AuthNode.php

echo "=== 4. nginx 配置 ==="
# 8080 已于 2026-11-05 停用（只保留 443），不再复制 ctc.conf
# 如需恢复 HTTP 入口：cp $SRC/ctc.conf /etc/nginx/conf.d/ctc.conf
if [ -f /etc/nginx/conf.d/ctc-ssl.conf ]; then
    echo "    使用已有 /etc/nginx/conf.d/ctc-ssl.conf"
else
    cp -f $SRC/ctc-ssl.conf /etc/nginx/conf.d/ctc-ssl.conf
fi
nginx -t

echo "=== 5. 清理缓存 ==="
rm -rf $APP/storage/cache/volt/*
rm -rf $APP/storage/cache/annotations/*

# 注解缓存在 Redis（env=pro），新增控制器后必须清理。
# 否则首次解析失败的结果会被缓存 7 天，改代码也不会生效。
echo "--- 清理 Redis 注解缓存 ---"
redis-cli -n 3 keys '_PHCR_ANNOTATION_*' | while IFS= read -r k; do
    redis-cli -n 3 del "$k" > /dev/null
done
echo "剩余: $(redis-cli -n 3 keys '_PHCR_ANNOTATION_*' | wc -l)"

echo "=== 6. 重载服务 ==="
systemctl reload nginx
systemctl restart php-fpm
sleep 3

echo "=== 7. 冒烟 ==="
for u in /admin/video_upload/ /admin/video_upload/list; do
    printf '%-32s ' "$u"
    curl -sk -o /tmp/vu.html -w '%{http_code} %{size_download}B' --max-time 90 \
        -u "admin:${ADMIN_PASS:?请先导出 ADMIN_PASS}" "https://127.0.0.1$u"
    echo -n '  '
    grep -o '<title>[^<]*</title>' /tmp/vu.html | head -1
done

printf '%-32s ' "/media/vod/(目录探测)"
curl -sk -o /dev/null -w '%{http_code}\n' --max-time 15 https://127.0.0.1/media/vod/

echo "=== 完成 ==="
