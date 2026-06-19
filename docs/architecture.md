# Architecture — Vue d'ensemble

## Présentation générale

Le lab YNOV-VIRTU est une infrastructure de virtualisation d'entreprise miniaturisée, construite autour de trois couches :

1. **Couche réseau** — Switch Arista 7050TX-64 <img src="assets/logos/arista.png" class="inline-logo" alt=""> (`YNOV-SW-LAB`), segmentation VLAN, LACP pour Ceph <img src="assets/logos/ceph.svg" class="inline-logo" alt="">.
2. **Couche compute** — Cluster Proxmox <img src="assets/logos/proxmox.png" class="inline-logo" alt=""> 3 nœuds (PRX1, PRX2, PRX3), hyperviseur KVM/LXC.
3. **Couche service** — OPNsense <img src="assets/logos/opnsense.svg" class="inline-logo" alt=""> (routage/firewall), Ceph <img src="assets/logos/ceph.svg" class="inline-logo" alt=""> (stockage distribué), Windows NAT (WAN temporaire).

---

## Topologie physique

```mermaid
graph TD
    classDef internet  fill:#37474f,stroke:#263238,color:#fff
    classDef win       fill:#2d6a4f,stroke:#1b4332,color:#fff
    classDef switch    fill:#c0392b,stroke:#922b21,color:#fff
    classDef proxmox   fill:#1565c0,stroke:#0d47a1,color:#fff
    classDef quorum    fill:#1976d2,stroke:#1565c0,color:#fff,stroke-dasharray:4 3
    classDef opnsense  fill:#e65c00,stroke:#bf360c,color:#fff
    classDef ceph      fill:#6a1b9a,stroke:#4a148c,color:#fff
    classDef admin     fill:#4a4a4a,stroke:#222,color:#fff

    INET["🌐 Internet\n(4G/5G Wi-Fi)"]:::internet
    WIN["💻 PC Windows\nNAT Wi-Fi → Eth\n10.0.99.1/24"]:::win
    SW["🔀 YNOV-SW-LAB\nArista 7050TX-64\n10.0.10.253"]:::switch

    INET -->|Wi-Fi| WIN
    WIN -->|Et1 — VLAN 99| SW

    SW -->|Et2 trunk\n10/20/30/99\nnatif 10| PRX1
    SW -->|Et3 trunk\n10/20/30/99\nnatif 10| PRX2
    SW -->|Et4 trunk\n10/20/30/99\nnatif 10| PRX3

    SW -->|Et5 — VLAN 10| PCADM["🖥 PC Admin\nVLAN MGMT"]:::admin
    SW -->|Et7 — VLAN 10| PCADM2["🖥 PC Admin 2\nVLAN MGMT"]:::admin

    SW -->|Po1 — LACP 2×10G\nEt49/1+49/2\nVLAN 101+102| C1["PRX1 bond0\nCeph public+private"]:::ceph
    SW -->|Et6 — VLAN 101| C2["PRX2 nic2\nCeph public"]:::ceph
    SW -->|Po2 — LACP 2×10G\nEt49/3+49/4\nVLAN 101+102| C3["PRX3 bond0\nCeph public+private"]:::ceph

    subgraph CLUSTER["☁️ Proxmox Cluster — YNOV-CLUSTER"]
        PRX1["🖥 PRX1\n10.0.10.1\nOSD · MON · MGR"]:::proxmox
        PRX2["🖥 PRX2\n10.0.10.2\nMON · MGR quorum"]:::quorum
        PRX3["🖥 PRX3\n10.0.10.3\nOSD · MON"]:::proxmox
        OPN["🛡 OPNsense VM\nWAN 10.0.99.254\nLAN 10.0.10.254\nDMZ 10.0.20.254\nSRV 10.0.30.254"]:::opnsense
        PRX3 --- OPN
    end

    C1 --- PRX1
    C2 --- PRX2
    C3 --- PRX3
```

### Schéma de brassage

![Schéma de brassage](assets/skema.png)

---

## Composants et rôles

### <img src="assets/logos/arista.png" class="inline-logo" alt=""> Switch Arista 7050TX-64

![Arista 7050TX-64](assets/arista-7050tx-64.png){ style="height:220px;width:auto" }

Le switch est le cœur L2 du lab. Il assure :

- La segmentation VLAN (10, 20, 30, 99, 101, 102, 4094).
- Les trunks vers les trois nœuds Proxmox (VLANs 10/20/30/99, natif 10).
- L'agrégation LACP pour les réseaux Ceph de PRX1 (Po1) et PRX3 (Po2).
- L'accès WAN du PC Windows (Et1, VLAN 99).
- La connectivité Ceph public de PRX2 (Et6, VLAN 101).
- La sécurisation des ports inutilisés (shutdown + VLAN 4094).

