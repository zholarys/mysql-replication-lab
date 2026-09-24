#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
archive=${1:?Usage: bash scripts/restore-check.sh backups/backup_TIMESTAMP.sql}
test -s "$archive"
db="restore_check_$(date +%Y%m%d_%H%M%S)_$$"
docker compose exec -T mysql-master sh -c '
export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"
exec mysql -uroot -e "CREATE DATABASE $1"
' sh "$db"
docker compose exec -T mysql-master sh -c '
export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"
exec mysql -uroot "$1"
' sh "$db" < "$archive"
docker compose exec -T mysql-master sh -c '
export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"
exec mysql -uroot "$1" -e "SHOW TABLES;"
' sh "$db"
echo "Restored into $db; compare expected rows/values before declaring the backup verified."
echo "The verification database is retained for inspection."
