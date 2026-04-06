terraform {
  required_version = ">= 1.6.0"

  cloud {
    organization = "kamal-homelab"

    workspaces {
      name = "homelab-proxmox-prod"
    }
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.100.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}