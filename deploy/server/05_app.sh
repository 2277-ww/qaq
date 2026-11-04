#!/bin/bash
# 阶段四：应用配置 + php-fpm + nginx(8080)
set -e

APP=/www/ctc

echo "===== [1/6] 生成 config.php ====="
cd $APP/config
cp -f config.example.php config.php
sed -i "s|PUT-YOUR-APP-KEY-HERE|${CTC_APP_KEY:?请先设置 CTC_APP_KEY 环境变量}|" config.php
sed -i "s|PUT-YOUR-DB-PASSWORD|${CTC_DB_PASSWORD:?请先设置 CTC_DB_PASSWORD 环境变量}|" config.php
# redis 用 3 号库，避开其他程序
sed -i "s|\$config\['redis'\]\['index'\] = 0;|\$config['redis']['index'] = 3;|" config.php
grep -nE "env'\]|key'\]|db'\]\['(host|dbname|username|password)'\]|redis'\]\['index'\]" config.php

echo "===== [2/6] PHP 参数调优 ====="
cat > /etc/php.d/99-ctc.ini <<'EOF'
memory_limit = 256M
upload_max_filesize = 50M
post_max_size = 50M
max_execution_time = 120
max_input_time = 120
date.timezone = Asia/Shanghai
expose_php = Off
opcache.enable = 1
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 10000
opcache.validate_timestamps = 1
opcache.revalidate_freq = 2
EOF
php -r 'echo "memory_limit=", ini_get("memory_limit"), " tz=", ini_get("date.timezone"), "\n";'

echo "===== [3/6] 目录权限 ====="
mkdir -p $APP/storage/cache/{annotations,metadata,purifier,volt} $APP/storage/log $APP/storage/tmp
chown -R apache:apache $APP/storage
chmod -R 775 $APP/storage
chown -R root:root $APP
chmod 755 $APP
ls -ld $APP $APP/storage $APP/public

echo "===== [4/6] php-fpm 池调优 ====="
sed -i 's/^pm = dynamic/pm = ondemand/' /etc/php-fpm.d/www.conf
sed -i 's/^pm.max_children = .*/pm.max_children = 10/' /etc/php-fpm.d/www.conf
sed -i 's/^pm.start_servers = .*/pm.start_servers = 3/' /etc/php-fpm.d/www.conf
sed -i 's/^pm.min_spare_servers = .*/pm.min_spare_servers = 2/' /etc/php-fpm.d/www.conf
sed -i 's/^pm.max_spare_servers = .*/pm.max_spare_servers = 5/' /etc/php-fpm.d/www.conf
grep -E '^pm' /etc/php-fpm.d/www.conf | head -4
systemctl enable php-fpm >/dev/null 2>&1 || true
systemctl restart php-fpm
sleep 3
echo -n "php-fpm: "; systemctl is-active php-fpm
ls -l /run/php-fpm/www.sock 2>/dev/null

echo "===== [5/6] nginx 站点（8080）====="
cat > /etc/nginx/conf.d/ctc.conf <<'EOF'
server {
    listen 8080;
    listen [::]:8080;
    server_name _;

    root /www/ctc/public;
    index index.php index.html;

    client_max_body_size 50m;
    access_log /var/log/nginx/ctc.access.log;
    error_log  /var/log/nginx/ctc.error.log;

    # 伪静态：全部交给入口文件
    location / {
        try_files $uri $uri/ /index.php?_url=$uri&$args;
    }

    location ~ \.php$ {
        fastcgi_pass   unix:/run/php-fpm/www.sock;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param  PATH_INFO       $fastcgi_path_info;
        include        fastcgi_params;
        fastcgi_read_timeout 300;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }

    # 静态资源缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff2?|ttf|eot)$ {
        expires 7d;
        access_log off;
        try_files $uri =404;
    }

    # 保护敏感文件
    location ~* /(config|db|storage|vendor)/ {
        deny all;
    }
    location ~* \.(sql|ini|log|md|lock|json)$ {
        deny all;
    }
    location ~ /\.(?!well-known) {
        deny all;
    }
}
EOF
nginx -t
systemctl reload nginx
echo -n "nginx: "; systemctl is-active nginx

echo "===== [6/6] 本机连通性 ====="
curl -s -o /dev/null -w "首页 %{http_code} %{size_download}B %{time_total}s\n" http://127.0.0.1:8080/
curl -s http://127.0.0.1:8080/ | grep -o '<title>[^<]*</title>' | head -1
echo "STAGE4_OK"
