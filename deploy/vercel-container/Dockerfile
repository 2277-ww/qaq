# syntax=docker/dockerfile:1.6
# ---------------------------------------------------------------------------
# 自学平台（酷瓜云课堂 CTC 1.8.3 改造版）Vercel Container 运行时镜像
# 目标：把 PHP 7.3 + Phalcon 3.4 的完整运行环境封进一个 OCI 镜像，
#       Vercel 以容器函数的形式承载，无需在目标机器上安装任何 PHP 组件。
#
# 重要：Debian 10(buster) 已 EOL，官方源已下线，必须切到 archive 源，
#       否则 apt-get update 必然 404。
# ---------------------------------------------------------------------------

FROM php:7.3-fpm-buster AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    printf '%s\n' \
      'deb http://archive.debian.org/debian buster main' \
      'deb http://archive.debian.org/debian buster-updates main' \
      'deb http://archive.debian.org/debian-security buster/updates main' \
      > /etc/apt/sources.list; \
    printf 'Acquire::Check-Valid-Until "false";\nAcquire::Retries "3";\n' \
      > /etc/apt/apt.conf.d/99archive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      git unzip libpcre3-dev libzip-dev libpng-dev libjpeg62-turbo-dev \
      libfreetype6-dev g++ make autoconf pkg-config; \
    docker-php-ext-configure gd \
      --with-freetype-dir=/usr/include --with-jpeg-dir=/usr/include; \
    docker-php-ext-install -j"$(nproc)" pdo_mysql zip gd opcache; \
    pecl install igbinary-3.2.5 redis-5.3.7; \
    docker-php-ext-enable igbinary redis

# Phalcon 3.4.5 只能编译安装：它是 C 扩展，composer 无法安装，
# 且 3.4 系列只支持到 PHP 7.3（7.4 起必须换 Phalcon 4）。
ADD https://github.com/phalcon/cphalcon/archive/refs/tags/v3.4.5.tar.gz /tmp/phalcon.tgz
RUN set -eux; \
    mkdir -p /tmp/phalcon; \
    tar -xzf /tmp/phalcon.tgz -C /tmp/phalcon --strip-components=1; \
    cd /tmp/phalcon/build && ./install; \
    echo 'extension=phalcon.so' > /usr/local/etc/php/conf.d/30-phalcon.ini; \
    php -m | grep -qi phalcon

# Composer 依赖（vendor 约 221MB / 3.2 万文件，构建期一次装好）
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --prefer-dist \
      --no-progress --no-interaction --optimize-autoloader
COPY . .


FROM php:7.3-fpm-buster AS runtime

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    printf '%s\n' \
      'deb http://archive.debian.org/debian buster main' \
      'deb http://archive.debian.org/debian buster-updates main' \
      'deb http://archive.debian.org/debian-security buster/updates main' \
      > /etc/apt/sources.list; \
    printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99archive; \
    apt-get update; \
    apt-get install -y --no-install-recommends nginx-light; \
    rm -rf /var/lib/apt/lists/*

# 复用构建阶段的 PHP 扩展（同基础镜像，ABI 一致）
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

COPY --from=builder /app /app
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 只读根文件系统下，storage 必须落到 /tmp。
# 在构建期就做成符号链接（运行时无法创建），应用代码无需改动路径。
RUN set -eux; \
    rm -rf /app/storage/cache /app/storage/log; \
    ln -sfn /tmp/cache /app/storage/cache; \
    ln -sfn /tmp/log /app/storage/log; \
    mkdir -p /app/storage/tmp

# 生产档位：关掉调试输出，开启 opcache
RUN printf '%s\n' \
      'display_errors=Off' \
      'log_errors=On' \
      'error_log=/proc/self/fd/2' \
      'opcache.enable=1' \
      'opcache.memory_consumption=192' \
      'opcache.max_accelerated_files=20000' \
      'opcache.validate_timestamps=0' \
      > /usr/local/etc/php/conf.d/99-production.ini

WORKDIR /app
EXPOSE 80
CMD ["/usr/local/bin/entrypoint.sh"]
