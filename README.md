<div align="center">
  <img src="docs/assets/ynov-campus.svg" alt="YNOV Campus Sophia-Antipolis" height="72">
</div>

# ynov-virtu

> **Cours de Virtualisation** — M1 Expert Cloud, Sécurité & Infrastructure  
> YNOV Campus Sophia-Antipolis

Lab orienté entreprise basé sur **Proxmox VE**, **OPNsense**, **Ceph** et un switch **Arista 7050TX-64**.  
Le repo couvre toute la stack : documentation, configs réseau, Infrastructure as Code (Terraform + Ansible) et GitHub Pages.

**Équipe :** Jonathan Panzer · Redouane Kachour · Thibaut Gianola · Sacha Veylon-Busser

<div align="center">
  <img src="docs/assets/logos/proxmox.png" height="48" alt="Proxmox VE">&nbsp;&nbsp;
  <img src="docs/assets/logos/opnsense.png" height="48" alt="OPNsense">&nbsp;&nbsp;
  <img src="docs/assets/logos/ceph.png" height="48" alt="Ceph">&nbsp;&nbsp;
  <img src="docs/assets/logos/arista.png" height="48" alt="Arista">&nbsp;&nbsp;
  <img src="docs/assets/logos/cloudflare.svg" height="48" alt="Cloudflare">&nbsp;&nbsp;
  <img src="docs/assets/logos/terraform.svg" height="48" alt="Terraform">&nbsp;&nbsp;
  <img src="docs/assets/logos/ansible.png" height="48" alt="Ansible">&nbsp;&nbsp;
  <img src="docs/assets/logos/github.svg" height="48" alt="GitHub">
</div>

---

## Architecture

> **Switch physique** — Arista 7050TX-64 (48× RJ45 10G + 4× QSFP+ 40G SFP)
>
> ![Arista 7050TX-64](docs/assets/arista-7050tx-64.png)

```mermaid
graph TD
    classDef windows  fill:#2d6a4f,stroke:#1b4332,color:#fff
    classDef switch   fill:#c0392b,stroke:#922b21,color:#fff
    classDef proxmox  fill:#1565c0,stroke:#0d47a1,color:#fff
    classDef quorum   fill:#1976d2,stroke:#1565c0,color:#fff,stroke-dasharray:4 3
    classDef opnsense fill:#e65c00,stroke:#bf360c,color:#fff
    classDef ceph     fill:#6a1b9a,stroke:#4a148c,color:#fff

    PC["💻 PC Windows\n10.0.99.1\nNAT Wi-Fi → Ethernet"]:::windows
    SW["🔀 Arista 7050TX-64\nYNOV-SW-LAB\n10.0.10.253"]:::switch

    PC -- "Et1 VLAN 99" --> SW

    SW -- "Et2 trunk\nVLAN 10/20/30/99" --> PRX1
    SW -- "Et3 trunk\nVLAN 10/20/30/99" --> PRX2
    SW -- "Et4 trunk\nVLAN 10/20/30/99" --> PRX3

    SW -- "Po1 LACP\nVLAN 101+102" --> PRX1_CEPH["PRX1 bond0\nCeph 2×10G"]:::ceph
    SW -- "Et6 VLAN 101" --> PRX2_CEPH["PRX2 nic2\nCeph public"]:::ceph
    SW -- "Po2 LACP\nVLAN 101+102" --> PRX3_CEPH["PRX3 bond0\nCeph 2×10G"]:::ceph

    subgraph CLUSTER["Proxmox Cluster — YNOV-CLUSTER"]
        PRX1["🖥 PRX1\n10.0.10.1\nOSD + MON + MGR"]:::proxmox
        PRX2["🖥 PRX2\n10.0.10.2\nMON + MGR (quorum)"]:::quorum
        PRX3["🖥 PRX3\n10.0.10.3\nOSD + MON"]:::proxmox
        OPN["🛡 OPNsense VM\nWAN 10.0.99.254\nLAN 10.0.10.254"]:::opnsense
        PRX3 --> OPN
    end

    PRX1_CEPH --- PRX1
    PRX2_CEPH --- PRX2
    PRX3_CEPH --- PRX3
```

### Flux VLAN

