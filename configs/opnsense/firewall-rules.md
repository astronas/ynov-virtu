# OPNsense — Règles de firewall

## Phase 1 — Règles permissives (validation initiale)

Ces règles sont appliquées en premier pour valider la connectivité end-to-end. Elles autorisent tout trafic sur toutes les interfaces.

> **À remplacer par les règles Phase 2 une fois le lab validé.**

### Interface WAN

| # | Action | Proto | Source | Destination | Port | Description |
|---|---|---|---|---|---|---|
| 1 | Block | * | * | * | * | Règle implicite — bloquer entrant WAN (défaut OPNsense) |

> Ne jamais créer de règle Pass sur le WAN sauf pour des besoins explicites.

### Interface LAN (MGMT)

| # | Action | Proto | Source | Destination | Port | Description |
|---|---|---|---|---|---|---|
| 1 | Pass | * | LAN net | * | * | Tout autoriser depuis MGMT (phase 1) |

### Interface DMZ

| # | Action | Proto | Source | Destination | Port | Description |
|---|---|---|---|---|---|---|
| 1 | Pass | * | DMZ net | * | * | Tout autoriser depuis DMZ (phase 1) |

### Interface SRV

| # | Action | Proto | Source | Destination | Port | Description |
|---|---|---|---|---|---|---|
| 1 | Pass | * | SRV net | * | * | Tout autoriser depuis SRV (phase 1) |

---

## Phase 2 — Règles durcies (production)

Ces règles remplacent les règles permissives et appliquent une segmentation stricte.

> **Ordre important** : dans OPNsense, les règles sont évaluées de haut en bas. La première règle correspondante s'applique.

### Interface LAN (MGMT) — `10.0.10.0/24`

| # | Action | Proto | Source | Destination | Port | Description |
|---|---|---|---|---|---|---|
| 1 | Pass | * | `10.0.10.0/24` | * | * | Admins — accès complet |

Justification : Le VLAN MGMT est le réseau d'administration. Il doit avoir accès à tout.

### Interface DMZ — `10.0.20.0/24`

| # | Action | Proto | Source | Destination | Port | Description |
|---|---|---|---|---|---|---|
| 1 | Block | * | `10.0.20.0/24` | `10.0.10.0/24` | * | Bloquer DMZ → MGMT |
| 2 | Block | * | `10.0.20.0/24` | `10.0.30.0/24` | * | Bloquer DMZ → SRV |
| 3 | Pass | TCP | `10.0.20.0/24` | * | 80, 443 | HTTP/HTTPS sortant (Cloudflare, updates) |
| 4 | Pass | TCP/UDP | `10.0.20.0/24` | * | 53 | DNS sortant |
| 5 | Block | * | `10.0.20.0/24` | * | * | Bloquer tout le reste |

Justification : La DMZ peut initier des connexions vers Internet (Cloudflare Tunnel), mais ne doit pas accéder aux réseaux internes (MGMT, SRV).

### Interface SRV — `10.0.30.0/24`

| # | Action | Proto | Source | Destination | Port | Description |
|---|---|---|---|---|---|---|
| 1 | Block | * | `10.0.30.0/24` | `10.0.10.0/24` | * | Bloquer SRV → MGMT |
| 2 | Pass | TCP | `10.0.30.0/24` | * | 80, 443 | HTTP/HTTPS sortant Internet |
| 3 | Pass | TCP/UDP | `10.0.30.0/24` | * | 53 | DNS sortant |
| 4 | Pass | TCP | `10.0.30.0/24` | `10.0.20.0/24` | 80, 443 | Vers DMZ (reverse proxy) si nécessaire |
| 5 | Block | * | `10.0.30.0/24` | * | * | Bloquer tout le reste |

Justification : Les VMs de service peuvent sortir vers Internet mais n'administrent pas le réseau MGMT.

### Interface WAN

| # | Action | Proto | Source | Destination | Port | Description |
|---|---|---|---|---|---|---|
| 1 | Block | * | * | * | * | Bloquer tout entrant WAN (défaut) |

---

## Résumé de la politique de sécurité

```
MGMT  → * : ✅ Autorisé (admins)
DMZ   → MGMT : ❌ Bloqué
DMZ   → SRV  : ❌ Bloqué
DMZ   → Internet (80/443) : ✅ Autorisé (Cloudflare Tunnel)
SRV   → MGMT : ❌ Bloqué
SRV   → Internet (80/443) : ✅ Autorisé
SRV   → DMZ (80/443) : ✅ Autorisé (optionnel)
WAN → * : ❌ Bloqué (défaut)
```

---

## Voir aussi

- [configs/opnsense/interfaces.md](interfaces.md) — Interfaces OPNsense
- [configs/opnsense/nat.md](nat.md) — Outbound NAT
- [docs/opnsense.md](../../docs/opnsense.md) — Documentation complète OPNsense
- [docs/security.md](../../docs/security.md) — Politique de sécurité globale
