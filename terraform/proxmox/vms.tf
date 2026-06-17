# ──────────────────────────────────────────────────────────────────────────────
# VMs du lab — telmate/proxmox provider (v3.0.x)
#
# Toutes les VMs sont déclarées dans la variable `vms` (voir env.*.tfvars) et
# déployées par clone d'un template via le module ./modules/vm.
#
#   terraform apply -var-file="env.prod.tfvars"
# ──────────────────────────────────────────────────────────────────────────────

module "vm" {
  source   = "./modules/vm"
  for_each = var.vms

  vm_id     = each.value.vm_id
  name      = each.value.name
  node_name = each.value.node

  clone_template = coalesce(each.value.template, var.default_template)
  datastore_id   = coalesce(each.value.datastore, var.datastore_local)

  cpu_cores = each.value.cpu_cores
  memory    = each.value.memory
  disk_size = "${each.value.disk_size}G"
  tags      = each.value.tags

  network_devices = [
    for n in each.value.networks : {
      bridge  = n.bridge
      model   = n.model
      vlan_id = n.vlan_id
    }
  ]

  ipv4_address = each.value.ipv4_address
  ipv4_gateway = each.value.ipv4_gateway

  # Cloud-init : valeurs par VM, sinon défauts globaux
  cloud_init_user     = each.value.ci_user != null ? each.value.ci_user : var.ci_default_user
  cloud_init_password = each.value.ci_password != null ? each.value.ci_password : var.ci_default_password
  ssh_public_key      = each.value.ssh_public_key != null ? each.value.ssh_public_key : var.ci_default_ssh_key
  nameserver          = var.ci_nameserver
}
