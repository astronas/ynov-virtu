# Sécurité réseau

## Principes généraux

Le lab applique une approche de **défense en profondeur** à plusieurs niveaux :

1. **Sécurisation L2** — Neutralisation du VLAN 1, isolation des ports inutilisés, VLAN blackhole.
2. **Segmentation VLAN** — Chaque zone réseau est isolée dans son propre VLAN.
3. **Filtrage inter-VLAN** — OPNsense contrôle tous les flux entre VLANs.
4. **Exposition externe sécurisée** — Cloudflare Tunnel, pas de port-forwarding entrant.

---

## Sécurisation du switch Arista

### Neutralisation du VLAN 1

Le VLAN 1 est le VLAN par défaut sur la plupart des équipements réseau. Il est vecteur de plusieurs attaques L2 :

- **VLAN hopping** : en double-tagging un paquet avec VLAN 1 comme tag externe, un attaquant peut accéder à un VLAN normalement inaccessible.
- **Spanning Tree manipulation** : le VLAN 1 est souvent utilisé par les BPDUs STP.

**Mesures appliquées :**

```eos
! Désactivation de l'interface SVI VLAN 1
interface Vlan1
   shutdown

! Aucun port n'est en access VLAN 1
! Tous les trunks ont un native VLAN différent de 1 (VLAN 10 ou 4094)
```

### VLAN 4094 — Blackhole

Le VLAN 4094 est un VLAN de quarantaine qui n'est routé nulle part et n'est attribué à aucun équipement légitime.

**Usages :**

- **Ports inutilisés** : tous les ports `Et8-Et48` sont en access VLAN 4094 + shutdown.
- **Native VLAN des trunks Ceph** : Po1 et Po2 ont le native VLAN 4094. Tout trafic non tagué arrivant sur ces liens est isolé dans un VLAN mort.

```eos
! Ports inutilisés
interface Ethernet8-48
   switchport access vlan 4094
   shutdown

! Trunks Ceph — native VLAN blackhole
interface Port-Channel1
   switchport trunk native vlan 4094
interface Port-Channel2
   switchport trunk native vlan 4094
```

### Isolation des trunks

Les trunks MGMT/DMZ/SRV/WAN (`Et2/Et3/Et4`) n'autorisent que les VLANs explicitement listés :

```eos
switchport trunk allowed vlan 10,20,30,99
```

Tout autre VLAN (101, 102, 4094) est implicitement rejeté sur ces trunks. Un attaquant sur une VM Proxmox ne peut pas injecter de trafic Ceph (VLAN 101/102) via ces ports.

### Ports d'administration

Les ports admin (`Et5`, `Et7`) sont en **access VLAN 10** (MGMT). Ils ne peuvent pas accéder aux VLANs DMZ, SRV ou WAN directement — le trafic doit passer par OPNsense.

---

## Sécurisation OPNsense

### Filtrage inter-VLAN

OPNsense est le seul point de routage entre les VLANs. Sans règle firewall, aucun trafic inter-VLAN n'est possible. La politique par défaut est **deny all** entre VLANs.

**Politique appliquée (Phase 2)** :

| Flux | Action | Justification |
|---|---|---|
| MGMT → tout | ✅ Autorisé | Les administrateurs ont accès à toute l'infrastructure |
| DMZ → MGMT | ❌ Bloqué | Un service compromis en DMZ ne doit pas atteindre le management |
| DMZ → SRV | ❌ Bloqué | La DMZ n'accède pas aux services internes directement |
| DMZ → Internet | ✅ TCP 80/443 uniquement | cloudflared et reverse proxy ont besoin de sortir |
| SRV → MGMT | ❌ Bloqué | Les VMs de service n'administrent pas l'infrastructure |
| SRV → Internet | ✅ TCP 80/443 uniquement | Les services ont besoin de mises à jour et d'accès API |
| WAN entrant | ❌ Bloqué | Par défaut OPNsense — aucun service exposé directement |

### Anti-spoofing

OPNsense active par défaut le **Block private networks** et **Block bogon networks** sur les interfaces externes. Sur cette infrastructure, ces protections sont désactivées sur le WAN (car le WAN est une IP privée `10.0.99.x`). Elles sont en revanche actives sur les interfaces internes (LAN, DMZ, SRV).

### Administration OPNsense

- L'accès à l'interface web OPNsense (`https://10.0.10.254:443`) est limité au VLAN 10 (MGMT).
- SSH OPNsense activé uniquement pour les besoins de diagnostic, sur le VLAN MGMT.
- Changer le mot de passe `admin` par défaut immédiatement après installation.

---

## Exposition de services vers Internet

### Problème : CG-NAT opérateur mobile

Une connexion 4G/5G est souvent derrière un **CG-NAT** (Carrier Grade NAT). L'opérateur ne fournit pas d'IP publique fixe, et plusieurs abonnés partagent la même IP publique. Il est impossible d'ouvrir des ports entrants (80, 443) depuis Internet.

### Solution : Cloudflare Tunnel

Cloudflare Tunnel (`cloudflared`) initie une connexion **sortante** depuis la DMZ vers les serveurs Cloudflare. Cloudflare devient alors le point d'entrée public, sans nécessiter de port-forwarding.

```
Internet → [Cloudflare Edge]
              │ Tunnel chiffré (QUIC/HTTP2)
           [cloudflared VM — 10.0.20.5 — DMZ]
              │ Requête HTTP interne
           [Reverse proxy — 10.0.20.10 — DMZ]
              │
           [Application (VLAN SRV ou DMZ)]
```

**Avantages :**

- Aucun port ouvert entrant sur le firewall OPNsense.
- Compatible avec le CG-NAT opérateur.
- TLS géré par Cloudflare (certificat automatique).
- Protection DDoS incluse dans l'offre Cloudflare gratuite.
- Contrôle d'accès possible via Cloudflare Access.

**Configuration de base `cloudflared` (VM DMZ) :**

```bash
# Installation cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
  -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

# Authentification et création du tunnel
cloudflared tunnel login
cloudflared tunnel create ynov-lab

# Exemple de config ~/.cloudflared/config.yml
# tunnel: <UUID>
# credentials-file: /root/.cloudflared/<UUID>.json
# ingress:
#   - hostname: app.example.com
#     service: http://10.0.20.10:80
#   - service: http_status:404

# Installer comme service systemd
cloudflared service install
```

---

## Sécurité des accès infrastructure

### Proxmox

- Désactiver l'accès root SSH sur les nœuds Proxmox en production (utiliser des utilisateurs PAM dédiés).
- Créer des utilisateurs Proxmox avec des rôles limités pour les accès non-admin.
- Activer la 2FA sur Proxmox VE.

### Switch Arista

- Changer le mot de passe `admin` par défaut.
- Désactiver l'accès Telnet (uniquement SSH).
- Utiliser un timeout de session SSH court (`idle-timeout 30`).
- Désactiver la Management API si non utilisée, ou la restreindre à l'IP du poste admin.

### Mots de passe

- Ne jamais laisser les mots de passe par défaut (`admin`/`opnsense`, `root`/vide, etc.).
- Les mots de passe ne sont pas stockés dans ce dépôt Git — utiliser un gestionnaire de secrets.

---

## Voir aussi

- [configs/arista/running-config-current.eos](../configs/arista/running-config-current.eos) — Config switch sécurisée
- [configs/opnsense/firewall-rules.md](../configs/opnsense/firewall-rules.md) — Règles firewall Phase 2
- [docs/troubleshooting.md](troubleshooting.md) — Résolution de problèmes réseau
