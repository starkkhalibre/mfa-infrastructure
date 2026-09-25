# MFA Infrastructure

This project provisions and runs a Multi-Factor Authentication (MFA) stack using Keycloak and PrivacyIDEA.

Docker Compose runs the services. Mise runs the commands. Ansible generates the local runtime files from Vault-backed variables.

## Architecture

* **Traefik**: Reverse proxy handling HTTP/HTTPS routing.
* **Keycloak**: Identity and Access Management (IAM) server (version 26+).
* **PrivacyIDEA**: Two Factor Authentication system.
* **MariaDB**: Centralized database backend for both Keycloak and PrivacyIDEA.
* **smtp4dev**: Internal SMTP catcher and web inbox for test mail.

## Prerequisites

1. [Docker](https://docs.docker.com/engine/install/) and Docker Compose
2. [Mise](https://mise.jdx.dev/getting-started.html) installed on the host
3. Access to HashiCorp Vault for fetching credentials

## Deploy

Generate runtime files and start the stack:

```bash
mise run start
```

This generates `.env`, certificates, PrivacyIDEA encfile, MariaDB config, renders the Keycloak Dockerfile, builds the custom Keycloak image, and then starts Docker Compose. If Ansible downloads a database backup, the task prints the restore command.

### Access URLs

* **Keycloak**: `https://keycloak-mfa.crosswired.me`
* **PrivacyIDEA**: `https://pi-mfa.crosswired.me`
* **Mail Inbox**: `https://mfa-mail.crosswired.me`
* **Traefik Dashboard**: `http://localhost:8080`

Internal SMTP endpoint for containers on the stack network: `smtp4dev:25`.

Generated MariaDB config is written to `config/mariadb/conf.d/`. The generated root `Dockerfile` and MariaDB config are ignored by git.

## Tasks

Run tasks with `mise run <task>`.

| Task | Description |
|---|---|
| `start` | Generate runtime files, build Keycloak, and start the stack |
| `start:services` | Start Compose services without Ansible |
| `stop` / `restart` / `down` | Stop, restart, or remove containers |
| `start:keycloak` / `stop:keycloak` / `logs:keycloak` | Manage Keycloak |
| `start:mariadb` / `stop:mariadb` / `logs:mariadb` | Manage MariaDB |
| `start:pi` / `stop:pi` / `logs:privacyidea` | Manage PrivacyIDEA |
| `start:mail` / `stop:mail` / `logs:mail` | Manage smtp4dev |
| `build:keycloak` | Render Dockerfile and build custom Keycloak image |
| `ps` / `pull` | Show containers or pull images |
| `db:export` | Create a full MariaDB physical backup in `databases/export/` |
| `db:restore [file]` | Restore the newest backup, or a specific `.tar.gz` file |
| `clean` | Remove containers, volumes, generated files, and DB backups |
