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
cp -f $SRC/ctc.conf /etc/nginx/conf.d/ctc.conf
nginx -t

echo "=== 5. 清理模板缓存 ==="
rm -rf $APP/storage/cache/volt/*

echo "=== 6. 重载服务 ==="
systemctl reload nginx
systemctl restart php-fpm
sleep 3

echo "=== 7. 冒烟 ==="
for u in /admin/video_upload/ /admin/video_upload/list; do
    printf '%-32s ' "$u"
    curl -s -o /tmp/vu.html -w '%{http_code} %{size_download}B' --max-time 90 "http://127.0.0.1:8080$u"
    echo -n '  '
    grep -o '<title>[^<]*</title>' /tmp/vu.html | head -1
done

printf '%-32s ' "/media/vod/(目录探测)"
curl -s -o /dev/null -w '%{http_code}\n' --max-time 15 http://127.0.0.1:8080/media/vod/

echo "=== 完成 ==="
