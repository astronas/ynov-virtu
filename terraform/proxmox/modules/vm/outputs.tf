output "vm_id" {
  value = proxmox_vm_qemu.this.vmid
}

output "name" {
  value = proxmox_vm_qemu.this.name
}

output "ipv4_address" {
  value = var.ipv4_address
}

output "node_name" {
  value = proxmox_vm_qemu.this.target_node
}
