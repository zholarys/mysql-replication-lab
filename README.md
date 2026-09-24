# MySQL source/replica lab

Docker Compose lab using MySQL 8.0 file/position replication and consistent `shopdb` snapshots. Requires Bash, Docker Compose with `--wait`, and `flock`. Containers publish database ports only on loopback.

## Setup from fresh volumes

```bash
cp .env.example .env
# Replace both passwords; generate values with: openssl rand -hex 32
bash scripts/setup-replication.sh
```

The script starts healthy instances, creates a replication user, takes a consistent source snapshot with its binlog coordinates, imports it into an empty replica and starts replication from those coordinates. It refuses an already configured replica or a nonempty replica shopdb. Do not change table schemas while taking the snapshot. It is a bootstrap tool, not an automatic repair/failover tool.

## Verify replication

```bash
docker compose exec -T mysql-master sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot shopdb -e "CREATE TABLE IF NOT EXISTS replication_probe (id INT PRIMARY KEY, note VARCHAR(50)); INSERT INTO replication_probe VALUES (1, '''replicated''') ON DUPLICATE KEY UPDATE note=VALUES(note);"'
docker compose exec -T mysql-replica sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -e "SHOW REPLICA STATUS\G"'
docker compose exec -T mysql-replica sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot shopdb -e "SELECT * FROM replication_probe;"'
```

Replication is asynchronous: allow time for the new table/row to arrive. Require `Replica_IO_Running: Yes`, `Replica_SQL_Running: Yes`, no replication errors, and the expected row. Both threads running alone do not prove data consistency.

`read-only=1` discourages ordinary application writes to the replica; administrators can bypass it. Replication credentials and `GET_SOURCE_PUBLIC_KEY=1` are for this isolated lab; production requires authenticated TLS and restricted access.

## Back up and restore

```bash
bash backup.sh
# Substitute the exact file printed by backup.sh:
bash scripts/restore-check.sh backups/backup_TIMESTAMP.sql
```

Backups contain only shopdb, have private permissions, use a partial file until success and retain completed files for seven days by age. The backup script does not install a scheduler. An interrupted dump is not promoted to a complete copy. Backups on this host do not protect against loss of the host.

The restore helper imports into a newly named database on the source server and lists tables. For the probe table, inspect the new database with `SELECT * FROM replication_probe;` and expect `(1, 'replicated')`. Validate application-specific counts and values for other datasets. The helper does not claim automatic full data verification or erase the restored database. In production, restore into an isolated verification server.

## Replication recovery

If a replication thread stops, preserve its error and determine why source and replica differ. Do not repair by blindly jumping to the source's current binlog position: that skips transactions. Rebuild from a consistent snapshot with matching coordinates, or use a properly designed GTID recovery procedure. Source binlogs must remain available until consumed. Replication is not a backup: deletions also replicate.

Changing passwords in `.env` does not rotate passwords in existing MySQL volumes. `docker compose down` preserves data; `docker compose down -v` destroys both databases and is only appropriate for an intentional lab reset.
