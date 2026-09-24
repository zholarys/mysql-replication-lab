#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
umask 077
sql() {
    docker compose exec -T "$1" sh -c 'export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"; exec mysql -uroot --batch --skip-column-names'
}
docker compose up -d --wait --wait-timeout 240
existing=$(printf 'SHOW REPLICA STATUS;\n' | sql mysql-replica)
if [[ -n "$existing" ]]; then
    echo "Replica is already configured. Inspect SHOW REPLICA STATUS before changing it." >&2
    exit 1
fi
count=$(printf "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='shopdb';\n" | sql mysql-replica)
[[ "$count" == 0 ]] || { echo "Replica shopdb is not empty; refusing to overwrite it." >&2; exit 1; }

# Restrict this lab password to SQL-safe alphanumeric input.
repl_password=$(docker compose exec -T mysql-master sh -c 'printf %s "$REPLICATION_PASSWORD"')
[[ "$repl_password" =~ ^[A-Za-z0-9_]{24,}$ ]] || { echo "Use a replication password of at least 24 alphanumeric/underscore characters." >&2; exit 1; }
printf "CREATE USER IF NOT EXISTS 'replicator'@'%%' IDENTIFIED BY '%s';\nALTER USER 'replicator'@'%%' IDENTIFIED BY '%s';\nGRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%%';\n" "$repl_password" "$repl_password" | sql mysql-master

snapshot=$(mktemp)
trap 'rm -f "$snapshot"' EXIT
# MySQL 8.0 source-data records coordinates belonging to this consistent snapshot.
# Do not execute DDL on shopdb while this command runs.
docker compose exec -T mysql-master sh -c '
export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"
exec mysqldump -uroot --single-transaction --source-data=2 --set-gtid-purged=OFF --no-tablespaces --databases shopdb
' > "$snapshot"
coordinates=$(sed -n "s/^-- CHANGE REPLICATION SOURCE TO SOURCE_LOG_FILE='\([^']*\)', SOURCE_LOG_POS=\([0-9]*\);/\1 \2/p" "$snapshot")
read -r log_file log_pos <<< "$coordinates"
[[ "$log_file" =~ ^[A-Za-z0-9._-]+$ && "$log_pos" =~ ^[0-9]+$ ]] || { echo "Snapshot replication coordinates not found" >&2; exit 1; }

sql mysql-replica < "$snapshot"
printf "CHANGE REPLICATION SOURCE TO SOURCE_HOST='mysql-master', SOURCE_USER='replicator', SOURCE_PASSWORD='%s', SOURCE_LOG_FILE='%s', SOURCE_LOG_POS=%s, GET_SOURCE_PUBLIC_KEY=1;\nSTART REPLICA;\n" "$repl_password" "$log_file" "$log_pos" | sql mysql-replica
printf 'SHOW REPLICA STATUS\\G\n' | sql mysql-replica
echo "Inspect Replica_IO_Running, Replica_SQL_Running and Last_*_Error, then verify a new source-side write."