```mermaid
graph LR
    classDef vlan_mgmt fill:#1565c0,stroke:#0d47a1,color:#fff
    classDef vlan_dmz  fill:#00838f,stroke:#006064,color:#fff
    classDef vlan_srv  fill:#2e7d32,stroke:#1b5e20,color:#fff
    classDef vlan_wan  fill:#6d4c41,stroke:#4e342e,color:#fff
    classDef vlan_ceph fill:#6a1b9a,stroke:#4a148c,color:#fff
    classDef opnsense  fill:#e65c00,stroke:#bf360c,color:#fff

    subgraph VLANs
        V10["VLAN 10\nMGMT\n10.0.10.0/24"]:::vlan_mgmt
        V20["VLAN 20\nDMZ\n10.0.20.0/24"]:::vlan_dmz
        V30["VLAN 30\nSRV-LAN\n10.0.30.0/24"]:::vlan_srv
        V99["VLAN 99\nWAN\n10.0.99.0/24"]:::vlan_wan
        V101["VLAN 101\nCEPH-PUBLIC\n10.0.101.0/24"]:::vlan_ceph
        V102["VLAN 102\nCEPH-PRIVATE\n10.0.102.0/24"]:::vlan_ceph
    end

    OPN["OPNsense\n10.0.10.254"]:::opnsense -- "inter-VLAN routing" --> V10
    OPN -- "firewall → DMZ" --> V20
    OPN -- "firewall → SRV" --> V30
    V99 -- "WAN upstream" --> OPN
    V101 -- "réplication OSD" --> V102
```

### Réseau Ceph

```mermaid
graph TD
    classDef bond   fill:#4a148c,stroke:#311b92,color:#fff
    classDef pub    fill:#0277bd,stroke:#01579b,color:#fff
    classDef priv   fill:#1b5e20,stroke:#004d40,color:#fff
    classDef direct fill:#e65c00,stroke:#bf360c,color:#fff

    subgraph PRX1["PRX1 — OSD + MON + MGR"]
        B1["bond0\nenic1 + enic2\nLACP 802.3ad"]:::bond
        P101A["bond0.101\n10.0.101.1/24"]:::pub
        P102A["bond0.102\n10.0.102.1/24"]:::priv
        B1 --> P101A
        B1 --> P102A
    end

    subgraph PRX2["PRX2 — MON + MGR (quorum only)"]
        N2["nic2 direct\nSFP→RJ45\n10.0.101.2/24"]:::direct
    end

    subgraph PRX3["PRX3 — OSD + MON"]
        B3["bond0\nenic1 + enic2\nLACP 802.3ad"]:::bond
        P101C["bond0.101\n10.0.101.3/24"]:::pub
        P102C["bond0.102\n10.0.102.3/24"]:::priv
        B3 --> P101C
        B3 --> P102C
    end

    P101A -- "VLAN 101 public" --> N2
    P101A -- "VLAN 101 public" --> P101C
    P102A -- "VLAN 102 private\n(PRX2 exclu)" --> P102C
```

## Plan réseau

| VLAN | Nom | Réseau | Rôle |
|------|-----|--------|------|
| 10 | MGMT | 10.0.10.0/24 | Management cluster (PRX1=.1, PRX2=.2, PRX3=.3, SW=.253, OPNsense=.254) |
| 20 | DMZ | 10.0.20.0/24 | cloudflared=.5, reverse-proxy=.10 |
| 30 | SRV-LAN | 10.0.30.0/24 | VMs serveurs internes |
| 99 | WAN-OPNSENSE | 10.0.99.0/24 | PC Windows=.1, OPNsense WAN=.2 |
| 101 | CEPH-PUBLIC | 10.0.101.0/24 | PRX1=.1, PRX2=.2, PRX3=.3 |
| 102 | CEPH-PRIVATE | 10.0.102.0/24 | PRX1=.1, PRX3=.3 (PRX2 sans private) |
| 4094 | BLACKHOLE | — | VLAN natif des ports inutilisés + trunks Ceph |

---

## Quickstart

```bash
# 1. Cloner le repo
git clone https://github.com/<org>/ynov-virtu && cd ynov-virtu

# 2. Installer les collections Ansible
ansible-galaxy collection install -r ansible/requirements.yml

# 3. Initialiser Terraform
cd terraform/proxmox
cp terraform.tfvars.example terraform.tfvars  # remplir les variables
terraform init && terraform plan

# 4. Déployer le switch Arista
ansible-playbook ansible/playbooks/arista-network.yml

# 5. Configurer les nœuds Proxmox + Ceph
ansible-playbook ansible/playbooks/site.yml --tags proxmox,ceph
```

---

## Structure du repo

