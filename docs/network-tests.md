# Tests de validation réseau

Ce document liste les commandes de vérification à exécuter à chaque étape du déploiement pour valider la connectivité.

---

## 1. Validation du switch Arista

Depuis la console ou SSH du switch (`10.0.10.253`) :

```bash
# VLANs configurés
show vlan

# État de toutes les interfaces
show interfaces status

# Trunks et VLANs autorisés
show interfaces trunk

# Résumé des Port-Channels (LACP)
show port-channel summary

# Détail LACP sur Po1 (PRX1 Ceph)
show lacp 1 peer
show lacp 1 counters

# Détail LACP sur Po2 (PRX3 Ceph)
show lacp 2 peer
show lacp 2 counters

# Table MAC (vérifier que les équipements sont appris)
show mac address-table

# Connectivité switch → OPNsense (gateway)
ping 10.0.10.254

# Connectivité switch → PRX1/PRX2/PRX3
ping 10.0.10.1
ping 10.0.10.2
ping 10.0.10.3
```

---

## 2. Validation réseau Proxmox

Depuis le shell de chaque nœud (`ssh root@10.0.10.x`) :

```bash
# Vérifier les interfaces actives
ip addr show
ip link show

# Vérifier le bridge vmbr0
bridge vlan show

# Vérifier le bond LACP (PRX1 et PRX3 uniquement)
cat /proc/net/bonding/bond0
ip link show bond0
ip link show bond0.101
ip link show bond0.102

# Test ping inter-nœud (MGMT VLAN 10)
ping -c 4 10.0.10.1    # depuis PRX2 ou PRX3
ping -c 4 10.0.10.2    # depuis PRX1 ou PRX3
ping -c 4 10.0.10.3    # depuis PRX1 ou PRX2

# Test ping réseau Ceph public (VLAN 101)
ping -c 4 10.0.101.1
ping -c 4 10.0.101.2
ping -c 4 10.0.101.3

# Test ping réseau Ceph private (VLAN 102 - PRX1 et PRX3 uniquement)
ping -c 4 10.0.102.1   # depuis PRX3
ping -c 4 10.0.102.3   # depuis PRX1

# Test gateway OPNsense (routage inter-VLAN)
ping -c 4 10.0.10.254
```

---

## 3. Validation NAT Windows

Depuis PowerShell (Admin) sur le PC Windows :

```powershell
# Vérifier que le NAT est actif
Get-NetNat

# Vérifier le forwarding
Get-NetIPInterface | Where-Object { $_.Forwarding -eq "Enabled" } | Select-Object InterfaceAlias, Forwarding

# Vérifier la configuration IP de la carte Ethernet
Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4

# Pinger OPNsense WAN
ping 10.0.99.254

# Vérifier les routes
route print
```

---

## 4. Validation OPNsense

Depuis l'interface Web OPNsense (`https://10.0.10.254`) :

- **Interfaces → Overview** : vérifier que WAN, LAN, DMZ, SRV ont des IP correctes.
- **System → Gateways** : vérifier que `GW_WAN` (10.0.99.1) est `Online`.
- **Firewall → Log Files → Live View** : observer les flux en temps réel.

Depuis le shell OPNsense (SSH `root@10.0.10.254`) :

```bash
# Interfaces
ifconfig

# Table de routage
netstat -rn

# Ping gateway Windows
ping -c 4 10.0.99.1

# Ping Internet (via NAT Windows)
ping -c 4 1.1.1.1
ping -c 4 8.8.8.8

# Résolution DNS
host google.com

# Traceroute
traceroute 1.1.1.1

# Ping vers les VLANs internes
ping -c 4 10.0.10.1     # PRX1
ping -c 4 10.0.10.2     # PRX2
ping -c 4 10.0.10.3     # PRX3
ping -c 4 10.0.20.254   # OPNsense DMZ (lui-même)
ping -c 4 10.0.30.254   # OPNsense SRV (lui-même)
```

---

## 5. Validation routage inter-VLAN

Depuis un PC branché en VLAN 10 (Ex5 ou Et7), configuré en `10.0.10.x/24`, gateway `10.0.10.254` :

```bash
# Gateway MGMT
ping 10.0.10.254

# Routage vers DMZ
ping 10.0.20.254

# Routage vers SRV
ping 10.0.30.254

# Internet
ping 1.1.1.1
curl -s https://ifconfig.me
```

Depuis une VM sur VLAN 30 (SRV) :

```bash
# Gateway SRV
ping 10.0.30.254

# Routage vers MGMT
ping 10.0.10.254

# Internet
ping 1.1.1.1
```

---

## 6. Validation Ceph

Depuis le shell de PRX1 :

```bash
# Statut global
ceph status
ceph health detail

# OSD tree
ceph osd tree

# Quorum MON
ceph mon stat
ceph quorum_status --format json-pretty | python3 -m json.tool

# Pool status
ceph df
rados df

# Test de performance (écriture)
rados bench -p vm-pool 10 write --no-cleanup

# Test de performance (lecture séquentielle)
rados bench -p vm-pool 10 seq

# Test de performance (lecture aléatoire)
rados bench -p vm-pool 10 rand

# Nettoyage bench
rados -p vm-pool cleanup
```

---

## 7. Matrice de tests réseau

| Source | Destination | Attendu | Protocole | Commentaire |
|---|---|---|---|---|
| PC Admin (VLAN 10) | `10.0.10.254` (OPNsense LAN) | ✅ Reach | ICMP | Gateway MGMT |
| PC Admin (VLAN 10) | `10.0.20.254` (OPNsense DMZ) | ✅ Reach | ICMP | Routage inter-VLAN |
| PC Admin (VLAN 10) | `10.0.30.254` (OPNsense SRV) | ✅ Reach | ICMP | Routage inter-VLAN |
| PC Admin (VLAN 10) | `1.1.1.1` | ✅ Reach | ICMP | Internet via NAT |
| VM SRV (VLAN 30) | `10.0.30.254` | ✅ Reach | ICMP | Gateway SRV |
| VM SRV (VLAN 30) | `1.1.1.1` | ✅ Reach | ICMP | Internet via OPNsense + NAT |
| VM SRV (VLAN 30) | `10.0.10.1` (PRX1) | ❌ Bloqué (Phase 2) | ICMP | SRV → MGMT bloqué |
| VM DMZ (VLAN 20) | `10.0.10.1` | ❌ Bloqué (Phase 2) | ICMP | DMZ → MGMT bloqué |
| VM DMZ (VLAN 20) | `1.1.1.1` | ✅ Reach | ICMP | DMZ → Internet |
| OPNsense WAN | `10.0.99.1` (PC Win) | ✅ Reach | ICMP | Gateway WAN |
| OPNsense WAN | `1.1.1.1` | ✅ Reach | ICMP | Internet via NAT Windows |
| PRX1 | `10.0.101.2` (PRX2) | ✅ Reach | ICMP | Ceph public |
| PRX1 | `10.0.102.3` (PRX3) | ✅ Reach | ICMP | Ceph private |
| PRX2 | `10.0.102.1` (PRX1) | ❌ Pas d'interface | ICMP | PRX2 sans VLAN 102 |
