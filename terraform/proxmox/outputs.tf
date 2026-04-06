output "ansible_inventory" {
  description = "Generated Ansible inventory from Proxmox VMs"
  value = templatefile("${path.module}/inventory.tmpl", {
    vms = local.inventory_hosts
  })
}