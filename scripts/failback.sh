#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a; source "${SCRIPT_DIR}/../.env"; set +a
source "${SCRIPT_DIR}/_remote.sh"

echo "Returning secondary (${SECONDARY_HOST}) to read-only and resuming replication..."
remote_secondary "docker exec -i mfa-mariadb-secondary mariadb -uroot -p'${MYSQL_ROOT_PASSWORD}'" <<-EOSQL
	STOP SLAVE;
	SET GLOBAL read_only = 1;
	CHANGE MASTER TO
	  MASTER_HOST='${PRIMARY_HOST}',
	  MASTER_USER='${MARIADB_REPLICATION_USER}',
	  MASTER_PASSWORD='${MARIADB_REPLICATION_PASSWORD}',
	  MASTER_USE_GTID=slave_pos;
	START SLAVE;
EOSQL

echo "Pointing applications at ${PRIMARY_HOST}..."
remote_primary "sudo sed -i 's/^ACTIVE_DB_HOST=.*/ACTIVE_DB_HOST=${PRIMARY_HOST}/' /opt/docker-compose/.env"
remote_secondary  "sudo sed -i 's/^ACTIVE_DB_HOST=.*/ACTIVE_DB_HOST=${PRIMARY_HOST}/' /opt/docker-compose/.env"

echo "Re-deploying the applications..."
remote_primary "cd /opt/docker-compose && sudo docker compose -p mfa -f docker-compose.primary.yml up -d keycloak privacyidea"
remote_secondary  "cd /opt/docker-compose && sudo docker compose -p mfa -f docker-compose.secondary.yml up -d keycloak privacyidea"

echo "Failback complete. ${PRIMARY_HOST} is active again."