```
ynov-virtu/
│
├── docs/                          # Documentation (GitHub Pages via MkDocs)
│   ├── architecture.md            # Topologie, rôles, choix d'architecture
│   ├── network-plan.md            # Plan IP, VLANs, ports switch
│   ├── proxmox.md                 # Installation et configuration cluster Proxmox
│   ├── ceph.md                    # Déploiement Ceph (OSD, MON, MGR, pools)
│   ├── opnsense.md                # VM OPNsense — interfaces, firewall, NAT
│   ├── windows-nat.md             # Passerelle NAT Windows Wi-Fi→Ethernet
│   ├── security.md                # Politique de sécurité réseau
│   └── troubleshooting.md         # Problèmes rencontrés et résolutions
│
├── configs/
│   ├── arista/
│   │   ├── running-config-current.eos   # Config complète YNOV-SW-LAB
│   │   └── cleanup-commands.eos         # Commandes de reset
│   ├── proxmox/
│   │   ├── prx1-interfaces.example      # /etc/network/interfaces PRX1
│   │   ├── prx2-interfaces.example      # /etc/network/interfaces PRX2
│   │   └── prx3-interfaces.example      # /etc/network/interfaces PRX3
│   ├── opnsense/
│   │   ├── interfaces.md
│   │   ├── firewall-rules.md
│   │   └── nat.md
│   └── windows/
│       └── nat-powershell.ps1
│
├── terraform/
│   └── proxmox/                   # Provider bpg/proxmox ~0.66
│       ├── providers.tf
│       ├── variables.tf
│       ├── main.tf
│       ├── network.tf             # Bridges, bonds, VLANs par nœud
│       ├── vms.tf                 # OPNsense, cloudflared, reverse-proxy
│       ├── outputs.tf
│       ├── terraform.tfvars.example
│       └── modules/vm/            # Module réutilisable (cloud-init)
│
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml           # arista.eos, community.general, ansible.windows
│   ├── inventory/
│   │   ├── hosts.yml              # PRX1/2/3, switch Arista, PC Windows
│   │   └── group_vars/
│   │       ├── all.yml            # VLANs, DNS, NTP globaux
│   │       ├── proxmox.yml        # Cluster, Ceph, packages
│   │       └── arista.yml         # VLANs, trunks, ports, Port-Channels
│   ├── playbooks/
│   │   ├── site.yml               # Master playbook (import de tous les autres)
│   │   ├── arista-network.yml     # Switch : VLANs, trunks, LACP, STP
│   │   ├── proxmox-base.yml       # Packages, NTP, repo no-subscription
│   │   ├── proxmox-cluster.yml    # pvecm create + jointure
│   │   ├── ceph.yml               # pveceph init, MON/MGR/OSD, pool
│   │   ├── opnsense-api.yml       # API REST OPNsense
│   │   └── windows-nat.yml        # WinRM + NAT idempotent
│   └── roles/
│       ├── proxmox_base/          # tasks, handlers, templates/chrony.conf.j2
│       ├── proxmox_network/       # tasks, handlers, templates/interfaces.j2
│       ├── ceph/                  # Health checks post-déploiement
│       └── arista_switch/         # Role modulaire Arista EOS
│
├── diagrams/
│   ├── architecture.mmd           # Topologie générale (Mermaid)
│   ├── vlan-flow.mmd              # Flux inter-VLAN
│   └── ceph-network.mmd          # Réseau Ceph (public/private)
│
├── scripts/
│   ├── windows-nat-setup.ps1      # Setup NAT Windows (admin requis)
│   ├── windows-nat-cleanup.ps1    # Suppression NAT
│   └── network-tests.md           # Matrice de validation réseau
│
├── .github/workflows/
│   ├── docs.yml                   # GitHub Pages (MkDocs Material)
│   └── terraform-validate.yml     # CI : fmt + init + validate
│
└── mkdocs.yml                     # Config site de documentation
```

---

## IaC — Terraform

Gère le cycle de vie des ressources Proxmox via le provider [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox/latest).

- **network.tf** : bridges VLAN-aware, bonds LACP, sous-interfaces Ceph par nœud
- **vms.tf** : VM OPNsense (vm_id=100), cloudflared (101), reverse-proxy (102)
- **modules/vm** : module cloud-init réutilisable (réseau, user, SSH key)

```bash
cd terraform/proxmox
cp terraform.tfvars.example terraform.tfvars
# Remplir proxmox_password, vm_ssh_public_key, etc.
terraform init
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
```

## IaC — Ansible

Gère la configuration des équipements via les collections officielles.

| Collection | Usage |
|------------|-------|
| `arista.eos` ≥6.0.0 | Switch : VLANs, trunks, LACP, STP |
| `community.general` ≥9.0.0 | Proxmox : timezone, packages |
| `ansible.windows` ≥2.0.0 | PC Windows : WinRM, NAT PowerShell |

```bash
# Installer les dépendances
ansible-galaxy collection install -r ansible/requirements.yml

# Tout déployer
ansible-playbook ansible/playbooks/site.yml

# Seulement le switch
ansible-playbook ansible/playbooks/arista-network.yml

# Seulement Ceph
ansible-playbook ansible/playbooks/ceph.yml

# Dry-run
ansible-playbook ansible/playbooks/site.yml --check
```

---

## Documentation en ligne

La documentation est disponible via GitHub Pages (MkDocs Material).  
Déployée automatiquement à chaque push sur `main` via `.github/workflows/docs.yml`.

---

## Licence

MIT
