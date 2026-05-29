# YNOV-VIRTU — Lab d'infrastructure virtualisée entreprise

> **Proxmox 3 nœuds · OPNsense · Ceph · Arista 7050TX-64 · VLAN segmenté**

Ce dépôt documente un lab de virtualisation orienté entreprise monté sur trois serveurs Proxmox, un switch Arista et un pare-feu OPNsense. L'objectif est de produire une infrastructure reproductible, segmentée par VLAN, avec stockage distribué Ceph, routage inter-VLAN, zone DMZ et accès Internet temporaire via NAT Windows.

---

## Table des matières

- [Présentation](#présentation)
- [Matériel](#matériel)
- [VLANs & Plan IP](#vlans--plan-ip)
- [Architecture](#architecture)
- [Démarrage rapide](#démarrage-rapide)
- [Documentation](#documentation)
- [Configurations](#configurations)
- [Schémas](#schémas)
- [Scripts](#scripts)

---

## Présentation

Le lab repose sur trois serveurs **PRX1**, **PRX2** et **PRX3** interconnectés via le switch **YNOV-SW-LAB** (Arista 7050TX-64). Un pare-feu/routeur **OPNsense** tourne en VM sur PRX3 et assure le routage inter-VLAN et l'accès Internet. Le stockage distribué **Ceph** est réparti entre PRX1 (OSD), PRX3 (OSD) et PRX2 (quorum/management). Un PC Windows sert de passerelle WAN temporaire via NAT PowerShell.

### Objectifs

| Objectif | Statut |
|---|---|
| Cluster Proxmox 3 nœuds | ✅ |
| OPNsense VM sur PRX3 | ✅ |
| Segmentation VLAN (MGMT / DMZ / SRV / WAN) | ✅ |
| Routage inter-VLAN via OPNsense | ✅ |
| Zone DMZ (reverse proxy + Cloudflare Tunnel) | 🔧 En cours |
| Ceph PRX1+PRX3 OSD, PRX2 quorum | ✅ |
| NAT Windows temporaire | ✅ |
| Exposition via Cloudflare Tunnel (sans port-forwarding) | 📋 Planifié |

---

## Matériel

| Équipement | Rôle | Remarques |
|---|---|---|
| **Arista 7050TX-64** `YNOV-SW-LAB` | Cœur de réseau L2 | 64 ports SFP+ / RJ45 |
| **PRX1** | Nœud Proxmox, OSD Ceph | 2 liens SFP Ceph → breakout Et49/1+49/2 |
| **PRX2** | Nœud Proxmox, quorum Ceph | 1 lien principal RJ45 + 1 SFP→RJ45 Ceph public |
| **PRX3** | Nœud Proxmox, OSD Ceph, VM OPNsense | 2 liens SFP Ceph → breakout Et49/3+49/4 |
| **PC Windows** | Passerelle WAN temporaire | NAT PowerShell Wi-Fi → Ethernet |
| **Câble QSFP→4xSFP** | Breakout port 49 | PRX1 (49/1+49/2) et PRX3 (49/3+49/4) |
| **Module SFP→RJ45** | Ceph public PRX2 | Connecté à `Ethernet6` du switch |

---

## VLANs & Plan IP

| VLAN | Nom | Réseau | Rôle |
|---|---|---|---|
| **10** | MGMT | `10.0.10.0/24` | Management Proxmox, switch, OPNsense LAN |
| **20** | DMZ | `10.0.20.0/24` | Zone DMZ / reverse proxy |
| **30** | SRV-LAN | `10.0.30.0/24` | Réseau serveurs internes |
| **99** | WAN-OPNSENSE | `10.0.99.0/24` | WAN OPNsense via PC Windows NAT |
| **101** | CEPH-PUBLIC | `10.0.101.0/24` | Réseau public Ceph |
| **102** | CEPH-PRIVATE | `10.0.102.0/24` | Réplication/recovery Ceph |
| **4094** | BLACKHOLE | — | VLAN poubelle / native sécurisée |

### IPs clés

| Équipement | MGMT (VLAN 10) | Ceph public (101) | Ceph private (102) |
|---|---|---|---|
| PRX1 | `10.0.10.1` | `10.0.101.1` | `10.0.102.1` |
| PRX2 | `10.0.10.2` | `10.0.101.2` | — |
| PRX3 | `10.0.10.3` | `10.0.101.3` | `10.0.102.3` |
| Switch Arista | `10.0.10.253` | — | — |
| OPNsense LAN | `10.0.10.254` | — | — |
| OPNsense WAN | `10.0.99.2` | — | — |
| OPNsense DMZ | `10.0.20.254` | — | — |
| OPNsense SRV | `10.0.30.254` | — | — |
| PC Windows | `10.0.99.1` | — | — |

---

## Architecture

```
Internet (4G/5G)
      │
 [PC Windows Wi-Fi]  ──NAT PowerShell──►  Ethernet 10.0.99.1/24
                                                    │
                                          VLAN 99 – Et1 (Arista)
                                                    │
                                         OPNsense WAN (10.0.99.2)
                                                    │
                              ┌─────────────────────┤
                              │          OPNsense VM (PRX3)
                              │    LAN/MGMT · DMZ · SRV/LAN
                              │
                   [YNOV-SW-LAB – Arista 7050TX-64]
                    Et2        Et3        Et4
                 (trunk)    (trunk)    (trunk)
                    │          │          │
                  PRX1       PRX2       PRX3
               10.0.10.1  10.0.10.2  10.0.10.3
                    │                    │
                  Po1 (LACP)          Po2 (LACP)
               Et49/1+49/2          Et49/3+49/4
              VLAN 101+102          VLAN 101+102
                    └──── Ceph ──────────┘
                              │
                    PRX2 ← Et6 ← VLAN 101 (Ceph public uniquement)
```

> Schéma Mermaid complet : [diagrams/architecture.mmd](diagrams/architecture.mmd)

---

## Démarrage rapide

### 1. Switch Arista

Appliquer la configuration complète :

```bash
# Depuis le mode enable sur l'Arista
copy tftp://10.0.10.x/running-config-current.eos running-config
# ou coller bloc par bloc depuis configs/arista/running-config-current.eos
```

### 2. Proxmox — interfaces réseau

Copier l'exemple correspondant dans `/etc/network/interfaces` de chaque nœud :

```bash
# Sur PRX1
cp configs/proxmox/prx1-interfaces.example /etc/network/interfaces
ifreload -a
```

### 3. Cluster Proxmox

```bash
# Sur PRX1 (premier nœud)
pvecm create YNOV-CLUSTER

# Sur PRX2 et PRX3
pvecm add 10.0.10.1
```

### 4. OPNsense

Créer la VM sur PRX3 avec 4 interfaces réseau VirtIO raccordées à `vmbr0` avec les VLAN tags 99 (WAN), vide/10 (LAN), 20 (DMZ), 30 (SRV). Voir [docs/opnsense.md](docs/opnsense.md).

### 5. NAT Windows

```powershell
# Depuis PowerShell (Admin) sur le PC Windows
.\scripts\windows-nat-setup.ps1
```

### 6. Ceph

Initialiser Ceph sur les trois nœuds dans l'ordre PRX1 → PRX3 → PRX2. Voir [docs/ceph.md](docs/ceph.md).

---

## Documentation

| Document | Description |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Vue d'ensemble, décisions d'architecture |
| [docs/network-plan.md](docs/network-plan.md) | Plan IP détaillé, VLANs, rôles des ports |
| [docs/proxmox.md](docs/proxmox.md) | Setup cluster, bridges, VLAN tags VMs |
| [docs/ceph.md](docs/ceph.md) | Déploiement Ceph, rôles, commandes |
| [docs/opnsense.md](docs/opnsense.md) | VM OPNsense, interfaces, firewall, règles |
| [docs/windows-nat.md](docs/windows-nat.md) | NAT PowerShell, configuration IP Windows |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Problèmes rencontrés et résolutions |
| [docs/security.md](docs/security.md) | Sécurité réseau, VLAN 1, Cloudflare Tunnel |

---

## Configurations

| Fichier | Description |
|---|---|
| [configs/arista/running-config-current.eos](configs/arista/running-config-current.eos) | Config EOS complète du switch |
| [configs/arista/cleanup-commands.eos](configs/arista/cleanup-commands.eos) | Commandes de remise à zéro |
| [configs/proxmox/prx1-interfaces.example](configs/proxmox/prx1-interfaces.example) | `/etc/network/interfaces` PRX1 |
| [configs/proxmox/prx2-interfaces.example](configs/proxmox/prx2-interfaces.example) | `/etc/network/interfaces` PRX2 |
| [configs/proxmox/prx3-interfaces.example](configs/proxmox/prx3-interfaces.example) | `/etc/network/interfaces` PRX3 |
| [configs/opnsense/interfaces.md](configs/opnsense/interfaces.md) | Interfaces OPNsense |
| [configs/opnsense/firewall-rules.md](configs/opnsense/firewall-rules.md) | Règles firewall initiales et durcies |
| [configs/opnsense/nat.md](configs/opnsense/nat.md) | Outbound NAT |
| [configs/windows/nat-powershell.ps1](configs/windows/nat-powershell.ps1) | Script NAT inline |

---

## Schémas

| Fichier | Description |
|---|---|
| [diagrams/architecture.mmd](diagrams/architecture.mmd) | Schéma global de l'infrastructure |
| [diagrams/vlan-flow.mmd](diagrams/vlan-flow.mmd) | Flux inter-VLAN via OPNsense |
| [diagrams/ceph-network.mmd](diagrams/ceph-network.mmd) | Topologie réseau Ceph |

---

## Scripts

| Fichier | Description |
|---|---|
| [scripts/windows-nat-setup.ps1](scripts/windows-nat-setup.ps1) | Mise en place du NAT Windows |
| [scripts/windows-nat-cleanup.ps1](scripts/windows-nat-cleanup.ps1) | Suppression du NAT Windows |
| [scripts/network-tests.md](scripts/network-tests.md) | Commandes de validation réseau |

---

## Licence

Usage interne / lab pédagogique — YNOV Campus.
