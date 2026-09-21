#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a; source "${SCRIPT_DIR}/../.env"; set +a
source "${SCRIPT_DIR}/_remote.sh"

echo "Promoting secondary (${SECONDARY_HOST})..."
remote_secondary "docker exec mfa-mariadb-secondary mariadb -uroot -p'${MYSQL_ROOT_PASSWORD}' -e 'STOP SLAVE; RESET SLAVE ALL; SET GLOBAL read_only = 0;'"

echo "Pointing applications at ${SECONDARY_HOST}..."
remote_primary "sudo sed -i 's/^ACTIVE_DB_HOST=.*/ACTIVE_DB_HOST=${SECONDARY_HOST}/' /opt/docker-compose/.env" || echo "Primary unreachable, skipping."
remote_secondary  "sudo sed -i 's/^ACTIVE_DB_HOST=.*/ACTIVE_DB_HOST=${SECONDARY_HOST}/' /opt/docker-compose/.env"

echo "Re-deploying the applications..."
remote_primary "cd /opt/docker-compose && sudo docker compose -p mfa -f docker-compose.primary.yml up -d keycloak privacyidea" || echo "Primary unreachable, skipping."
remote_secondary  "cd /opt/docker-compose && sudo docker compose -p mfa -f docker-compose.secondary.yml up -d keycloak privacyidea"

echo "Failover complete. ${SECONDARY_HOST} is now the active primary."
