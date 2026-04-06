output "portainer_hosts" {
  description = "Hosts to register in Portainer"
  value = {
    for name, vm in local.inventory_hosts :
    name => {
      ip = vm.ip
    }
  }
}