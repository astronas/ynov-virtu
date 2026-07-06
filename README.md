<div align="center">

<img src="docs/assets/logo_ynov_campus_sophia.png" alt="Ynov Campus Sophia-Antipolis" height="72">

<h1>ynov-virtu</h1>

<p>
<strong>Lab d'infrastructure virtualisée orienté entreprise.</strong><br>
Cluster Proxmox VE haute disponibilité, stockage Ceph, segmentation réseau et pare-feu OPNsense,<br>
couche applicative déployée intégralement en Infrastructure as Code.
</p>

[![Documentation](https://github.com/astronas/ynov-virtu/actions/workflows/docs.yml/badge.svg)](https://astronas.github.io/ynov-virtu/)
[![OpenTofu validate](https://github.com/astronas/ynov-virtu/actions/workflows/opentofu-validate.yml/badge.svg)](https://github.com/astronas/ynov-virtu/actions/workflows/opentofu-validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<p>
<a href="https://astronas.github.io/ynov-virtu/"><strong>Documentation en ligne</strong></a> &nbsp;·&nbsp;
<a href="https://astronas.github.io/ynov-virtu/architecture/">Architecture</a> &nbsp;·&nbsp;
<a href="https://astronas.github.io/ynov-virtu/network-plan/">Plan réseau</a> &nbsp;·&nbsp;
<a href="https://astronas.github.io/ynov-virtu/opentofu/">Déploiement IaC</a>
</p>

</div>

---

## Aperçu

`ynov-virtu` reproduit une infrastructure d'entreprise de bout en bout, du câblage physique jusqu'aux applications, en séparant clairement deux couches :

- **Underlay physique** : cluster Proxmox VE à 3 nœuds, stockage distribué Ceph hyperconvergé, switch Arista 7050TX-64 et pare-feu OPNsense assurant le routage inter-VLAN.
- **Couche applicative** : bastion d'administration (PAM), serveurs web et base de données, supervision et IPAM/DCIM, provisionnés puis configurés sans aucune intervention manuelle.

Projet réalisé dans le cadre du module Virtualisation du M1 Expert Cloud, Sécurité & Infrastructure (Ynov Campus Sophia-Antipolis).

## Points clés

| Domaine | Mise en œuvre |
|---|---|
| **Virtualisation** | Cluster Proxmox VE 3 nœuds : quorum, stockage partagé, migration à chaud |
| **Stockage** | Ceph hyperconvergé (OSD / MON / MGR), réseaux public et privé dédiés en LACP |
| **Réseau** | 6 VLANs segmentés (802.1Q), agrégation LACP, VLAN blackhole pour les ports inutilisés |
| **Sécurité** | Pare-feu OPNsense (routage inter-VLAN, DMZ), bastion PAM JumpServer, secrets HashiCorp Vault |
| **Infrastructure as Code** | Provisioning OpenTofu, bootstrap cloud-init, configuration Ansible idempotente |
| **IPAM** | NetBox comme source de vérité, allocation d'IP dynamique pilotée par OpenTofu |
| **Observabilité** | Supervision Zabbix (serveur, agents, monitoring applicatif) |
| **CI/CD** | GitHub Actions : validation OpenTofu et documentation déployée à chaque push |

## Stack technique

<div align="center">
  <img src="docs/assets/logos/proxmox.png" height="46" alt="Proxmox VE">&nbsp;&nbsp;&nbsp;
  <img src="docs/assets/logos/opnsense.svg" height="46" alt="OPNsense">&nbsp;&nbsp;&nbsp;
  <img src="docs/assets/logos/ceph.svg" height="46" alt="Ceph">&nbsp;&nbsp;&nbsp;
  <img src="docs/assets/logos/arista.png" height="46" alt="Arista">&nbsp;&nbsp;&nbsp;
  <img src="docs/assets/logos/terraform.svg" height="46" alt="OpenTofu">&nbsp;&nbsp;&nbsp;
  <img src="docs/assets/logos/ansible.svg" height="46" alt="Ansible">&nbsp;&nbsp;&nbsp;
  <img src="docs/assets/logos/github.svg" height="46" alt="GitHub">
</div>

<p align="center">
Proxmox VE&nbsp;·&nbsp;Ceph&nbsp;·&nbsp;OPNsense&nbsp;·&nbsp;Arista EOS&nbsp;·&nbsp;OpenTofu&nbsp;·&nbsp;cloud-init&nbsp;·&nbsp;Ansible&nbsp;·&nbsp;NetBox&nbsp;·&nbsp;Zabbix&nbsp;·&nbsp;JumpServer&nbsp;·&nbsp;HashiCorp Vault&nbsp;·&nbsp;Docker&nbsp;·&nbsp;GitHub Actions
</p>

## Architecture

```mermaid
graph TD
    classDef windows  fill:#2d6a4f,stroke:#1b4332,color:#fff
    classDef switch   fill:#c0392b,stroke:#922b21,color:#fff
    classDef proxmox  fill:#1565c0,stroke:#0d47a1,color:#fff
    classDef quorum   fill:#1976d2,stroke:#1565c0,color:#fff,stroke-dasharray:4 3
    classDef opnsense fill:#e65c00,stroke:#bf360c,color:#fff
    classDef ceph     fill:#6a1b9a,stroke:#4a148c,color:#fff

    PC["PC Windows<br>10.0.99.1<br>NAT Wi-Fi vers Ethernet"]:::windows
    SW["Arista 7050TX-64<br>YNOV-SW-LAB<br>10.0.10.253"]:::switch

    PC -- "Et1 · VLAN 99" --> SW

    SW -- "Et2 trunk<br>VLAN 10/20/30/99" --> PRX1
    SW -- "Et3 trunk<br>VLAN 10/20/30/99" --> PRX2
    SW -- "Et4 trunk<br>VLAN 10/20/30/99" --> PRX3

    SW -- "Po1 LACP<br>VLAN 101+102" --> PRX1_CEPH["PRX1 bond0<br>Ceph 2x10G"]:::ceph
    SW -- "Et6 · VLAN 101" --> PRX2_CEPH["PRX2 nic2<br>Ceph public"]:::ceph
    SW -- "Po2 LACP<br>VLAN 101+102" --> PRX3_CEPH["PRX3 bond0<br>Ceph 2x10G"]:::ceph

    subgraph CLUSTER["Cluster Proxmox · YNOV-CLUSTER"]
        PRX1["PRX1 · 10.0.10.1<br>OSD + MON + MGR"]:::proxmox
        PRX2["PRX2 · 10.0.10.2<br>MON + MGR (quorum)"]:::quorum
        PRX3["PRX3 · 10.0.10.3<br>OSD + MON"]:::proxmox
        OPN["OPNsense (VM)<br>WAN 10.0.99.254<br>LAN 10.0.10.254"]:::opnsense
        PRX3 --> OPN
    end

    PRX1_CEPH --- PRX1
    PRX2_CEPH --- PRX2
    PRX3_CEPH --- PRX3
```

> Switch physique : **Arista 7050TX-64** (48x RJ45 10G + 4x QSFP+ 40G).
> Le détail des flux inter-VLAN et de la topologie Ceph est documenté dans [Architecture](https://astronas.github.io/ynov-virtu/architecture/) et [Plan réseau](https://astronas.github.io/ynov-virtu/network-plan/).

### Plan réseau

| VLAN | Rôle | Réseau |
|---|---|---|
| 10 | MGMT (management cluster) | `10.0.10.0/24` |
| 20 | DMZ (bastion, reverse-proxy) | `10.0.20.0/24` |
| 30 | SRV-LAN (web, db, supervision) | `10.0.30.0/24` |
| 99 | WAN (uplink OPNsense) | `10.0.99.0/24` |
| 101 / 102 | Ceph public / privé | `10.0.101.0/24`, `10.0.102.0/24` |
| 4094 | Blackhole (ports inutilisés) | (aucun) |

### Couche applicative

| VM | Rôle | VLAN | IP |
|---|---|---|---|
| **bastion** | JumpServer (PAM) et outils d'administration | DMZ | `10.0.20.1` |
| **web** | Frontal nginx + php-fpm | SRV-LAN | `10.0.30.4` |
| **db** | Base de données MariaDB | SRV-LAN | `10.0.30.5` |
| **zabbix** | Supervision | SRV-LAN | `10.0.30.6` |
| **netbox** | IPAM / DCIM | SRV-LAN | `10.0.30.7` |

## Déploiement

Trois étapes, entièrement automatisées :

```bash
# 1. Provisionner les VMs (clone du template cloud-init sur Proxmox)
cd opentofu
cp terraform.tfvars.example terraform.tfvars   # API Proxmox, nœud, template, réseau
tofu init && tofu apply

# 2. Installer les dépendances Ansible (collections + rôle externe)
cd ../ansible
ANSIBLE_CONFIG=./ansible.cfg ansible-galaxy collection install -r requirements.yml

# 3. Configurer les VMs (socle commun, rôles applicatifs, services)
ansible-playbook playbooks/roles.yml
```

Guides pas à pas : [OpenTofu et cloud-init](https://astronas.github.io/ynov-virtu/opentofu/) &nbsp;·&nbsp; [Ansible](https://astronas.github.io/ynov-virtu/ansible/).

> **Prérequis :** un template Proxmox Debian 12 compatible cloud-init et un token API Proxmox avec droits de clonage.

## Documentation

Toute la conception, les choix d'architecture et les procédures sont publiés sur le site de documentation, généré avec [Zensical](https://zensical.org) et déployé sur GitHub Pages :

**<https://astronas.github.io/ynov-virtu/>**

| Section | Contenu |
|---|---|
| [Architecture](https://astronas.github.io/ynov-virtu/architecture/) | Topologie physique, rôles des nœuds, choix de conception |
| [Plan réseau](https://astronas.github.io/ynov-virtu/network-plan/) | Plan d'adressage, VLANs, ports du switch |
| [Proxmox](https://astronas.github.io/ynov-virtu/proxmox/) · [Ceph](https://astronas.github.io/ynov-virtu/ceph/) | Cluster, bridges, interfaces, déploiement du stockage |
| [OPNsense](https://astronas.github.io/ynov-virtu/opnsense/) · [Vault](https://astronas.github.io/ynov-virtu/vault/) · [JumpServer](https://astronas.github.io/ynov-virtu/jumpserver/) | Pare-feu, secrets, bastion |
| [OpenTofu](https://astronas.github.io/ynov-virtu/opentofu/) · [Ansible](https://astronas.github.io/ynov-virtu/ansible/) · [NetBox](https://astronas.github.io/ynov-virtu/netbox/) | Provisioning, configuration, IPAM |
| [Supervision](https://astronas.github.io/ynov-virtu/supervision/) · [Sécurité](https://astronas.github.io/ynov-virtu/security/) · [Tests réseau](https://astronas.github.io/ynov-virtu/network-tests/) | Zabbix, politique de sécurité, matrice de validation |

## Structure du dépôt

<details>
<summary>Arborescence</summary>

```
ynov-virtu/
├── opentofu/          # Provisioning des VMs (OpenTofu + providers Proxmox / NetBox)
├── cloud-init/        # Bootstrap #cloud-config par VM (premier boot)
├── ansible/           # Configuration : socle commun, rôles applicatifs, services
├── configs/           # Configs de référence (Arista, Proxmox, OPNsense, Windows)
├── diagrams/          # Schémas Mermaid source (.mmd)
├── docs/              # Documentation (site Zensical / GitHub Pages)
├── overrides/         # Surcharges de thème Zensical
├── old/               # Ancienne IaC physique (référence)
├── .github/workflows/ # CI : validation OpenTofu, déploiement de la documentation
└── zensical.toml      # Configuration du site de documentation
```

</details>

## Équipe

Jonathan Panzer &nbsp;·&nbsp; Redouane Kachour &nbsp;·&nbsp; Thibaut Gianola &nbsp;·&nbsp; Sacha Veylon-Busser

## Licence

Distribué sous licence [MIT](LICENSE).
