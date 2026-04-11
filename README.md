# 🏠 Homelab 2.0

[![Infrastructure: Terraform](https://img.shields.io/badge/Infrastructure-Terraform-7B42BC?logo=terraform&logoColor=white)](https://developer.hashicorp.com/terraform)
[![Configuration: Ansible](https://img.shields.io/badge/Configuration-Ansible-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Orchestration: Portainer](https://img.shields.io/badge/Orchestration-Portainer-13BEF9?logo=portainer&logoColor=white)](https://www.portainer.io/)
[![Identity: Authentik](https://img.shields.io/badge/Identity-Authentik-FD4B2D?logo=authentik&logoColor=white)](https://goauthentik.io/)
[![Proxy: Traefik](https://img.shields.io/badge/Proxy-Traefik_v3-24A1C1?logo=traefikproxy&logoColor=white)](https://traefik.io/)
[![VPN: Tailscale](https://img.shields.io/badge/VPN-Tailscale-246FDB?logo=tailscale&logoColor=white)](https://tailscale.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> A production-grade, fully automated homelab running on **Proxmox**, built entirely with Infrastructure-as-Code — provisioned by **Terraform**, configured by **Ansible**, orchestrated by **Portainer**, secured by **Tailscale + Authentik**, and exposed through **Traefik** with automatic TLS via **Cloudflare DNS challenge**.
>
> Every VM is reproducible, every secret is injected at runtime, and every deployment is GitOps-driven — no snowflakes, no manual SSH sessions.

---

## 📐 Architecture Overview

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                            PHYSICAL INFRASTRUCTURE                          ║
║                                                                              ║
║   ┌─────────────────────────────┐       ┌──────────────────────────────┐   ║
║   │        PC — TrueNAS         │       │     Mini-PC — Proxmox VE     │   ║
║   │                             │       │                              │   ║
║   │  ┌─────────────────────┐   │ NFS   │  ┌────────┐  ┌──────────┐  │   ║
║   │  │  NFS Shares         │◄──┼───────┼─►│ VM:    │  │ VM:      │  │   ║
║   │  │  /mnt/apps/*        │   │       │  │ infra  │  │ rdbms    │  │   ║
║   │  └─────────────────────┘   │       │  └────────┘  └──────────┘  │   ║
║   │  ┌─────────────────────┐   │       │                              │   ║
║   │  │  SMB Shares         │   │       │  ┌────────────────────────┐ │   ║
║   │  │  (home network)     │   │       │  │ VM: network            │ │   ║
║   │  └─────────────────────┘   │       │  └────────────────────────┘ │   ║
║   └─────────────────────────────┘       └──────────────────────────────┘   ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### VM Layout

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │  VM: infra                      VM: rdbms                            │
  │  ─────────────────────          ──────────────                       │
  │  • Portainer (hub) ✅ SSO       • PostgreSQL 17                      │
  │  • Semaphore (GitOps UI)        • pgAdmin 4      ✅ SSO              │
  │  • TFC Agent (Terraform)                                             │
  │  • GitHub Runner                VM: network                          │
  │  • Authentik (SSO/IdP) ✅       ──────────────                       │
  │                                 • Pi-hole (DNS + ad-block)           │
  │  VM: proxmox (hypervisor)       • Traefik (reverse proxy) ✅ SSO    │
  │  ────────────────────────       • Tailscale (overlay VPN)            │
  │  • Proxmox VE ✅ SSO                                                 │
  └──────────────────────────────────────────────────────────────────────┘
```

---

## 🌐 Network Architecture

```
  ┌─────────────────────────────────────────────────────────────────┐
  │                       TAILSCALE OVERLAY                         │
  │                   (encrypted WireGuard mesh)                    │
  │                                                                 │
  │    [Laptop / Phone / Remote device]                             │
  │              │                                                  │
  │              │  100.x.x.x (Tailscale IP)                        │
  │              ▼                                                  │
  │    ┌─────────────────┐      DNS query (*.home.lan)              │
  │    │  Pi-hole         │◄────────────────────────────────────┐   │
  │    │  (DNS resolver) │                                      │   │
  │    │                 │  Custom DNS record:                   │   │
  │    │  service.home.lan──► 100.x.x.x (Traefik Tailscale IP)  │   │
  │    └────────┬────────┘                                      │   │
  │             │                                               │   │
  │             ▼                                               │   │
  │    ┌─────────────────┐                                      │   │
  │    │  Traefik v3     │  HTTPS (:443)                        │   │
  │    │  reverse proxy  │  TLS cert via Cloudflare DNS         │   │
  │    │                 │  challenge (Let's Encrypt)           │   │
  │    └────────┬────────┘                                      │   │
  │             │                                               │   │
  │     ┌───────┴───────┐                                       │   │
  │     ▼               ▼                                       │   │
  │  [Service A]   [Service B] ── Authentik ForwardAuth ────────┘   │
  │  portainer     semaphore       (SSO middleware)                 │
  │  .home.lan     .home.lan                                        │
  └─────────────────────────────────────────────────────────────────┘
```

### Why Tailscale over Twingate?

| | Twingate | Tailscale |
|---|---|---|
| **DNS integration** | Relies on external DNS; hard to integrate with Pi-hole | Native DNS override — Pi-hole can resolve `*.home.lan` directly to Tailscale IPs |
| **Protocol** | Proprietary | WireGuard (audited, open standard) |
| **Split DNS** | Requires extra steps | First-class feature |
| **MagicDNS** | ✗ | ✓ built-in |
| **Self-hosted option** | Connector model only | Headscale available |
| **Latency** | Higher (cloud relay) | Near-zero with direct WireGuard tunnels |

**Bottom line**: Tailscale's native DNS override capability is what makes the `service.home.lan → Pi-hole → Traefik` chain seamless — no manual DNS hacks, no cloud relay.

---

## 🔐 DNS Resolution Flow

```
  Client (on Tailscale)
        │
        │  DNS query: portainer.home.lan
        ▼
  Pi-hole  (Tailscale IP set as DNS server)
        │
        │  Custom record: *.home.lan → <Traefik Tailscale IP>
        ▼
  Traefik  (listens on :443 on Tailscale interface)
        │
        │  SNI routing by hostname
        │  TLS terminated (Let's Encrypt wildcard cert
        │  obtained via Cloudflare DNS-01 challenge —
        │  no port 80 exposure required)
        ▼
  Upstream container  (portainer:9000, semaphore:3000, etc.)
```

**Key design decisions:**
- **No ports exposed to the public internet** — Traefik is bound exclusively to the Tailscale interface
- **Wildcard TLS cert** (`*.home.lan`) obtained via Cloudflare DNS-01 — no HTTP challenge, no firewall holes
- **Pi-hole as the single DNS resolver** — ad-blocking, local overrides, and query logging in one place
- **Tailscale as the transport layer** — every device on the mesh gets a stable `100.x.x.x` IP, works across networks

---

## 🔑 Authentication & SSO

All services are protected by **Authentik** — a self-hosted Identity Provider (IdP) running on the `infra` VM. No service is exposed without authentication.

### SSO Architecture

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │                        AUTHENTIK IdP                                │
  │                    (authentik.home.lan)                             │
  │                                                                     │
  │   ┌─────────────────────────────────────────────────────────────┐  │
  │   │  Providers                  Outposts                        │  │
  │   │  ─────────────────────      ────────────────────────────    │  │
  │   │  • OAuth2 / OpenID          • Proxy Outpost                 │  │
  │   │    (Portainer, pgAdmin,       → Traefik ForwardAuth         │  │
  │   │     Proxmox)                  → Traefik Dashboard           │  │
  │   │  • LDAP Provider            • RADIUS (future)               │  │
  │   │    → TrueNAS (WIP)                                          │  │
  │   └─────────────────────────────────────────────────────────────┘  │
  └─────────────────────────────────────────────────────────────────────┘
               │                          │
    ┌──────────┴──────────┐    ┌──────────┴──────────────────────┐
    │  Native OIDC / OAuth │    │  Proxy Outpost (ForwardAuth)    │
    │  ─────────────────── │    │  ─────────────────────────────  │
    │  Portainer   ✅ Live  │    │  Traefik Dashboard  ✅ Live     │
    │  pgAdmin 4   ✅ Live  │    │  (any app without native SSO)  │
    │  Proxmox VE  ✅ Live  │    └─────────────────────────────── ┘
    └──────────────────────┘
```

### Integrated Services

| Service | Integration Method | Status | Notes |
|---|---|---|---|
| **Portainer** | OAuth2 / OpenID Connect | ✅ Live | Native OIDC; groups synced from Authentik |
| **pgAdmin 4** | OAuth2 | ✅ Live | OAuth2 redirect flow; role mapped from Authentik groups |
| **Proxmox VE** | OpenID Connect | ✅ Live | Realm configured on PVE side; Authentik as OIDC provider |
| **Traefik Dashboard** | Proxy Outpost + ForwardAuth | ✅ Live | No native SSO — Authentik proxy outpost in front of Traefik API |
| **TrueNAS** | LDAP | 🚧 In Progress | Authentik LDAP outpost → TrueNAS directory service |
| **Semaphore** | OIDC | 🔜 Planned | Native OIDC support |

### Authentication Flow

```
  Browser  →  service.home.lan
                    │
                    ▼
           ┌─────────────────┐
           │  Traefik v3     │
           │  (ForwardAuth   │
           │   middleware)   │
           └────────┬────────┘
                    │
          ┌─────────┴──────────────────────────────────┐
          │  Native OIDC app?           Proxy Outpost?  │
          ▼                             ▼               │
   Redirect to                  Authentik checks        │
   Authentik /authorize         session cookie          │
          │                             │               │
          │  OAuth2 code exchange       │  Valid?       │
          ▼                             ▼               │
   Service handles             Forward to upstream      │
   token locally               (transparent to user)   │
                                                        │
          └──────────── MFA enforced on all paths ──────┘
```

**Authentik** features in use:
- **OIDC / OAuth2 providers** — native SSO for Portainer, pgAdmin, Proxmox
- **Proxy Outpost** — ForwardAuth middleware for services without native SSO (Traefik dashboard)
- **LDAP Outpost** — directory service integration for TrueNAS *(in progress)*
- **MFA enforcement** — TOTP for all admin accounts
- **Application groups** — per-service access control via Authentik groups
- **Blueprints** — declarative provider/application configuration (version-controlled)

---

## ⚙️ Automation Pipeline

Every VM is provisioned and configured through a fully automated pipeline — no manual SSH, no clicking in UIs.

```
  GitHub  (this repo)
       │
       │  push / PR
       ▼
  HCP Terraform Cloud  (plan + apply)
       │
       │  via self-hosted TFC Agent (runs inside homelab)
       ▼
  Terraform  ──  bpg/proxmox provider
       │
       ├─ Renders cloud-init user-data templates
       ├─ Uploads snippets to Proxmox datastore
       ├─ Clones base VM template (cloud-init + Docker-ready)
       ├─ Configures CPU / RAM / Disk per VM
       ├─ Injects SSH keys  (kamal user + ansible user)
       └─ Outputs: VM IPs  →  Ansible inventory file
                   │
                   ▼
           Ansible  (triggered via Semaphore UI)
                   │
                   └─ Deploys Portainer Agent on every VM
                             │
                             ▼
                     sync_portainer.py
                             │
                             └─ Registers each VM as a
                                Portainer environment via API
                                         │
                                         ▼
                                 Portainer  (central hub)
                                         │
                                         └─ GitOps: pulls Docker
                                            stack definitions from
                                            this repo and deploys
```

---

## 💾 Storage Architecture

```
  ┌────────────────────────────────────────────────┐
  │                  TrueNAS (PC)                  │
  │                                                │
  │  ┌──────────────────┐  ┌──────────────────┐   │
  │  │   NFS Exports    │  │   SMB Shares     │   │
  │  │                  │  │                  │   │
  │  │  /mnt/apps/      │  │  Media/          │   │
  │  │  ├─ traefik/     │  │  Documents/      │   │
  │  │  ├─ authentik/   │  │  Backups/        │   │
  │  │  ├─ semaphore/   │  │  (home network)  │   │
  │  │  ├─ pihole/      │  └──────────────────┘   │
  │  │  └─ postgres/    │                          │
  │  └──────┬───────────┘                          │
  └─────────┼────────────────────────────────────-─┘
            │
            │  NFS mount  (over Tailscale / LAN)
            ▼
   Proxmox VMs  (/mnt/apps/*)
   All persistent app data lives on TrueNAS —
   VMs are stateless and fully reproducible
```

**Design principles:**
- **VMs are stateless** — all application data is NFS-mounted from TrueNAS; a VM can be destroyed and redeployed with zero data loss
- **SMB for humans** — Windows/macOS-friendly shares accessible from any device on Tailscale for home file sharing
- **NFS for machines** — low-overhead, POSIX-compatible mounts used by Docker volume binds inside VMs

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| **Hypervisor** | [Proxmox VE](https://www.proxmox.com/) |
| **Storage** | [TrueNAS](https://www.truenas.com/) — NFS (VM data) + SMB (home network) |
| **Infrastructure as Code** | [Terraform](https://www.terraform.io/) + [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox) provider |
| **Terraform State & CI** | [HCP Terraform Cloud](https://app.terraform.io/) (self-hosted agent) |
| **VM Provisioning** | [cloud-init](https://cloud-init.io/) — templates rendered by Terraform |
| **Configuration Management** | [Ansible](https://www.ansible.com/) + `community.docker` collection |
| **Automation UI** | [Semaphore](https://www.semaphoreui.com/) — Ansible & Terraform run history |
| **Container Management** | [Portainer](https://www.portainer.io/) — central hub + per-VM agents |
| **Overlay VPN** | [Tailscale](https://tailscale.com/) — WireGuard mesh, split DNS, MagicDNS |
| **DNS / Ad-blocking** | [Pi-hole](https://pi-hole.net/) — local resolver, ad-block, custom records |
| **Reverse Proxy + TLS** | [Traefik v3](https://traefik.io/) — automatic HTTPS via Cloudflare DNS-01 |
| **SSO / Identity Provider** | [Authentik](https://goauthentik.io/) — OIDC, OAuth2, ForwardAuth, LDAP, MFA |
| **Database** | [PostgreSQL 17](https://www.postgresql.org/) + [pgAdmin 4](https://www.pgadmin.org/) |
| **Secret Injection** | Environment variables via Portainer stacks (no secrets in Git) |
| **Dependency Updates** | [Dependabot](https://docs.github.com/en/code-security/dependabot) — daily Docker image + Actions pins |

---

## 📂 Repository Structure

```
homelab-2.0/
├── terraform/
│   └── proxmox/
│       ├── main.tf                        # VM definitions (clone, cpu, memory, disk, cloud-init)
│       ├── provider.tf                    # Proxmox provider + SSH agent config
│       ├── variables.tf                   # Input variables
│       ├── outputs.tf                     # VM IPs exported as Portainer hosts JSON
│       ├── versions.tf                    # HCP Terraform Cloud workspace + provider pins
│       ├── terraform.tfvars.example       # Example variable values
│       └── cloud-init/
│           └── base-user-data.yaml.tpl    # Cloud-init template (users, SSH keys, packages)
│
├── ansible/
│   ├── ansible.cfg                        # Ansible defaults
│   └── playbooks/
│       └── deploy-portainer-agent.yml     # Installs Portainer Agent on each VM
│
├── docker/
│   ├── portainer-agent/                   # Portainer Agent (deployed per-VM by Ansible)
│   ├── semaphore/                         # Semaphore automation UI
│   ├── postgres/                          # PostgreSQL + pgAdmin
│   ├── traefik/                           # Traefik v3 (Cloudflare DNS challenge)
│   ├── authentik/                         # Authentik SSO server + worker
│   ├── terraform-agent/                   # Self-hosted HCP Terraform Cloud agent
│   └── pihole/                            # Pi-hole DNS + ad-blocker
│
├── scripts/
│   ├── sync_portainer.py                  # Registers VM IPs as Portainer environments via API
│   └── terraform-agent-start.sh          # Bootstraps SSH agent before starting TFC agent
│
├── requirements.yml                       # Ansible Galaxy collections
└── .github/
    └── dependabot.yml                     # Auto-updates Docker images + GitHub Actions daily
```

---

## 🖥 Virtual Machines

All VMs are cloned from a single hardened base template (Debian, cloud-init, Docker pre-installed, QEMU Guest Agent enabled). Terraform handles the full lifecycle — from provisioning to outputting the Ansible inventory — so adding a new VM is a one-line change in `terraform.tfvars`.

### VM 1 — `infra`
> Core control plane of the homelab

| Service | Status | SSO | Purpose |
|---|---|---|---|
| Portainer | ✅ Live | ✅ OIDC | Central Docker management UI, aggregates all VM environments |
| Semaphore | ✅ Live | 🔜 Planned | Web UI for running Ansible playbooks and Terraform plans |
| TFC Agent | ✅ Live | N/A | Self-hosted Terraform Cloud agent (runs plans inside the homelab) |
| GitHub Runner | ✅ Live | N/A | Self-hosted GitHub Actions runner |
| Authentik | ✅ Live | N/A (IdP itself) | SSO + Identity Provider (OIDC, ForwardAuth, LDAP, MFA) |

---

### VM 2 — `rdbms`
> Database layer — persistent storage backend for all services

| Service | Status | SSO | Purpose |
|---|---|---|---|
| PostgreSQL 17 | ✅ Live | N/A | Primary relational database (shared by Authentik, Semaphore, etc.) |
| pgAdmin 4 | ✅ Live | ✅ OAuth2 | Web-based PostgreSQL management |

---

### VM 3 — `network`
> Networking, DNS, and HTTPS ingress

| Service | Status | SSO | Purpose |
|---|---|---|---|
| Pi-hole | ✅ Live | 🔜 Planned | Network-wide DNS resolver, ad-blocker, and custom local records |
| Traefik v3 | ✅ Live | ✅ Proxy Outpost | Reverse proxy with automatic TLS (Cloudflare DNS-01 challenge) |
| Tailscale | ✅ Live | N/A | WireGuard overlay mesh — all internal traffic stays encrypted |

---

### Proxmox VE (Hypervisor)

| Service | Status | SSO | Purpose |
|---|---|---|---|
| Proxmox VE | ✅ Live | ✅ OpenID Connect | Bare-metal hypervisor hosting all VMs |

---

### TrueNAS (Storage Server)

| Service | Status | SSO | Purpose |
|---|---|---|---|
| TrueNAS | ✅ Live | 🚧 LDAP (WIP) | NFS + SMB storage server; LDAP auth via Authentik in progress |

---

### VM 4 — `home-automation` _(planned)_
| Service | Purpose |
|---|---|
| Home Assistant | Smart home automation and device integrations |

---

### VM 5 — `media` _(planned)_
| Service | Purpose |
|---|---|
| Sonarr / Radarr / Prowlarr | Automated media management (Arr stack) |

---

### VM 6 — `tools` _(planned)_
| Service | Purpose |
|---|---|
| Homepage | Unified homelab dashboard |
| Vaultwarden | Self-hosted Bitwarden-compatible password manager |
| SearXNG | Privacy-respecting metasearch engine |
| ntfy | Push notification service |

---

### VM 7 — `ai` _(planned)_
| Service | Purpose |
|---|---|
| Ollama | Local LLM inference server |
| Open WebUI | Browser UI for interacting with local models |

---

### VM 8 — `monitoring` _(planned)_
| Service | Purpose |
|---|---|
| Prometheus | Metrics collection |
| Grafana | Dashboards and visualisation |
| Loki | Log aggregation |
| Uptime Kuma | Service availability monitoring |

---

## 🗺 Roadmap

### ✅ Done
- [x] TrueNAS storage server setup (NFS + SMB)
- [x] Proxmox hypervisor setup
- [x] Base VM template (cloud-init, SSH hardening, Docker-ready, QEMU agent)
- [x] Terraform provisioning pipeline (HCP Terraform Cloud + self-hosted agent)
- [x] Automated cloud-init injection via Terraform templates
- [x] Ansible playbook for Portainer Agent deployment
- [x] `sync_portainer.py` — auto-registers VMs as Portainer environments
- [x] `infra` VM deployed (Portainer, Semaphore, TFC Agent, GitHub Runner)
- [x] `rdbms` VM deployed (PostgreSQL 17, pgAdmin)
- [x] `network` VM deployed (Pi-hole, Traefik v3 with Cloudflare DNS challenge, Tailscale)
- [x] Authentik deployed — SSO Identity Provider live
- [x] Migrated from Twingate to Tailscale (split DNS + Pi-hole integration)
- [x] Dependabot configured for daily Docker image + GitHub Actions updates
- [x] **pgAdmin 4** — OAuth2 SSO via Authentik
- [x] **Proxmox VE** — OpenID Connect SSO via Authentik
- [x] **Portainer** — OpenID Connect SSO via Authentik
- [x] **Traefik Dashboard** — Proxy Outpost + ForwardAuth middleware via Authentik

### 🚧 In Progress
- [ ] **TrueNAS** — LDAP directory service integration via Authentik LDAP outpost
- [ ] Authentik Blueprints — version-control all provider/application configs declaratively

### 🔜 Next Up
- [ ] Semaphore — OIDC SSO via Authentik
- [ ] Pi-hole — SSO or basic auth via Authentik proxy outpost
- [ ] `home-automation` VM — Home Assistant
- [ ] `media` VM — Arr stack (Sonarr, Radarr, Prowlarr)
- [ ] `tools` VM — Homepage, Vaultwarden, SearXNG, ntfy
- [ ] `monitoring` VM — Prometheus, Grafana, Loki, Uptime Kuma
- [ ] `ai` VM — Ollama + Open WebUI
- [ ] Headscale — self-hosted Tailscale control plane

---

## 🚀 Getting Started

### Prerequisites

- Proxmox VE node with a cloud-init-ready VM template
- TrueNAS (or any NFS server) for VM persistent storage
- [HCP Terraform Cloud](https://app.terraform.io/) account with a workspace named `homelab-proxmox-prod`
- SSH key pair for the `ansible` automation user
- Tailscale account (or self-hosted Headscale)
- Cloudflare account with a domain (for Traefik DNS-01 TLS challenge)

### 1. Provision VMs with Terraform

```bash
cd terraform/proxmox
cp terraform.tfvars.example terraform.tfvars
# Fill in your values: Proxmox URL, API token, SSH keys, VM specs
terraform init
terraform apply
```

Terraform outputs a `portainer_hosts` JSON with the IPs of all provisioned VMs.

### 2. Install Ansible dependencies

```bash
ansible-galaxy install -r requirements.yml
```

### 3. Deploy Portainer Agent on all VMs

```bash
ansible-playbook -i <generated-inventory.yml> ansible/playbooks/deploy-portainer-agent.yml
```

### 4. Register VMs in Portainer

```bash
# Export Terraform output to JSON
terraform output -json portainer_hosts > /tmp/portainer_hosts.json

# Sync environments
PORTAINER_URL=https://portainer.home.lan \
PORTAINER_API_KEY=your-api-key \
python3 scripts/sync_portainer.py /tmp/portainer_hosts.json
```

All VMs will now appear as environments in your Portainer instance. Deploy Docker stacks directly from the UI or via GitOps.

### 5. Network access

All services are reachable exclusively over Tailscale — no public ports. Join the Tailscale network, set your Pi-hole Tailscale IP as your DNS server, and every `*.home.lan` address resolves through Traefik with a valid TLS certificate.

---

## 📜 License

[MIT](LICENSE)
