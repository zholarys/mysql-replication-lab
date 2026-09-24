#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"
umask 077
mkdir -p backups
exec 9>backups/.backup.lock
flock -n 9 || { echo "Another backup is running" >&2; exit 1; }
partial=$(mktemp backups/.backup.XXXXXXXX.partial)
trap 'rm -f "$partial"' EXIT
backup="backups/backup_$(date +%Y%m%d_%H%M%S)_$$.sql"
docker compose exec -T mysql-master sh -c '
export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"
exec mysqldump -uroot --single-transaction --no-tablespaces --set-gtid-purged=OFF shopdb
' > "$partial"
test -s "$partial"
mv "$partial" "$backup"
# Retain by age, not by count. Only this script's completed SQL files are eligible.
find backups -maxdepth 1 -type f -name 'backup_*.sql' -mmin +10080 -delete
echo "Backup completed: $backup"
