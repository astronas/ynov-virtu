# OPNsense — Outbound NAT

## Principe

OPNsense fait du NAT sortant (masquerading) pour permettre aux réseaux internes d'accéder à Internet via l'interface WAN (`10.0.99.2`).

Le PC Windows fait ensuite un second NAT depuis `10.0.99.1` vers Internet via Wi-Fi.

```
VM interne (10.0.30.x)
  → OPNsense MASQUERADE (10.0.30.x → 10.0.99.2)
  → PC Windows MASQUERADE (10.0.99.2 → IP Wi-Fi)
  → Internet
```

---

## Configuration Outbound NAT

**Firewall → NAT → Outbound** → sélectionner **Automatic outbound NAT**.

En mode automatique, OPNsense crée les règles suivantes :

| Interface | Source | Destination | Translation | Description |
|---|---|---|---|---|
| WAN | `10.0.10.0/24` | * | Interface WAN (`10.0.99.2`) | MGMT → Internet |
| WAN | `10.0.20.0/24` | * | Interface WAN (`10.0.99.2`) | DMZ → Internet |
| WAN | `10.0.30.0/24` | * | Interface WAN (`10.0.99.2`) | SRV → Internet |

---

## Mode manuel (si besoin de granularité)

Passer en mode **Manual** pour des règles explicites :

```
Action      : MASQUERADE
Interface   : WAN
Protocol    : any
Source      : 10.0.10.0/24
Destination : any
Translation : Interface address (10.0.99.2)
Description : NAT MGMT vers WAN

(Répéter pour 10.0.20.0/24 et 10.0.30.0/24)
```

---

## Vérification

Depuis une VM sur VLAN 30 (SRV) :

```bash
# Vérifier la gateway
ip route show

# Tester le routage vers OPNsense
ping 10.0.30.254

# Tester l'accès Internet (via OPNsense + NAT Windows)
ping 1.1.1.1
curl -s https://ifconfig.me
```

Depuis OPNsense (shell SSH sur `10.0.10.254`) :

```bash
# Voir les connexions NAT actives
pfctl -s state | grep 10.0.99

# Statistiques NAT
pfctl -s info
```