### <img src="assets/logos/proxmox.png" class="inline-logo" alt=""> PRX1

- **Rôle Proxmox** : nœud de compute, héberge des VMs de workload.
- **Rôle Ceph** : OSD (stockage de données), MON/MGR possible.
- **Réseaux** : MGMT/DMZ/SRV/WAN via trunk `Et2`, Ceph public+private via `Po1` (LACP 2×10G, Et49/1+49/2).

### <img src="assets/logos/proxmox.png" class="inline-logo" alt=""> PRX2

- **Rôle Proxmox** : nœud de compute, héberge des VMs de workload.
- **Rôle Ceph** : quorum/management (MON, MGR), **pas d'OSD**. Pas de réseau Ceph private.
- **Réseaux** : MGMT/DMZ/SRV/WAN via trunk `Et3`, Ceph public uniquement via `Et6` (VLAN 101, SFP→RJ45).

### <img src="assets/logos/proxmox.png" class="inline-logo" alt=""> PRX3

- **Rôle Proxmox** : nœud de compute, héberge la VM OPNsense.
- **Rôle Ceph** : OSD (stockage de données), MON/MGR possible.
- **Réseaux** : MGMT/DMZ/SRV/WAN via trunk `Et4`, Ceph public+private via `Po2` (LACP 2×10G, Et49/3+49/4).

### <img src="assets/logos/opnsense.svg" class="inline-logo" alt=""> OPNsense

VM hébergée sur PRX3. Sert de passerelle et pare-feu pour l'ensemble du lab :

- **WAN** : `10.0.99.254/24` — récupère Internet depuis le PC Windows via NAT.
- **LAN/MGMT** : `10.0.10.254/24` — gateway du VLAN management.
- **DMZ** : `10.0.20.254/24` — gateway de la zone DMZ.
- **SRV/LAN** : `10.0.30.254/24` — gateway des services internes.

### 💻 PC Windows

Passerelle WAN temporaire. Partage une connexion Wi-Fi (4G/5G ou autre) vers le VLAN 99 via NAT PowerShell. Connecté au switch via `Et1` (VLAN 99 access).

---

## Couche workload (VMs)

Au-dessus de l'underlay physique, les VMs métier sont déployées en IaC (OpenTofu + cloud-init + Ansible) :

| VM | Rôle | VLAN | IP |
|----|------|------|----|
| **bastion** | JumpServer (PAM) + outils d'admin | 20 — DMZ | `10.0.20.1` |
| **web** | Frontal nginx + php-fpm | 30 — SRV-LAN | `10.0.30.4` |
| **db** | Base de données MariaDB | 30 — SRV-LAN | `10.0.30.5` |
| **zabbix** | Supervision (serveur + web + MariaDB) | 30 — SRV-LAN | `10.0.30.6` |

> Détails du provisionnement : [OpenTofu & cloud-init](opentofu.md) · [Configuration Ansible](ansible.md)

---

## Décisions d'architecture

### Pourquoi OPNsense sur PRX3 et non une appliance dédiée ?

L'objectif est de maximiser l'usage du matériel disponible. PRX3 porte les OSD Ceph et OPNsense simultanément. En production, OPNsense serait idéalement sur du matériel dédié ou avec des ressources CPU/RAM réservées.

### Pourquoi VLAN natif 10 sur les trunks Proxmox ?

Le management Proxmox (interface web, SSH, corosync) doit rester accessible sans tag VLAN. En plaçant le VLAN 10 comme natif sur les trunks `Et2/Et3/Et4`, le trafic non tagué est automatiquement dans le VLAN MGMT. Cela simplifie le boot et l'accès initial.

### Pourquoi LACP pour <img src="assets/logos/ceph.svg" class="inline-logo" alt=""> Ceph ?

Ceph génère un trafic réseau intense lors des opérations de réplication (réseau private VLAN 102) et d'accès client (réseau public VLAN 101). Le LACP 2×10G offre à la fois la redondance et l'augmentation de bande passante effective pour PRX1 et PRX3.

### Pourquoi PRX2 sans réseau Ceph private ?

PRX2 ne porte pas d'OSD. Il ne participe pas à la réplication inter-OSD. Son rôle Ceph (MON, MGR) ne nécessite que le réseau public. Le réseau private est exclusivement utilisé pour la réplication entre OSD (PRX1 ↔ PRX3).

### Pourquoi VLAN 4094 comme blackhole ?

Le VLAN 1 est le VLAN natif par défaut sur Arista. Pour éviter les attaques de VLAN hopping (double-tagging sur VLAN 1), tous les ports inutilisés sont placés dans un VLAN inexistant (4094) et mis en shutdown. Les trunks Ceph utilisent aussi 4094 comme VLAN natif.

