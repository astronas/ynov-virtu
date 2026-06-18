# ── Nœuds Proxmox (data sources) ─────────────────────────────────────────────

locals {
  cluster_nodes = toset(["prx1", "prx2", "prx3"])

  # VLAN IDs du lab
  vlan_mgmt        = 10
  vlan_dmz         = 20
  vlan_srv         = 30
  vlan_wan         = 99
  vlan_ceph_pub    = 101
  vlan_ceph_priv   = 102
  vlan_blackhole   = 4094

  # Nœuds portant des OSD Ceph (réseau private requis)
  ceph_osd_nodes = {
    for k, v in var.proxmox_nodes : k => v if v.ceph_osd
  }

  # Nœuds sans OSD (PRX2 — quorum uniquement)
  ceph_mon_only_nodes = {
    for k, v in var.proxmox_nodes : k => v if !v.ceph_osd
  }
}
