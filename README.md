# 2FA Infrastructure

This project provisions and runs a Multi-Factor Authentication (MFA) stack using Keycloak and PrivacyIDEA.

The environment is managed via [Docker Compose](https://docs.docker.com/compose/) and orchestrated using [Mise](https://mise.jdx.dev/) tasks. Secrets and certificates are retrieved dynamically from HashiCorp Vault via Ansible.

## Architecture

* **Traefik**: Reverse proxy handling HTTP/HTTPS routing.
* **Keycloak**: Identity and Access Management (IAM) server (version 26+).
* **PrivacyIDEA**: Two Factor Authentication system.
* **MariaDB**: Centralized database backend for both Keycloak and PrivacyIDEA.

## Prerequisites

1. [Docker](https://docs.docker.com/engine/install/) and Docker Compose
2. [Mise](https://mise.jdx.dev/getting-started.html) installed on the host
3. Access to HashiCorp Vault for fetching credentials

## Quick Start

Bring up the entire stack (fetches Vault secrets, generates `.env`, writes certificates, and starts Docker containers):

```bash
mise run start
```

If a database backup was downloaded from S3 into `databases/`, `start` will print the exact `mise run db:restore` command to load it.

### Access URLs

* **Keycloak**: `https://keycloak-mfa.crosswired.me`

* **PrivacyIDEA**: `https://pi-mfa.crosswired.me`

* **Traefik Dashboard**: `http://localhost:8080`

## Available Tasks

Manage the stack easily using `mise run <task>`:

| Task | Description |
|---|---|
| `start` | Fetch secrets via Ansible, generate `.env` and certs, start Docker stack |
| `start:services` | Start docker compose |
| `stop` | Stop all containers gracefully |
| `stop:keycloak` | Stop only the Keycloak container |
| `stop:mariadb` | Stop only the MariaDB container |
| `stop:pi` | Stop only the PrivacyIDEA container |
| `start:keycloak` | Start (or create) the Keycloak container |
| `start:mariadb` | Start an existing, stopped MariaDB container |
| `start:pi` | Start an existing, stopped PrivacyIDEA container |
| `start:privacyidea` | Start (or create) the PrivacyIDEA container |
| `build:keycloak` | Build custom Keycloak image with PrivacyIDEA provider via Ansible |
| `down` | Stop and remove containers (keeps volumes intact) |
| `restart` | Restart all containers |
| `logs:keycloak` | check keycloak logs |
| `logs:privacyidea` | check privacyidea logs |
| `logs:mariadb` | check mariadb logs |
| `ps` | List running containers |
| `pull` | Pull latest Docker images |
| `db:export` | Dump the Keycloak and PrivacyIDEA databases into `databases/mariadb_backup_<timestamp>.tar.gz` |
| `db:restore [file]` | Restore MariaDB databases from a `.tar.gz` backup file; defaults to the most recent file in `databases/` if none is given |
| `clean` | **DANGER**: Stop stack, delete volumes, DB backups, and remove generated certs |

## Backup and Restore

**Export Database**:

```bash
mise run db:export
```

This dumps only the application databases (Keycloak and PrivacyIDEA — not MariaDB's internal system tables) and compresses them into `databases/mariadb_backup_<timestamp>.tar.gz`.

**Restore Database**:

```bash
mise run db:restore                                              # restores the most recent backup in databases/
mise run db:restore databases/mariadb_backup_20260914_123456.tar.gz   # restores a specific backup
```

After restoring, the task automatically resyncs MariaDB's internal healthcheck credentials and waits for the container to report `healthy` before exiting.