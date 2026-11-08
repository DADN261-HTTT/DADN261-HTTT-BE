#!/bin/bash
# Chạy 1 lần khi khởi tạo MySQL lần đầu (volume còn trống).
# Tạo database <MYSQL_DATABASE>_test cho kiểm thử tự động và cấp quyền cho tài khoản ứng dụng.
set -e
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}_test\`
        CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
    GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}_test\`.* TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL