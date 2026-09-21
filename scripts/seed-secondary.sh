#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a; source "${SCRIPT_DIR}/../.env"; set +a
source "${SCRIPT_DIR}/_remote.sh"

tmp="$(mktemp /tmp/mfa-seed.XXXXXX.sql)"
trap 'rm -f "${tmp}"' EXIT

echo "Taking GTID-consistent snapshot from primary (${PRIMARY_HOST})..."
remote_primary "docker exec mfa-mariadb-primary mariadb-dump -uroot -p'${MYSQL_ROOT_PASSWORD}' --single-transaction --master-data=1 --gtid --databases '${KEYCLOAK_DB_NAME}' '${PI_DB_NAME}'" > "${tmp}"

echo "Resetting secondary (${SECONDARY_HOST})..."
remote_secondary "docker exec -i mfa-mariadb-secondary mariadb -uroot -p'${MYSQL_ROOT_PASSWORD}' -e 'STOP SLAVE;'" || true
remote_secondary "docker exec -i mfa-mariadb-secondary mariadb -uroot -p'${MYSQL_ROOT_PASSWORD}' -e 'RESET SLAVE ALL;'" || true
remote_secondary "docker exec -i mfa-mariadb-secondary mariadb -uroot -p'${MYSQL_ROOT_PASSWORD}' -e 'SET GLOBAL read_only = 0;'"

echo "Ensuring application and replication users on secondary..."
remote_secondary "docker exec -i mfa-mariadb-secondary mariadb -uroot -p'${MYSQL_ROOT_PASSWORD}'" <<-EOSQL
	CREATE USER IF NOT EXISTS '${KEYCLOAK_DB_USER}'@'%' IDENTIFIED BY '${KEYCLOAK_DB_PASSWORD}';
	ALTER USER '${KEYCLOAK_DB_USER}'@'%' IDENTIFIED BY '${KEYCLOAK_DB_PASSWORD}';
	GRANT ALL PRIVILEGES ON \`${KEYCLOAK_DB_NAME}\`.* TO '${KEYCLOAK_DB_USER}'@'%';

	CREATE USER IF NOT EXISTS '${PI_DB_USER}'@'%' IDENTIFIED BY '${PI_DB_PASSWORD}';
	ALTER USER '${PI_DB_USER}'@'%' IDENTIFIED BY '${PI_DB_PASSWORD}';
	GRANT ALL PRIVILEGES ON \`${PI_DB_NAME}\`.* TO '${PI_DB_USER}'@'%';

	CREATE USER IF NOT EXISTS '${MARIADB_REPLICATION_USER}'@'%' IDENTIFIED BY '${MARIADB_REPLICATION_PASSWORD}';
	ALTER USER '${MARIADB_REPLICATION_USER}'@'%' IDENTIFIED BY '${MARIADB_REPLICATION_PASSWORD}';
	GRANT REPLICATION SLAVE ON *.* TO '${MARIADB_REPLICATION_USER}'@'%';

	FLUSH PRIVILEGES;
EOSQL

echo "Loading snapshot into secondary..."
remote_secondary "docker exec -i mfa-mariadb-secondary mariadb -uroot -p'${MYSQL_ROOT_PASSWORD}'" < "${tmp}"

echo "Configuring GTID replication..."
remote_secondary "docker exec -i mfa-mariadb-secondary mariadb -uroot -p'${MYSQL_ROOT_PASSWORD}'" <<-EOSQL
	CHANGE MASTER TO
	  MASTER_HOST='${PRIMARY_HOST}',
	  MASTER_USER='${MARIADB_REPLICATION_USER}',
	  MASTER_PASSWORD='${MARIADB_REPLICATION_PASSWORD}',
	  MASTER_USE_GTID=slave_pos;
	SET GLOBAL read_only = 1;
	START SLAVE;
EOSQL

echo "Secondary status:"
remote_secondary "docker exec mfa-mariadb-secondary mariadb -uroot -p'${MYSQL_ROOT_PASSWORD}' -e 'SHOW SLAVE STATUS\G'" \
  | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_Error|Last_IO_Error|Last_SQL_Error" || true

echo "Seed complete."
