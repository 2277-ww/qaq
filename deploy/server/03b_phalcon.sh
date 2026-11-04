#!/bin/bash
# 阶段二（最终）：只跑一次 -O1 编译，避免 OOM 与重复编译
pkill -9 -f '03.sh' 2>/dev/null || true
pkill -9 -f 'cphalcon-3.4.5/build/install' 2>/dev/null || true
pkill -9 -f 'cc1' 2>/dev/null || true
pkill -9 -f '^make' 2>/dev/null || true
sleep 2

echo "===== [1/4] 清理旧产物 ====="
cd /usr/local/src/cphalcon-3.4.5/build/php7/64bits || { echo "目录不存在"; exit 1; }
make clean >/dev/null 2>&1 || true
ls *.lo .libs/*.so 2>/dev/null | head -3
echo "已清理"

echo "===== [2/4] -O1 单线程编译（约 8-15 分钟）====="
date +%H:%M:%S
make -j1 CFLAGS="-O1 -fno-var-tracking -fPIC -DPHALCON_RELEASE" 2>&1 | tail -8
date +%H:%M:%S

echo "===== [3/4] 安装 ====="
make install 2>&1 | tail -3

echo "===== [4/4] 验证 ====="
echo "extension=phalcon.so" > /etc/php.d/40-phalcon.ini
php -r 'echo "phalcon: ", (phpversion("phalcon") ?: "未加载"), "\n";' 2>&1 | tail -2
free -m | sed -n 2,3p
echo "STAGE2C_DONE"
