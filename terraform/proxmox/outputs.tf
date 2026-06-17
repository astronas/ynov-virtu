output "vms" {
  description = "VMs déployées (clé logique → vmid / nœud / IP cible)"
  value = {
    for k, m in module.vm : k => {
      vm_id        = m.vm_id
      name         = m.name
      node_name    = m.node_name
      ipv4_address = m.ipv4_address
    }
  }
}

output "ceph_bond_nodes" {
  description = "Nœuds avec bond LACP Ceph configuré"
  value       = keys(local.ceph_osd_nodes)
}
