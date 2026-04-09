# 🏠 Homelab 2.0

A fully automated, infrastructure-as-code homelab built on **Proxmox**, provisioned with **Terraform**, configured with **Ansible**, and managed through **Portainer** — with GitOps-driven deployments, secure remote access via Tailscale, and a growing stack of self-hosted services.

---

## 📐 Architecture Overview

```
┌────────────────────────────────────────────────────────────────────┐
│                          Physical Hardware                         │
│                                                                    │
│  ┌───────────────────┐          ┌─────────────────────────────┐   │
│  │  TrueNAS (NFS)    │◄────────►│   Proxmox Hypervisor        │   │
│  │  Storage Server   │  NFS     │   (VM host)                 │   │
│  └───────────────────┘          └─────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
                                          │
             ┌────────────────────────────┼────────────────────────┐
             ▼                            ▼                        ▼
      ┌─────────────┐            ┌──────────────┐        ┌──────────────────┐
      │  VM: infra  │            │  VM: rdbms   │        │   VM: network    │
      │             │            │              │        │                  │
      │  Portainer  │            │  PostgreSQL  │        │ Tailscale        │
      │  Semaphore  │            │  pgAdmin     │        │ Pi-hole (DNS)    │
      │  TFC Agent  │            └──────────────┘        │ Traefik          │
      │  GH Runner  │                                    └──────────────────┘
      └─────────────┘
```

---

## ⚙️ Automation Pipeline

Every VM is provisioned and configured through a fully automated pipeline — no manual SSH, no clicking in UIs.

```
  HCP Terraform Cloud
        │
        │  plan + apply  (via self-hosted TFC Agent)
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
            Ansible  (triggered via Semaphore)
                    │
                    └─ Deploys Portainer Agent on every VM
                              │
                              ▼
                      sync_portainer.py
                              │
                              └─ Registers each VM as a
                                 Portainer environment (via API)
                                          │
                                          ▼
                                  Portainer  (central hub)
                                          │
                                          └─ Manages Docker
                                             stacks via GitOps
```

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| **Hypervisor** | [Proxmox VE](https://www.proxmox.com/) |
| **Storage** | [TrueNAS](https://www.truenas.com/) (NFS) |
| **Infrastructure as Code** | [Terraform](https://www.terraform.io/) + [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox) provider |
| **Terraform State & CI** | [HCP Terraform Cloud](https://app.terraform.io/) |
| **VM Provisioning** | [cloud-init](https://cloud-init.io/) (templates rendered by Terraform) |
| **Configuration Management** | [Ansible](https://www.ansible.com/) + `community.docker` collection |
| **Automation UI** | [Semaphore](https://www.semaphoreui.com/) (Ansible / Terraform runs) |
| **Container Management** | [Portainer](https://www.portainer.io/) (central hub + per-VM agents) |
| **Remote Access** | [Tailscale](https://tailscale.com/) (on `network` VM, routes DNS through Pi-hole) |
| **Database** | [PostgreSQL 17](https://www.postgresql.org/) + [pgAdmin 4](https://www.pgadmin.org/) |
| **DNS / Ad-blocking** | [Pi-hole](https://pi-hole.net/) (internal DNS + ad-blocker) |
| **Reverse Proxy** | [Traefik v3](https://traefik.io/) (HTTPS via Cloudflare DNS challenge) |
| **SSO / Identity** | [Authentik](https://goauthentik.io/) 🔜 |
| **Dependency Updates** | [Dependabot](https://docs.github.com/en/code-security/dependabot) (Docker images + GitHub Actions) |

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
│   ├── terraform-agent/                   # Self-hosted HCP Terraform Cloud agent
│   ├── traefik/                           # Traefik reverse proxy (Cloudflare DNS challenge)
│   └── pihole/                            # Pi-hole DNS + ad-blocker
│
├── scripts/
│   ├── sync_portainer.py                  # Registers VM IPs as Portainer environments via API
│   └── terraform-agent-start.sh           # Bootstraps SSH agent before starting TFC agent
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

| Service | Purpose |
|---|---|
| Portainer | Central Docker management UI, aggregates all VM environments |
| Semaphore | Web UI for running Ansible playbooks and Terraform plans |
| TFC Agent | Self-hosted Terraform Cloud agent (runs plans inside the homelab) |
| GitHub Runner | Self-hosted GitHub Actions runner |
| Authentik | SSO + identity provider 🔜 |

---

### VM 2 — `rdbms`
> Database layer

| Service | Purpose |
|---|---|
| PostgreSQL 17 | Primary relational database |
| pgAdmin 4 | Web-based PostgreSQL management |
| MySQL | Secondary database engine 🔜 |

---

### VM 3 — `network`
> Networking, DNS, and secure remote access

| Service | Purpose |
|---|---|
| Tailscale | Secure remote access (VPN mesh); configured to route DNS through Pi-hole |
| Pi-hole | Network-wide DNS resolver and ad-blocker; serves internal `.home` / local DNS records |
| Traefik | Reverse proxy with automatic HTTPS via Cloudflare DNS challenge |

---

### VM 4 — `home-automation` _(planned)_
| Service | Purpose |
|---|---|
| Home Assistant | Smart home automation and integrations |

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
| Dev tools | Various self-hosted developer utilities |

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
- [x] TrueNAS storage server setup
- [x] Proxmox hypervisor setup
- [x] Base VM template (cloud-init, SSH hardening, Docker-ready, QEMU agent)
- [x] Terraform provisioning pipeline (HCP Terraform Cloud + self-hosted agent)
- [x] Automated cloud-init injection via Terraform templates
- [x] Ansible playbook for Portainer Agent deployment
- [x] `sync_portainer.py` — auto-registers VMs as Portainer environments
- [x] `infra` VM deployed (Portainer, Semaphore, TFC Agent)
- [x] `rdbms` VM deployed (PostgreSQL, pgAdmin)
- [x] `network` VM deployed (Tailscale, Pi-hole, Traefik)
- [x] Pi-hole internal DNS — local records served to all VMs
- [x] Tailscale on `network` VM — remote access with DNS routed through Pi-hole
- [x] Traefik reverse proxy — HTTPS for all services via Cloudflare DNS challenge
- [x] Dependabot configured for daily Docker image + GitHub Actions updates

### 🚧 In Progress
- [ ] Authentik SSO (unified login across all services)

### 🔜 Next Up
- [ ] `home-automation` VM — Home Assistant
- [ ] `media` VM — Arr stack
- [ ] `tools` VM — Homepage, Vaultwarden, SearXNG, ntfy
- [ ] `monitoring` VM — Prometheus, Grafana, Loki, Uptime Kuma
- [ ] `ai` VM — Ollama + Open WebUI

---

## 🚀 Getting Started

### Prerequisites

- Proxmox VE node with a cloud-init-ready VM template
- TrueNAS (or any NFS server) for VM storage
- [HCP Terraform Cloud](https://app.terraform.io/) account with a workspace named `homelab-proxmox-prod`
- SSH key pair for the `ansible` automation user

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
PORTAINER_URL=https://portainer.your-domain \
PORTAINER_API_KEY=your-api-key \
python3 scripts/sync_portainer.py /tmp/portainer_hosts.json
```

All VMs will now appear as environments in your Portainer instance. Deploy Docker stacks directly from the UI or via GitOps.

---

## 📜 License

[MIT](LICENSE)
