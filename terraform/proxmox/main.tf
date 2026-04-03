resource "proxmox_virtual_environment_vm" "vms" {
  for_each = var.vms

  name      = each.value.name
  node_name = var.proxmox_node_name
  vm_id     = each.value.vm_id

  clone {
    vm_id = var.vm_template_id
  }

  cpu {
    cores = each.value.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.vm_datastore
    interface    = "scsi0"
    size         = each.value.disk_size
  }

  network_device {
    bridge = var.vm_bridge
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  operating_system {
    type = "l26"
  }

  started = true
}