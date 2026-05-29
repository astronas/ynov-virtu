output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  value = proxmox_virtual_environment_vm.this.name
}

output "ipv4_address" {
  value = var.ipv4_address
}

output "node_name" {
  value = proxmox_virtual_environment_vm.this.node_name
}
