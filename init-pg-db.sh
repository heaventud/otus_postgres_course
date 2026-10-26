#!/usr/bin/env bash

set -e

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
    CREATE USER test_user PASSWORD 'secret123';
    CREATE DATABASE my_test_db;
    GRANT ALL PRIVILEGES ON DATABASE my_test_db TO test_user;
EOSQL

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d my_test_db <<-EOSQL
    GRANT USAGE, CREATE ON SCHEMA public TO test_user;
EOSQL

echo "host all all 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT pg_reload_conf();"
