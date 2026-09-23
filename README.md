# MySQL Master-Replica Replication Lab

A Docker Compose lab demonstrating MySQL master-replica replication, backup strategy, and restore verification.

## Architecture

- `mysql-master`: primary instance with binary logging enabled (server-id=1)
- `mysql-replica`: read-only replica consuming the master's binlog (server-id=2)

## What it shows

- Setting up binlog-based replication from scratch (`CHANGE REPLICATION SOURCE TO`)
- Diagnosing and recovering a broken replication stream (SQL thread stopped on `Unknown database` error caused by a DDL statement executed before the replication start position; resolved by resetting replica state and reconnecting from the master's current binlog position)
- Automated `mysqldump` backups with 7-day retention via `backup.sh`
- Verified restore procedure — a backup is only useful if it's been tested

## Stack

Docker Compose, MySQL 8.0, Bash

## Usage

Start the stack:
\`\`\`bash
docker compose up -d
\`\`\`

Check replication status:
\`\`\`bash
docker exec -i mysql-replication-lab-mysql-replica-1 mysql -uroot -prootpass -e "SHOW REPLICA STATUS\G"
\`\`\`

Run a backup:
\`\`\`bash
./backup.sh
\`\`\`
