#!/bin/bash
# 阶段二（修正）：加 swap + 降优化级别，重编 Phalcon 3.4.5
set -e

echo "===== [1/5] 创建 4G swap ====="
if [ ! -f /swapfile_ctc ]; then
    dd if=/dev/zero of=/swapfile_ctc bs=1M count=4096 status=none
    chmod 600 /swapfile_ctc
    mkswap /swapfile_ctc >/dev/null
fi
swapon /swapfile_ctc 2>/dev/null || true
grep -q swapfile_ctc /etc/fstab || echo "/swapfile_ctc swap swap defaults 0 0" >> /etc/fstab
free -m | head -3

echo "===== [2/5] 生成 Makefile ====="
cd /usr/local/src/cphalcon-3.4.5/build
./install --phpize /usr/bin/phpize --php-config /usr/bin/php-config >/tmp/ph_install.log 2>&1 || true

echo "===== [3/5] 用 -O1 单线程重编 ====="
cd /usr/local/src/cphalcon-3.4.5/build/php7/64bits
make clean >/dev/null 2>&1 || true
make -j1 CFLAGS="-O1 -fno-var-tracking -fPIC -DPHALCON_RELEASE" 2>&1 | tail -6

echo "===== [4/5] 安装模块 ====="
make install 2>&1 | tail -3
ls -la /usr/lib64/php/modules/phalcon.so 2>/dev/null || echo "!! 仍未生成 phalcon.so"

echo "===== [5/5] 验证 ====="
echo "extension=phalcon.so" > /etc/php.d/40-phalcon.ini
php -r 'echo "phalcon: ", phpversion("phalcon") ?: "未加载", "\n";' 2>&1 | tail -3
free -m | head -3
echo "STAGE2B_DONE"
