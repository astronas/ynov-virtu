# OPNsense — Configuration des interfaces

## Interfaces physiques (côté VM Proxmox)

| Interface VM | Driver | VLAN tag (Proxmox) | Interface OPNsense | Nom logique |
|---|---|---|---|---|
| `net0` | VirtIO (vtnet0) | `99` | `vtnet0` | WAN |
| `net1` | VirtIO (vtnet1) | *(vide — natif VLAN 10)* | `vtnet1` | LAN |
| `net2` | VirtIO (vtnet2) | `20` | `vtnet2` | DMZ |
| `net3` | VirtIO (vtnet3) | `30` | `vtnet3` | SRV |

## Adressage IP

| Interface OPNsense | Adresse IP | Masque | Gateway | Rôle |
|---|---|---|---|---|
| WAN (`vtnet0`) | `10.0.99.254` | `/24` | `10.0.99.1` | Accès Internet via PC Windows NAT |
| LAN (`vtnet1`) | `10.0.10.254` | `/24` | — | Management Proxmox + administration |
| DMZ (`vtnet2`) | `10.0.20.254` | `/24` | — | Zone démilitarisée |
| SRV (`vtnet3`) | `10.0.30.254` | `/24` | — | Services internes |

## Paramètres spécifiques WAN

L'interface WAN reçoit une IP **privée** (`10.0.99.x`). Il est obligatoire de désactiver les protections suivantes dans OPNsense pour que le trafic fonctionne :

- **Block private networks** : ❌ désactivé
- **Block bogon networks** : ❌ désactivé

Ces options se trouvent dans : `Interfaces → WAN → (bas de page)`

## Gateway

| Nom | Interface | IP | Surveillance |
|---|---|---|---|
| `GW_WAN` | WAN | `10.0.99.1` | `1.1.1.1` |

La gateway WAN pointe vers le PC Windows (`10.0.99.1`) qui fait le NAT vers Internet.

## Flux réseau par interface

```
vtnet0 (WAN, VLAN 99)
  └── Switch Et1 (access VLAN 99) → PC Windows (10.0.99.1) → NAT → Internet

vtnet1 (LAN, natif VLAN 10)
  └── Switch Et2/3/4 (trunk, native 10) → PRX1/PRX2/PRX3, PC Admin

vtnet2 (DMZ, VLAN 20)
  └── Switch Et2/3/4 (trunk, tagged 20) → VMs DMZ (reverse proxy, cloudflared)

vtnet3 (SRV, VLAN 30)
  └── Switch Et2/3/4 (trunk, tagged 30) → VMs services internes
```
