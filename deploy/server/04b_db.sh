#!/bin/bash
# 阶段三：启动 MariaDB/Redis，建库建账号
set -e

echo "===== [1/4] 写配置并启动 ====="
mkdir -p /etc/my.cnf.d
cat > /etc/my.cnf.d/ctc-tune.cnf <<'EOF'
[mysqld]
innodb_buffer_pool_size = 128M
innodb_log_file_size    = 64M
max_connections         = 60
table_open_cache        = 256
tmp_table_size          = 32M
max_heap_table_size     = 32M
performance_schema      = OFF
character-set-server    = utf8mb4
collation-server        = utf8mb4_general_ci
skip-name-resolve
EOF

systemctl enable mariadb redis >/dev/null 2>&1 || true
systemctl restart mariadb redis
sleep 6
echo -n "mariadb: "; systemctl is-active mariadb
echo -n "redis:   "; systemctl is-active redis

echo "===== [2/4] 建库建账号 ====="
mariadb -uroot <<'SQL'
CREATE DATABASE IF NOT EXISTS ctc DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS 'ctc'@'localhost' IDENTIFIED BY 'PUT-YOUR-DB-PASSWORD';
CREATE USER IF NOT EXISTS 'ctc'@'127.0.0.1' IDENTIFIED BY 'PUT-YOUR-DB-PASSWORD';
GRANT ALL PRIVILEGES ON ctc.* TO 'ctc'@'localhost';
GRANT ALL PRIVILEGES ON ctc.* TO 'ctc'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
mariadb -uroot -e "select version() as v;" | tail -1
redis-cli ping

echo "===== [3/4] 导入数据 ====="
if [ -f /root/ctc_deploy/ctc_db.sql ]; then
    mariadb -uroot --default-character-set=utf8mb4 ctc < /root/ctc_deploy/ctc_db.sql
    echo "导入完成"
    mariadb -uroot -N ctc -e "select count(*) as tables from information_schema.tables where table_schema='ctc';"
    mariadb -uroot ctc -e "select '课程' t, count(*) c from kg_course union all select '章节', count(*) from kg_chapter union all select '设置', count(*) from kg_setting;" 2>&1 | head -6
else
    echo "!! 未找到 SQL 文件"
fi

echo "===== [4/4] 资源 ====="
free -m | sed -n 2,3p
echo "STAGE3_OK"
