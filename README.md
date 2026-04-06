## 🗺 Roadmap

This homelab is being built progressively. The goal is to establish a strong infrastructure foundation before layering services on top.

---

### 🧱 Base Infrastructure

- [x] TrueNAS server (storage)
- [x] Proxmox server (virtualization)
- [x] Create base VM template (cloud-init, SSH, Docker-ready)

---

### 🖥 Virtual Machines

All VMs are exported through terraform and ansible will deploy a portainer agent then a script will add them as environements to the main Portainer UI in infra, this helps keep one Portainer instance as a central hub and manage stacks easily through GitOps automations.

#### VM 1 — `infra`
Core control plane of the homelab.

- Portainer (main UI / central management)
- Semaphore (Ansible / Terraform automation)
- Scripts (automation, API sync)
- Self-hosted GitHub Runner
- 🔜 Authentik (SSO, identity provider)

---

#### VM 2 — `rdbms`
Database layer.

- PostgreSQL
- pgAdmin
- 🔜 MySQL

---

#### VM 3 — `network`
Networking and access layer.

- Twingate connector
- 🔜 Traefik (reverse proxy)
- 🔜 Pi-hole (DNS / ad-blocking)

---

#### VM 4 — `home-automation`
_Not yet deployed_

- Home Assistant

---

#### VM 5 — `media`
_Not yet deployed_

- Arr stack (Sonarr, Radarr, etc.)

---

#### VM 6 — `tools`
_Not yet deployed_

- Homepage dashboard
- Vaultwarden
- SearXNG
- Dev tools
- ntfy

---

#### VM 7 — `ai`
_Not yet deployed_

- Open WebUI
- Ollama

---

#### VM 8 — `monitoring`
_Not yet deployed_

- Grafana
- Prometheus
- Loki
- Uptime Kuma
- (future: alerting stack)

---

### 📍 Current State

- Infrastructure is deployed up to **VM 3**
- Twingate connector is operational
- Portainer and automation stack are in place

---

### 🔜 Next Steps

- Deploy **Authentik** (SSO + identity)
- Deploy **Traefik** (reverse proxy)
- Deploy **Pi-hole** (DNS + network control)

---

### 🧠 Notes

This roadmap is intentionally incremental:

- Build **core infrastructure first**
- Then add **networking and identity**
- Then deploy **services and applications**