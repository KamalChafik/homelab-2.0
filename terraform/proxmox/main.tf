locals {
  base_user_data = templatefile("${path.module}/cloud-init/base-user-data.yaml.tpl", {
    kamal_ssh_keys  = var.kamal_ssh_keys
    ansible_ssh_key = var.ansible_ssh_key
  })
}

resource "proxmox_virtual_environment_file" "base_user_data" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore
  node_name    = var.proxmox_node_name

  source_raw {
    file_name = "base-user-data.yaml"
    data      = local.base_user_data
  }
}

resource "proxmox_virtual_environment_vm" "vms" {
  for_each = var.vms

  name      = each.value.name
  node_name = var.proxmox_node_name
  vm_id     = each.value.vm_id

  clone {
    vm_id = var.vm_template_id
    full  = true
  }

  cpu {
    cores = each.value.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory_max
    floating  = each.value.memory_min
  }

  disk {
    datastore_id = each.value.datastore_id
    interface    = "scsi0"
    size         = each.value.disk_size
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge = var.vm_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id      = each.value.datastore_id
    user_data_file_id = proxmox_virtual_environment_file.base_user_data.id

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