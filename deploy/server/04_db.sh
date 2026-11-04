#!/bin/bash
# 阶段三：MariaDB 10.5 + Redis 6
set -e

echo "===== [1/5] 安装 MariaDB 与 Redis ====="
dnf install -y --disablerepo='*' --enablerepo='alinux3-*' --enablerepo=epel \
    --setopt=timeout=60 --setopt=retries=2 \
    mariadb-server mariadb redis 2>&1 | tail -8

echo "===== [2/5] 内存友好的 MariaDB 配置 ====="
mkdir -p /etc/my.cnf.d
cat > /etc/my.cnf.d/ctc-tune.cnf <<'EOF'
[mysqld]
# 1.9G 内存的小机器，压缩缓冲池
innodb_buffer_pool_size     = 128M
innodb_log_file_size        = 64M
innodb_flush_method         = O_DIRECT
max_connections             = 60
table_open_cache            = 256
tmp_table_size              = 32M
max_heap_table_size         = 32M
performance_schema          = OFF
innodb_file_per_table       = 1
character-set-server        = utf8mb4
collation-server            = utf8mb4_general_ci
skip-name-resolve
EOF

echo "===== [3/5] 启动服务 ====="
systemctl enable --now mariadb redis >/dev/null 2>&1 || true
sleep 5
systemctl is-active mariadb redis

echo "===== [4/5] 创建库与账号 ====="
mariadb -uroot <<'SQL'
CREATE DATABASE IF NOT EXISTS ctc DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS 'ctc'@'localhost' IDENTIFIED BY 'PUT-YOUR-DB-PASSWORD';
CREATE USER IF NOT EXISTS 'ctc'@'127.0.0.1' IDENTIFIED BY 'PUT-YOUR-DB-PASSWORD';
GRANT ALL PRIVILEGES ON ctc.* TO 'ctc'@'localhost';
GRANT ALL PRIVILEGES ON ctc.* TO 'ctc'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
mariadb -uroot -e "select version() as mariadb_version; show databases;" | head -8
redis-cli ping

echo "===== [5/5] 内存占用 ====="
free -m | head -3
echo "STAGE3_OK"
