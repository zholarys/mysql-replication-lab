#!/bin/bash
set -euo pipefail

BACKUP_DIR="$(dirname "$0")/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CONTAINER="mysql-replication-lab-mysql-master-1"

mkdir -p "$BACKUP_DIR"

docker exec "$CONTAINER" mysqldump -uroot -prootpass --all-databases --single-transaction > "$BACKUP_DIR/backup_${TIMESTAMP}.sql"

# Хранить только последние 7 бэкапов
find "$BACKUP_DIR" -name "backup_*.sql" -mtime +7 -delete

echo "Backup completed: backup_${TIMESTAMP}.sql"
