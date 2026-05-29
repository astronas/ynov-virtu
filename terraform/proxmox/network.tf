# ──────────────────────────────────────────────────────────────────────────────
# Réseau des nœuds Proxmox — bpg/proxmox provider
#
# Gère les bridges, bonds LACP et interfaces VLAN Ceph sur chaque nœud.
# Note : après apply, un `ifreload -a` ou reboot est nécessaire sur le nœud.
# ──────────────────────────────────────────────────────────────────────────────

# ── vmbr0 — Bridge principal VLAN-aware (PRX1, PRX2, PRX3) ───────────────────

resource "proxmox_virtual_environment_network_linux_bridge" "vmbr0" {
  for_each = var.proxmox_nodes

  node_name = each.value.name
  name      = "vmbr0"

  address = "${each.value.mgmt_ip}/24"
  gateway = "10.0.10.254"

  vlan_aware = true
  ports      = [each.value.main_iface]

  comment = "Bridge principal VLAN-aware — MGMT/DMZ/SRV/WAN (${each.value.name})"
}

# ── bond0 — Bond LACP Ceph (PRX1 et PRX3 uniquement) ─────────────────────────

resource "proxmox_virtual_environment_network_linux_bond" "ceph_bond" {
  for_each = local.ceph_osd_nodes

  node_name = each.value.name
  name      = "bond0"

  bond_primary = "enic1"
  ports        = ["enic1", "enic2"]

  mode             = "802.3ad"
  xmit_hash_policy = "layer3+4"
  mii_mon          = 100

  comment = "Bond LACP 2×10G Ceph — Po1/Po2 switch (${each.value.name})"
}

# ── bond0.101 — VLAN Ceph public (PRX1 et PRX3) ──────────────────────────────

resource "proxmox_virtual_environment_network_linux_vlan" "ceph_public" {
  for_each = local.ceph_osd_nodes

  node_name = each.value.name
  name      = "bond0.101"

  address = "${each.value.ceph_pub}/24"
  comment = "Ceph public VLAN 101 — ${each.value.ceph_pub} (${each.value.name})"

  depends_on = [proxmox_virtual_environment_network_linux_bond.ceph_bond]
}

# ── bond0.102 — VLAN Ceph private (PRX1 et PRX3) ─────────────────────────────

resource "proxmox_virtual_environment_network_linux_vlan" "ceph_private" {
  for_each = {
    for k, v in local.ceph_osd_nodes : k => v if v.ceph_priv != null
  }

  node_name = each.value.name
  name      = "bond0.102"

  address = "${each.value.ceph_priv}/24"
  comment = "Ceph private VLAN 102 — ${each.value.ceph_priv} (${each.value.name})"

  depends_on = [proxmox_virtual_environment_network_linux_bond.ceph_bond]
}

# ── nic2 — Interface Ceph public PRX2 (SFP→RJ45, access VLAN 101) ────────────
# PRX2 n'a pas de bond — lien direct sur nic2, port access VLAN 101 côté switch.

resource "proxmox_virtual_environment_network_linux_bridge" "ceph_public_prx2" {
  node_name = "prx2"
  name      = "vmbr1"

  address = "${var.proxmox_nodes["prx2"].ceph_pub}/24"
  ports   = ["nic2"]

  comment = "Bridge Ceph public PRX2 — VLAN 101 via SFP→RJ45 (Et6 switch)"

  depends_on = [proxmox_virtual_environment_network_linux_bridge.vmbr0["prx2"]]
}
