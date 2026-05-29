output "opnsense_vm_id" {
  description = "VM ID de la VM OPNsense"
  value       = proxmox_virtual_environment_vm.opnsense.vm_id
}

output "cloudflared_ip" {
  description = "IP de la VM cloudflared (DMZ)"
  value       = module.vm_cloudflared.ipv4_address
}

output "reverse_proxy_ip" {
  description = "IP de la VM reverse-proxy (DMZ)"
  value       = module.vm_reverse_proxy.ipv4_address
}

output "ceph_bond_nodes" {
  description = "Nœuds avec bond LACP Ceph configuré"
  value       = keys(local.ceph_osd_nodes)
}

output "proxmox_cluster_nodes" {
  description = "Nœuds disponibles dans le cluster Proxmox"
  value       = data.proxmox_virtual_environment_nodes.available.names
}
