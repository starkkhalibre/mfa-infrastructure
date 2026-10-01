# 2FA Infrastructure

This project provisions and runs a Multi-Factor Authentication (MFA) stack using Keycloak and PrivacyIDEA.

The environment is managed via [Docker Compose](https://docs.docker.com/compose/) and orchestrated using [Mise](https://mise.jdx.dev/) tasks. Secrets and certificates are retrieved dynamically from HashiCorp Vault via Ansible.

## Architecture

* **Traefik**: Reverse proxy handling HTTP/HTTPS routing.
* **Keycloak**: Identity and Access Management (IAM) server (version 26+).
* **PrivacyIDEA**: Two Factor Authentication system.
* **Percona XtraDB Cluster (PXC)**: Database backend for both Keycloak and PrivacyIDEA.

## Prerequisites

1. [Docker](https://docs.docker.com/engine/install/) and Docker Compose
2. [Mise](https://mise.jdx.dev/getting-started.html) installed on the host
3. Access to HashiCorp Vault for fetching credentials

For two-node deployment, the remote hosts must already have SSH, Docker, Docker Compose, `rsync`, and passwordless sudo prepared. Host preparation is handled by external Ansible tasks, not by this repository.

If Docker Hub authentication is required for image pulls, set `vault_docker_repo_username` and `vault_docker_repo_password` in the Ansible vault. Cluster deployment logs in on each remote node before Docker Compose pulls images.

## Quick Start

Bring up the entire stack (fetches Vault secrets, generates `.env`, writes certificates, and starts Docker containers):

```bash
mise run start
```

If a database backup was downloaded from S3 into `databases/`, `start` will print the exact `mise run db:restore` command to load it.

### Access URLs

* **Keycloak**: `https://keycloak-mfa-lab.crosswired.me`

* **PrivacyIDEA**: `https://pi-mfa-lab.crosswired.me`

* **Traefik Dashboard**: `http://localhost:8080`

## Available Tasks

Manage the stack easily using `mise run <task>`:

| Task | Description |
|---|---|
| `build:keycloak` | Build custom Keycloak image with PrivacyIDEA provider via Ansible |
| `sync` | Render node-specific config locally and sync project files to both nodes |
| `sync:node1` | Render node1 config locally and sync project files |
| `sync:node2` | Render node2 config locally and sync project files |
| `deploy:node1` | Start or update remote services on node1 |
| `deploy:node2` | Start or update remote services on node2 |
| `deploy:cluster` | Generate assets, sync both nodes, bootstrap node1, start node2, then verify |
| `cluster:status` | Show container and PXC status on both nodes |
| `cluster:verify` | Fail if either node, app containers, or the two-node PXC cluster is unhealthy |
| `logs:keycloak` | Show recent Keycloak logs on both nodes |
| `logs:privacyidea` | Show recent PrivacyIDEA logs on both nodes |
| `logs:pxc` | Show recent PXC logs on both nodes |
| `ps` | List stack containers on both nodes |
| `db:export` | Take a physical PXC backup into `databases/export/pxc_fullbackup_<timestamp>.tar.gz` |
| `db:restore [file]` | Restore PXC databases from a `.tar.gz` backup file; defaults to the most recent file in `databases/` if none is given |

## Two-Node Deployment

Set both cluster hosts in `ansible/inventory.yml` before deploying:

```yaml
node1:
  ansible_host: 192.168.10.11
  ansible_user: ubuntu
node2:
  ansible_host: 192.168.10.12
  ansible_user: ubuntu
```

Both `ansible_host` values are required and deployment will fail early if either is blank. Remote files are synced to `/opt/mfa-infrastructure`.

For nodes with slow storage, the PXC entrypoint wrapper extends the image's internal initialization wait from 120 to 600 seconds. Compose allows a 20-minute health-check grace period, and Ansible waits up to 20 minutes for each PXC readiness check. This prevents premature initialization timeouts; startup speed still depends on the node's storage.

Sync files and start/update the full two-node stack with:

```bash
mise run deploy:cluster
```

The deployment renders node-specific `.env`, `config/pxc/custom.cnf`, and `config/pxc/init.cnf` locally under the gitignored `.ansible/rendered/<node>/` directory, syncs shared project files followed by each node’s rendered files, pulls images, builds the Keycloak Dockerfile when Compose starts the stack, and starts the Docker Compose services. Node1 bootstraps PXC with `PXC_CLUSTER_JOIN=""` and `PI_SKIP_BOOTSTRAP=false`, while node2 joins node1 with `PXC_CLUSTER_JOIN=<node1 ansible_host>` and `PI_SKIP_BOOTSTRAP=true`. The cluster deployment starts node1 PXC, Traefik, and Keycloak first, waits for Keycloak to finish any database migrations, then starts the remaining services and node2. Fresh empty Keycloak databases can still take several minutes; use a prepared PXC backup for fast fresh environments. Both nodes run Traefik, PXC, Keycloak, and PrivacyIDEA. PXC uses host networking and advertises each host's inventory IP from `config/pxc/custom.cnf` for Galera, SST, and IST traffic so peer nodes do not try to connect to Docker bridge addresses and PXC can bind the advertised receive addresses. PXC inter-node replication and SST traffic is intentionally unencrypted with `pxc-encrypt-cluster-traffic=OFF`; both nodes must use the same setting and run on a trusted private network. Keycloak advertises each node's inventory IP for cache transport. Allow PXC traffic between nodes on `3306/tcp`, `4444/tcp`, `4567/tcp`, `4567/udp`, and `4568/tcp`; allow Keycloak cache traffic between nodes on `7800/tcp` and `57800/tcp`. Do not configure Traefik to write a sticky cookie named `AUTH_SESSION_ID`; that cookie is owned by Keycloak and overriding it can cause login redirect loops. The Keycloak image is tagged as `khalibre/mfa-keycloak:26.1.3-pi-1.8.0`.

Until a health-checked reverse proxy/load balancer with session affinity is
available, publish only node1 for the public MFA hostnames. This avoids sending
Keycloak browser sessions to the other node through raw DNS round-robin:

```dns
keycloak-mfa-lab.crosswired.me A <node1-ip>

pi-mfa-lab.crosswired.me       A <node1-ip>
```

Use the real `node1` IP from `ansible/inventory.yml`. Do not point a wildcard
record such as `*.crosswired.me` at the lab nodes, because that will redirect
unrelated dev subdomains to this stack. Keep Keycloak node-to-node traffic
open between both inventory IPs on `7800/tcp` and `57800/tcp`.

## Backup and Restore

**Export Database**:

```bash
mise run db:export
```

This creates a physical backup of the PXC data directory and compresses it into `databases/export/pxc_fullbackup_<timestamp>.tar.gz`.

**Restore Database**:

```bash
mise run db:restore                                              # restores the most recent backup in databases/
mise run db:restore databases/export/pxc_fullbackup_20260914_123456.tar.gz   # restores a specific backup
```

After restoring, the task waits for `mfa-pxc` to report `healthy` before exiting.
