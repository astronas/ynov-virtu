# Sécurité réseau

## Principes généraux

Le lab applique une approche de **défense en profondeur** à plusieurs niveaux :

1. **Sécurisation L2** — Neutralisation du VLAN 1, isolation des ports inutilisés, VLAN blackhole.
2. **Segmentation VLAN** — Chaque zone réseau est isolée dans son propre VLAN.
3. **Filtrage inter-VLAN** — OPNsense contrôle tous les flux entre VLANs.

---

## <img src="assets/logos/arista.png" class="inline-logo" alt=""> Sécurisation du switch Arista

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

## <img src="assets/logos/opnsense.svg" class="inline-logo" alt=""> Sécurisation OPNsense

### Filtrage inter-VLAN

OPNsense est le seul point de routage entre les VLANs. Sans règle firewall, aucun trafic inter-VLAN n'est possible. La politique par défaut est **deny all** entre VLANs.

**Politique appliquée (Phase 2)** :

| Flux | Action | Justification |
|---|---|---|
| MGMT → tout | ✅ Autorisé | Les administrateurs ont accès à toute l'infrastructure |
| DMZ → MGMT | ❌ Bloqué | Un service compromis en DMZ ne doit pas atteindre le management |
| DMZ → SRV | ❌ Bloqué | La DMZ n'accède pas aux services internes directement |
| DMZ → Internet | ✅ TCP 80/443 uniquement | Les services DMZ ont besoin d'accès sortant |
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

## Évolutions futures envisagées

### Exposition de services via <img src="assets/logos/cloudflare.svg" class="inline-logo" alt=""> Cloudflare Tunnel

> **Idée d'évolution — non implémenté dans ce lab**

En cas de connexion derrière CG-NAT (4G/5G), il est impossible d'ouvrir des ports entrants. Cloudflare Tunnel permettrait d'exposer des services publics via une connexion sortante depuis la DMZ, sans port-forwarding et avec TLS automatique + protection DDoS.

---

## Sécurité des accès infrastructure

### <img src="assets/logos/proxmox.png" class="inline-logo" alt=""> Proxmox

- Désactiver l'accès root SSH sur les nœuds Proxmox en production (utiliser des utilisateurs PAM dédiés).
- Créer des utilisateurs Proxmox avec des rôles limités pour les accès non-admin.
- Activer la 2FA sur Proxmox VE.

### <img src="assets/logos/arista.png" class="inline-logo" alt=""> Switch Arista

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
