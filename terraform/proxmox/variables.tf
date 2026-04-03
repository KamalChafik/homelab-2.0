variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL"
}

variable "proxmox_api_token" {
  type        = string
  description = "Proxmox API token"
  sensitive   = true
}

variable "proxmox_node_name" {
  type        = string
  description = "Proxmox node name"
}

variable "vm_template_id" {
  type        = number
  description = "Cloud-init template VM ID"
}

variable "vm_bridge" {
  type        = string
  description = "Bridge for VM NICs"
  default     = "vmbr0"
}

variable "snippets_datastore" {
  type        = string
  description = "Datastore that supports snippets (default to nfs)"
  default     = "vmstore"
}

variable "kamal_ssh_keys" {
  type        = list(string)
  description = "Public SSH keys for kamal user"
}

variable "ansible_ssh_key" {
  type        = string
  description = "Public SSH key for ansible user"
}

variable "vms" {
  description = "Map of VMs to create"
  type = map(object({
    name         = string
    vm_id        = number
    cpu_cores    = number
    memory_max   = number
    memory_min   = number
    disk_size    = number
    datastore_id = string
  }))
}

variable "proxmox_node_address" {
  type        = string
  description = "SSH address of the Proxmox node"
}

variable "proxmox_ssh_username" {
  type        = string
  description = "SSH username for the Proxmox node"
  default     = "root"
}