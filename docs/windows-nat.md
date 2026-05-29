# NAT Windows — Passerelle WAN temporaire

## Rôle

Le PC Windows sert de **passerelle WAN temporaire** pour OPNsense, en attendant une connexion Internet dédiée. Il partage une connexion Wi-Fi (4G/5G ou fixe) vers le VLAN 99 via NAT PowerShell natif.

```
[Internet]
    │ Wi-Fi (DHCP opérateur)
[PC Windows]
    │ Ethernet — 10.0.99.1/24
[Switch Arista — Et1 — VLAN 99]
    │
[OPNsense WAN — 10.0.99.2/24]
```

---

## Configuration de la carte Ethernet Windows

La carte Ethernet du PC, connectée au switch sur `Et1` (access VLAN 99), doit être configurée manuellement :

| Paramètre | Valeur |
|---|---|
| Adresse IP | `10.0.99.1` |
| Masque | `255.255.255.0` |
| Gateway | *(vide — aucune)* |
| DNS | *(optionnel — `1.1.1.1`)* |

> **Important** : ne pas mettre de gateway sur l'interface Ethernet. Seule l'interface Wi-Fi doit avoir une gateway vers Internet.

### Via l'interface graphique Windows

1. Ouvrir **Paramètres → Réseau → Ethernet → Propriétés**
2. Sélectionner **Protocole Internet version 4 (TCP/IPv4)**
3. Saisir l'adresse IP statique `10.0.99.1`
4. Masque : `255.255.255.0`
5. Laisser la gateway vide
6. Valider

### Via PowerShell (Admin)

```powershell
# Remplacer "Ethernet" par le nom exact de l'interface si différent
$iface = "Ethernet"
New-NetIPAddress -InterfaceAlias $iface -IPAddress "10.0.99.1" -PrefixLength 24
# Ne pas définir de DefaultGateway sur cette interface
```

---

## Mise en place du NAT

### Prérequis

- PowerShell exécuté **en tant qu'Administrateur**
- La carte Wi-Fi doit avoir un accès Internet fonctionnel
- La carte Ethernet doit être configurée en `10.0.99.1/24`

### Commandes de base

```powershell
# 1. Créer le NAT sur le réseau 10.0.99.0/24
New-NetNat -Name "NAT-OPNSENSE-WAN99" -InternalIPInterfaceAddressPrefix "10.0.99.0/24"

# 2. Activer le forwarding sur l'interface Ethernet (vers switch)
Set-NetIPInterface -InterfaceAlias "Ethernet" -Forwarding Enabled

# 3. Activer le forwarding sur l'interface Wi-Fi (vers Internet)
Set-NetIPInterface -InterfaceAlias "Wi-Fi" -Forwarding Enabled
```

> Utiliser le **script complet** pour une mise en place robuste : [scripts/windows-nat-setup.ps1](../scripts/windows-nat-setup.ps1)

---

## Vérification

### Depuis Windows

```powershell
# Vérifier que le NAT est bien créé
Get-NetNat

# Vérifier le forwarding activé
Get-NetIPInterface | Where-Object { $_.Forwarding -eq "Enabled" } | Select-Object InterfaceAlias, Forwarding

# Pinger OPNsense WAN depuis Windows
ping 10.0.99.2

# Vérifier les routes
route print
```

### Depuis OPNsense

```bash
# OPNsense doit pouvoir pinger le PC Windows
ping 10.0.99.1

# Et accéder à Internet
ping 1.1.1.1
traceroute 1.1.1.1
```

---

## Nettoyage / suppression du NAT

Pour supprimer le NAT quand il n'est plus nécessaire :

```powershell
# Supprimer la règle NAT
Remove-NetNat -Name "NAT-OPNSENSE-WAN99" -Confirm:$false

# Désactiver le forwarding
Set-NetIPInterface -InterfaceAlias "Ethernet" -Forwarding Disabled
Set-NetIPInterface -InterfaceAlias "Wi-Fi" -Forwarding Disabled
```

Script complet : [scripts/windows-nat-cleanup.ps1](../scripts/windows-nat-cleanup.ps1)

---

## Problèmes courants

### OPNsense ne reçoit pas les pings depuis Windows

1. Vérifier la configuration IP de la carte Ethernet Windows (`ipconfig`).
2. Vérifier qu'`Et1` du switch est bien en access VLAN 99.
3. Vérifier que le câble est branché sur `Et1` du switch.
4. Vérifier qu'OPNsense a `10.0.99.2/24` sur son interface WAN.
5. Vérifier les règles firewall Windows (désactiver temporairement pour test).

### OPNsense ping `10.0.99.1` mais pas `1.1.1.1`

1. Vérifier que `New-NetNat` a bien été exécuté : `Get-NetNat`
2. Vérifier que le forwarding est activé sur les deux interfaces.
3. Vérifier que le Wi-Fi a bien un accès Internet depuis Windows.
4. Vérifier que la gateway OPNsense WAN pointe bien sur `10.0.99.1`.

### Conflit de route sur le PC Windows

Si le PC Windows a une route Wi-Fi et une route Ethernet dans le même sous-réseau ou avec des métriques conflictuelles, le routage peut ne pas fonctionner.

```powershell
# Afficher toutes les routes
route print

# Augmenter la métrique de l'interface Ethernet (la rendre moins prioritaire pour la route par défaut)
Set-NetIPInterface -InterfaceAlias "Ethernet" -InterfaceMetric 1000
```

> Voir [docs/troubleshooting.md](troubleshooting.md) pour le problème détaillé de route Windows.

---

## Voir aussi

- [scripts/windows-nat-setup.ps1](../scripts/windows-nat-setup.ps1) — Script complet de mise en place
- [scripts/windows-nat-cleanup.ps1](../scripts/windows-nat-cleanup.ps1) — Script de nettoyage
- [docs/troubleshooting.md](troubleshooting.md) — Résolution de problèmes
