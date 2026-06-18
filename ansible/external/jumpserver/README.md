<div align="center">

<img src="https://raw.githubusercontent.com/jumpserver/jumpserver/master/apps/static/img/logo-color.svg" alt="JumpServer Logo" width="320" />

# ansible-jumpserver

**Ansible role to deploy [JumpServer](https://www.jumpserver.com) open-source edition (v4.x) on Linux.**  
Automates the full lifecycle: prerequisites → download → configuration → install → verify.

[![Ansible](https://img.shields.io/badge/Ansible-2.12%2B-red?logo=ansible&logoColor=white)](https://docs.ansible.com)
[![JumpServer](https://img.shields.io/badge/JumpServer-v4.x-blue?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTEyIDJDNi40OCAyIDIgNi40OCAyIDEyczQuNDggMTAgMTAgMTAgMTAtNC40OCAxMC0xMFMxNy41MiAyIDEyIDJ6Ii8+PC9zdmc+)](https://www.jumpserver.com)
[![Platform](https://img.shields.io/badge/platform-linux%2Fx86__64-lightgrey?logo=linux&logoColor=white)](https://github.com/jumpserver/installer)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

</div>

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Role Variables](#role-variables)
- [Online vs Offline Install](#online-vs-offline-install)
- [Secrets & Vault](#secrets--vault)
- [Ports Reference](#ports-reference)
- [Idempotency](#idempotency)

---

## Overview

JumpServer is an open-source Privileged Access Management (PAM) / bastion host solution. It provides audited SSH, RDP, and web-based access to infrastructure assets.

This role deploys JumpServer **natively in Ansible** by orchestrating the official Docker Compose definitions directly — it never executes `jmsctl.sh` or any shell installer. The installer tarball is downloaded only to reuse its declarative `compose/*.yml` and `config_init/` files; the stack is brought up with `community.docker.docker_compose_v2`. There is **no official Ansible role** published by the JumpServer project.

> **Note:** JumpServer v4.x switched its default database from MariaDB to **PostgreSQL** in April 2024. Older tutorials referencing MariaDB as the default are outdated.

---

## Architecture

```
Ansible Controller
      │
      │  SSH (become: sudo)
      ▼
Target Host (Linux x86_64, kernel ≥ 4.0)
├── /opt/jumpserver-installer-{version}/
│   ├── compose/*.yml      ← compose definitions reused as data (no script run)
│   └── .env               ← symlink → config.txt (compose substitution vars)
├── /opt/jumpserver/
│   └── config/
│       ├── config.txt     ← generated from Ansible template (env_file + .env)
│       ├── nginx|redis|.. ← seeded from the tarball's config_init/
│       └── certs/         ← optional TLS certs (Redis / HTTPS)
└── Docker Engine + compose v2 plugin (assumed present on the target)
```

Components brought up via `community.docker.docker_compose_v2`:

| Service      | Role                         | Default port |
|-------------|------------------------------|-------------|
| Core         | Django API + Celery workers  | internal    |
| Web          | Nginx frontend               | 80 / 443    |
| KoKo         | SSH / SFTP proxy             | 2222        |
| Lion         | RDP proxy (Guacamole)        | 3389        |
| PostgreSQL   | Primary database             | 5432        |
| Redis        | Cache / sessions / pubsub    | 6379        |

---

## Prerequisites

| Requirement       | Minimum version         |
|-------------------|------------------------|
| OS                | Linux (Debian / RedHat family) |
| Architecture      | x86_64 only            |
| Kernel            | ≥ 4.0                  |
| Ansible           | ≥ 2.12                 |
| Python (target)   | ≥ 3.8                  |
| Disk              | ≥ 50 GB in `/opt`      |
| RAM               | ≥ 8 GB (16 GB recommended) |

The role installs `tar` on the target (for tarball extraction). **Docker Engine and the `docker compose` v2 plugin must already be present** — the role asserts this and fails fast otherwise.

It also requires the `community.docker` collection on the controller:

```bash
ansible-galaxy collection install -r requirements.yml
```

---

## Repository Structure

```
jumpserver/
├── ansible.cfg                          # Inventory path, privilege escalation
├── site.yml                             # Main playbook entry point
│
├── inventory/
│   ├── hosts.yml                        # Target hosts
│   └── group_vars/
│       ├── jumpserver.yml               # Environment-level variable overrides
│       └── vault.yml                    # Encrypted secrets (ansible-vault)
│
└── roles/jumpserver/
    ├── defaults/main.yml                # All variables with documented defaults
    ├── meta/main.yml                    # Galaxy metadata + supported platforms
    ├── handlers/main.yml                # restart handler (docker_compose_v2 restarted)
    ├── tasks/
    │   ├── main.yml                     # Import order
    │   ├── prerequisites.yml            # OS/kernel asserts + Docker/compose check
    │   ├── download.yml                 # Fetch + extract tarball (compose data only)
    │   ├── configure.yml                # config.txt + seed config_init + .env link
    │   └── deploy.yml                   # Select compose files → docker compose up
    └── templates/
        └── config.txt.j2               # /opt/jumpserver/config/config.txt
```

---

## Quick Start

### 1 — Clone and configure inventory

```bash
git clone <this-repo> jumpserver
cd jumpserver
```

Edit [`inventory/hosts.yml`](inventory/hosts.yml) with your server address:

```yaml
all:
  children:
    jumpserver:
      hosts:
        jumpserver01:
          ansible_host: 192.168.1.100
          ansible_user: root
```

### 2 — Set secrets

Edit [`inventory/group_vars/vault.yml`](inventory/group_vars/vault.yml):

```yaml
jumpserver_db_password: "your-strong-db-password"
jumpserver_redis_password: "your-strong-redis-password"
# Required — generate once and keep stable:
#   openssl rand -hex 32   /   openssl rand -hex 16
jumpserver_secret_key: "your-48+char-secret-key"
jumpserver_bootstrap_token: "your-bootstrap-token"
```

Then encrypt it:

```bash
ansible-vault encrypt inventory/group_vars/vault.yml
```

### 3 — Set version and mode

Edit [`inventory/group_vars/jumpserver.yml`](inventory/group_vars/jumpserver.yml):

```yaml
jumpserver_version: "v4.10.16"
jumpserver_install_mode: online   # or: offline
```

### 4 — Deploy

```bash
ansible-playbook site.yml --ask-vault-pass
```

Once complete, JumpServer is available at `http://<host>` (default credentials: `admin` / `ChangeMe`).

---

## Role Variables

All variables are defined in [`roles/jumpserver/defaults/main.yml`](roles/jumpserver/defaults/main.yml) with inline documentation.

### Core

| Variable | Default | Description |
|---|---|---|
| `jumpserver_version` | `v4.10.16` | JumpServer release tag |
| `jumpserver_image_tag` | `{{ version }}-ce` | Docker image tag (open-source `-ce` suffix) |
| `jumpserver_install_mode` | `online` | `online` or `offline` |
| `jumpserver_install_path` | `/opt` | Base installation directory |
| `jumpserver_config_dir` | `/opt/jumpserver/config` | Runtime config directory |
| `jumpserver_volume_dir` | `/data/jumpserver` | Persistent data (DB, recordings, logs) |

### Database

| Variable | Default | Description |
|---|---|---|
| `jumpserver_db_engine` | `postgresql` | `postgresql` or `mysql` |
| `jumpserver_db_host` | `postgresql` | `postgresql`/`mysql` = bundled container; host/IP = external DB |
| `jumpserver_db_port` | `5432` | DB port (`3306` for MySQL) |
| `jumpserver_db_name` | `jumpserver` | Database name |
| `jumpserver_db_user` | `jumpserver` | Database user |
| `jumpserver_db_password` | — | **Set in vault.yml** |

### Redis

| Variable | Default | Description |
|---|---|---|
| `jumpserver_redis_host` | `redis` | `redis` = bundled container; host/IP = external Redis |
| `jumpserver_redis_port` | `6379` | Redis port |
| `jumpserver_redis_password` | — | **Set in vault.yml** |
| `jumpserver_redis_use_sentinel` | `false` | Enable Redis Sentinel HA |
| `jumpserver_redis_sentinel_hosts` | `""` | e.g. `sentinel1:26379,sentinel2:26379` |
| `jumpserver_redis_use_ssl` | `false` | Enable Redis TLS |

### Network

| Variable | Default | Description |
|---|---|---|
| `jumpserver_http_port` | `80` | HTTP port |
| `jumpserver_https_enabled` | `false` | Enable HTTPS |
| `jumpserver_https_port` | `443` | HTTPS port (when enabled) |
| `jumpserver_ssh_port` | `2222` | SSH proxy port (KoKo) |
| `jumpserver_rdp_port` | `3389` | RDP proxy port (Lion) |

---

## Online vs Offline Install

### Online (default)

The role downloads the installer tarball directly from GitHub Releases:

```yaml
jumpserver_install_mode: online
jumpserver_version: "v4.10.16"
```

### Offline / Air-gapped

Download the tarball on a machine with internet access and copy it to the Ansible controller:

```bash
# On an internet-connected machine:
wget https://github.com/jumpserver/installer/releases/download/v4.10.16/jumpserver-installer-v4.10.16.tar.gz
```

Then set:

```yaml
jumpserver_install_mode: offline
jumpserver_offline_pkg_src: "/path/on/controller/jumpserver-installer-v4.10.16.tar.gz"
```

The role will `copy` the file to the target host automatically.

> **Architecture note:** The offline package only supports `linux/amd64` (x86_64). ARM64 is not currently supported via offline install.

---

## Secrets & Vault

Never commit plaintext passwords. Use [ansible-vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html):

```bash
# Encrypt
ansible-vault encrypt inventory/group_vars/vault.yml

# Edit in place
ansible-vault edit inventory/group_vars/vault.yml

# Run playbook
ansible-playbook site.yml --ask-vault-pass

# Or store the vault password in a file (add to .gitignore)
echo "my-vault-password" > .vault-pass
ansible-playbook site.yml --vault-password-file .vault-pass
```

Add to `.gitignore`:

```
.vault-pass
*.retry
```

---

## Ports Reference

Open the following ports on your firewall:

| Port | Protocol | Purpose | Required |
|------|----------|---------|----------|
| 80   | TCP      | Web UI (HTTP) | Yes |
| 443  | TCP      | Web UI (HTTPS) | If HTTPS enabled |
| 2222 | TCP      | SSH asset proxy (KoKo) | Yes |
| 3389 | TCP      | RDP asset proxy (Lion) | If RDP used |

Internal ports (not exposed to users, managed by Docker):

| Port | Service |
|------|---------|
| 5432 | PostgreSQL |
| 6379 | Redis |

---

## Idempotency

The role is safe to run multiple times:

- Tarball extraction is guarded by a `stat` check on the installer directory
- `docker_compose_v2` with `state: present` only acts when the desired state differs
- Seeded `config_init` files use `force: false`, so post-install customisations are kept
- Config changes trigger the `restart jumpserver` handler automatically
- All package installs use `state: present`

---

<div align="center">

Built with [Ansible](https://www.ansible.com) · Powered by [JumpServer](https://www.jumpserver.com) · Docs: [docs.jumpserver.org](https://docs.jumpserver.org)

</div>
