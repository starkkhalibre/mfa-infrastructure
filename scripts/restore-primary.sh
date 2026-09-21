#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a; source "${SCRIPT_DIR}/../.env"; set +a
source "${SCRIPT_DIR}/_remote.sh"

infile="${1:-}"
if [ -z "${infile}" ] || [ ! -f "${infile}" ]; then
  echo "Usage: $0 <backup.tar.gz>" >&2
  exit 1
fi

HEALTHCHECK_PASS=$(remote_primary "docker exec mfa-mariadb-primary grep '^password=' /var/lib/mysql/.my-healthcheck.cnf | cut -d= -f2")

echo "Restoring ${infile} into mfa-mariadb-primary (${PRIMARY_HOST})..."
tar -xzvOf "${infile}" | remote_primary "docker exec -i mfa-mariadb-primary mariadb -uroot -p'${MYSQL_ROOT_PASSWORD}'"

echo "Re-ensuring application and replication users..."
remote_primary "docker exec -i mfa-mariadb-primary mariadb -uroot -p'${MYSQL_ROOT_PASSWORD}'" <<-EOSQL
	FLUSH PRIVILEGES;

	SET sql_log_bin = 0;
	CREATE USER IF NOT EXISTS 'healthcheck'@'127.0.0.1' IDENTIFIED BY '${HEALTHCHECK_PASS}';
	CREATE USER IF NOT EXISTS 'healthcheck'@'localhost' IDENTIFIED BY '${HEALTHCHECK_PASS}';
	ALTER USER 'healthcheck'@'127.0.0.1' IDENTIFIED BY '${HEALTHCHECK_PASS}';
	ALTER USER 'healthcheck'@'localhost' IDENTIFIED BY '${HEALTHCHECK_PASS}';
	SET sql_log_bin = 1;
	
	CREATE DATABASE IF NOT EXISTS \`${KEYCLOAK_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
	CREATE DATABASE IF NOT EXISTS \`${PI_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

	CREATE USER IF NOT EXISTS '${KEYCLOAK_DB_USER}'@'%' IDENTIFIED BY '${KEYCLOAK_DB_PASSWORD}';
	GRANT ALL PRIVILEGES ON \`${KEYCLOAK_DB_NAME}\`.* TO '${KEYCLOAK_DB_USER}'@'%';

	CREATE USER IF NOT EXISTS '${PI_DB_USER}'@'%' IDENTIFIED BY '${PI_DB_PASSWORD}';
	GRANT ALL PRIVILEGES ON \`${PI_DB_NAME}\`.* TO '${PI_DB_USER}'@'%';

	CREATE USER IF NOT EXISTS '${MARIADB_REPLICATION_USER}'@'%' IDENTIFIED BY '${MARIADB_REPLICATION_PASSWORD}';
	GRANT REPLICATION REPLICA ON *.* TO '${MARIADB_REPLICATION_USER}'@'%';

	FLUSH PRIVILEGES;
EOSQL

echo "Restore complete."
