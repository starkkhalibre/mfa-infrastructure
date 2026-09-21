# 2FA Infrastructure

Keycloak + PrivacyIDEA MFA stack running on two hosts with Docker Compose.
No Swarm: each host runs its own Compose project and they talk over published ports.
Secrets/certs come from HashiCorp Vault via Ansible (`mise run deploy`).

## Hosts

| Host | Services |
|---|---|
| **node_1_primary** (`192.168.241.45`) | Traefik, MariaDB primary, Keycloak 1, PrivacyIDEA |
| **node_2_secondary** (`192.168.241.51`) | MariaDB secondary, Keycloak 2, PrivacyIDEA (standby) |

## Quick start

```bash
mise run deploy                 # provision secrets/certs + deploy both hosts
mise run db:restore <backup>    # load the S3 backup into the primary
mise run db:seed-secondary          # copy the primary into the secondary + start replication
```

Check it:

```bash
mise run ps                     # containers on both hosts
```

Access:

* Keycloak — https://keycloak-mfa.crosswired.me
* PrivacyIDEA — https://pi-mfa.crosswired.me
* Traefik dashboard — http://192.168.241.45:8080

## Common commands

| Command | What it does |
|---|---|
| `mise run deploy` | Provision + deploy both hosts |
| `mise run ps` | List containers on both hosts |
| `mise run logs:keycloak1` / `logs:keycloak2` | Keycloak logs |
| `mise run logs:privacyidea` | PrivacyIDEA logs |
| `mise run logs:mariadb-primary` / `logs:mariadb-secondary` | MariaDB logs |
| `mise run logs:traefik` | Traefik logs |
| `mise run stop` / `restart` / `down` | Stop / restart / remove both stacks |
| `mise run pull` | Pull images on both hosts |
| `mise run db:export` | Back up all databases to `databases/` |
| `mise run db:restore <file>` | Restore a backup into the primary |
| `mise run db:seed-secondary` | Seed the secondary from the primary |
| `mise run destroy` | Remove stacks, volumes, certs, backups |

## Failover / failback

```bash
mise run db:failover   # promote the secondary and point the apps at it
mise run db:failback   # revert to the primary
```

> Failback is only safe if nothing was written to the promoted secondary.
> Re-running `mise run deploy` resets `ACTIVE_DB_HOST` back to the primary.

## How it works

* `mise run deploy` runs Ansible (in the `ansible-ee` image) which fetches Vault
  secrets/certs, downloads the S3 backup, and copies only what each host needs
  to `/opt/docker-compose`, then starts each host's stack.
* MariaDB primary → secondary replication uses GTID (`scripts/seed-secondary.sh`).
* The secondary PrivacyIDEA uses the secondary database and is not routed by Traefik.
  Because the secondary is read-only, it only runs after `mise run db:failover` promotes it.

## Prerequisites

* Two hosts with Docker + Compose, SSH access, and passwordless `sudo`.
* The SSH key in `inventory.yml` (`ansible_ssh_private_key_file`), also exposed
  as `SSH_KEY` in `.env` for the scripts.
* [Mise](https://mise.jdx.dev/getting-started.html) + Docker on the control machine.
* Vault access and `inventory.yml` filled in.

## Verify replication

```bash
source .env && source scripts/_remote.sh
remote_secondary "docker exec mfa-mariadb-secondary mariadb -uroot -p'$MYSQL_ROOT_PASSWORD' -e 'SHOW ALL SLAVES STATUS\G'" |
grep -E "Slave_IO_Running:|Slave_SQL_Running:|Seconds_Behind_Master:"
```
