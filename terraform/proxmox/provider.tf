provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = true

  ssh {
    agent    = true
    username = var.proxmox_ssh_username

    node {
      name    = var.proxmox_node_name
      address = var.proxmox_node_address
    }
  }
}