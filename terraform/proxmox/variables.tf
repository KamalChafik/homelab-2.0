variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL, e.g. https://10.0.0.10:8006/api2/json"
}

variable "proxmox_api_token" {
  type        = string
  description = "Proxmox API token in the form user@realm!tokenid=secret"
  sensitive   = true
}

variable "proxmox_node_name" {
  type        = string
  description = "Default Proxmox node name"
}

variable "vm_template_id" {
  type        = number
  description = "Template VM ID used for cloning"
}

variable "vm_bridge" {
  type        = string
  description = "Default network bridge"
  default     = "vmbr0"
}

variable "vm_datastore" {
  type        = string
  description = "Default datastore for VM : asgard vmstore"
  default     = "vmstore"
}

variable "vms" {
  description = "Map of VMs to create"
  type = map(object({
    name      = string
    vm_id     = number
    cpu_cores = number
    memory    = number
    disk_size = number
  }))
}