---

## Flux de données principaux

### Accès Internet depuis une VM interne (VLAN 30)

```mermaid
sequenceDiagram
    participant VM as 🖥 VM<br/>10.0.30.x
    participant OPN_SRV as 🛡 OPNsense SRV<br/>10.0.30.254
    participant OPN_WAN as 🛡 OPNsense WAN<br/>10.0.99.254
    participant WIN as 💻 PC Windows<br/>10.0.99.1
    participant INET as 🌐 Internet

    VM->>OPN_SRV: requête (VLAN 30)
    OPN_SRV->>OPN_WAN: routage inter-VLAN
    OPN_WAN->>WIN: VLAN 99 — NAT
    WIN->>INET: Wi-Fi (4G/5G)
    INET-->>WIN: réponse
    WIN-->>OPN_WAN: NAT retour
    OPN_WAN-->>VM: retour routé
```

### Réplication Ceph (inter-OSD)

```mermaid
graph LR
    classDef ceph fill:#6a1b9a,stroke:#4a148c,color:#fff
    classDef sw   fill:#c0392b,stroke:#922b21,color:#fff

    PRX1["🖥 PRX1\nbond0.102\n10.0.102.1"]:::ceph
    SW["🔀 Switch\nPo1 + Po2\nVLAN 102"]:::sw
    PRX3["🖥 PRX3\nbond0.102\n10.0.102.3"]:::ceph

    PRX1 <-->|LACP 2×10G| SW
    SW <-->|LACP 2×10G| PRX3
```

### Accès client Ceph (VLAN 101)

```mermaid
graph LR
    classDef ceph   fill:#6a1b9a,stroke:#4a148c,color:#fff
    classDef sw     fill:#c0392b,stroke:#922b21,color:#fff
    classDef client fill:#1565c0,stroke:#0d47a1,color:#fff

    PRX1C["PRX1\n10.0.101.1"]:::client
    PRX2C["PRX2\n10.0.101.2"]:::client
    PRX3C["PRX3\n10.0.101.3"]:::client
    SW["🔀 Switch\nVLAN 101"]:::sw
    CEPH["🗄 Ceph Cluster\n(MON / OSD)"]:::ceph

    PRX1C <--> SW
    PRX2C <--> SW
    PRX3C <--> SW
    SW <--> CEPH
```

---

## Configuration switch Arista (running-config)

Configuration complète exportée depuis le switch (`show running-config`) — **EOS 4.20.12M** :

```eos
! device: YNOV-SW-LAB (DCS-7050TX-64, EOS-4.20.12M)

hostname YNOV-SW-LAB
spanning-tree mode mstp
environment fan-speed override 30

! --- VLANs ---
vlan 10  → MGMT
vlan 20  → DMZ
vlan 30  → SRV-LAN
vlan 99  → WAN-FUTUR-OPNSENSE
vlan 101 → CEPH-PUBLIC
vlan 102 → CEPH-PRIVATE
vlan 4094 → BLACKHOLE-NATIVE

! --- Ports actifs ---
Et1  : access vlan 99          → PC Windows (NAT WAN vers OPNsense)
Et2  : trunk 10,20,30,99       → PRX1 (native vlan 10)
Et3  : trunk 10,20,30,99       → PRX2 (native vlan 10)
Et4  : trunk 10,20,30,99       → PRX3 / OPNsense (native vlan 10)
Et5  : access vlan 10          → PC Admin MGMT
Et6  : access vlan 101         → PRX2 Ceph public (NIC2 SFP-RJ45)
Et7  : access vlan 10          → PC Admin MGMT2

! --- LACP Ceph ---
Po1 (Et49/1+Et49/2) : trunk vlan 101-102, native 4094, mtu 9000 → PRX1 Ceph
Po2 (Et49/3+Et49/4) : trunk vlan 101-102, native 4094, mtu 9000 → PRX3 Ceph

! --- Sécurité ---
Et8-Et48, Et50-Et52 : shutdown, access vlan 4094 (blackhole)
interface Vlan1 : shutdown (neutralisation VLAN 1)

! --- Routage management ---
interface Vlan10 : ip address 10.0.10.253/24
ip route 0.0.0.0/0 10.0.10.254
ip routing
```

> Fichier complet : [`configs/arista/running-config-current.eos`](../configs/arista/running-config-current.eos)

![Table de routage Arista — ip route](assets/route.png)

---

## Voir aussi

- [docs/network-plan.md](network-plan.md) — Plan IP complet et rôles des ports switch
- [diagrams/architecture.mmd](../diagrams/architecture.mmd) — Schéma Mermaid
- [docs/proxmox.md](proxmox.md) — Configuration des nœuds
- [docs/ceph.md](ceph.md) — Déploiement du cluster Ceph
