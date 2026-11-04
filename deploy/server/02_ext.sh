#!/bin/bash
# 阶段二：编译 Phalcon 3.4.5 + igbinary + redis（PHP 7.3）
set -e
mkdir -p /usr/local/src && cd /usr/local/src

echo "===== [1/6] 下载源码 ====="
curl -sSL -o phalcon.tar.gz https://github.com/phalcon/cphalcon/archive/refs/tags/v3.4.5.tar.gz
curl -sSL -o igbinary.tar.gz https://github.com/igbinary/igbinary/archive/refs/tags/3.2.15.tar.gz
curl -sSL -o redis.tar.gz https://github.com/phpredis/phpredis/archive/refs/tags/5.3.7.tar.gz
ls -lh *.tar.gz | awk '{print $9, $5}'

echo "===== [2/6] 编译 igbinary ====="
tar xzf igbinary.tar.gz && cd igbinary-3.2.15
phpize >/dev/null && ./configure --enable-igbinary >/dev/null 2>&1
make -j2 2>&1 | tail -2 && make install 2>&1 | tail -2
echo "extension=igbinary.so" > /etc/php.d/40-igbinary.ini
cd /usr/local/src

echo "===== [3/6] 编译 redis ====="
tar xzf redis.tar.gz && cd phpredis-5.3.7
phpize >/dev/null && ./configure --enable-redis --enable-redis-igbinary >/dev/null 2>&1
make -j2 2>&1 | tail -2 && make install 2>&1 | tail -2
echo "extension=redis.so" > /etc/php.d/40-redis.ini
cd /usr/local/src

echo "===== [4/6] 编译 Phalcon 3.4.5（耗时最长）====="
tar xzf phalcon.tar.gz && cd cphalcon-3.4.5/build
./install --phpize /usr/bin/phpize --php-config /usr/bin/php-config 2>&1 | tail -8

echo "===== [5/6] 写入 phalcon ini ====="
grep -q phalcon /etc/php.d/40-phalcon.ini 2>/dev/null || echo "extension=phalcon.so" > /etc/php.d/40-phalcon.ini

echo "===== [6/6] 验证 ====="
php -m 2>/dev/null | grep -iE 'phalcon|redis|igbinary'
php -r 'echo "phalcon version: ", phpversion("phalcon"), "\n";' 2>&1
php -r 'echo "redis version: ", phpversion("redis"), "\n";' 2>&1
echo "STAGE2_OK"
