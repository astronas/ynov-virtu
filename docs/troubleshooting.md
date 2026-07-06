# Troubleshooting - Résolution de problèmes

Ce document répertorie les problèmes rencontrés pendant le déploiement du lab, ainsi que les procédures de diagnostic et de résolution.

---

## Problème 1 - Ping VLAN 10 → VLAN 30 ne fonctionne pas

### Symptôme

Un PC admin branché en VLAN 10 (`10.0.10.x`) ne parvient pas à pinger le réseau SRV (`10.0.30.x`) ni à accéder à des VMs sur ce VLAN, bien que OPNsense soit configuré avec des règles `any-any` et que le switch transporte correctement les VLANs.

### Investigation

```bash
# Sur le PC Windows admin - vérifier les routes actives
route print

# Chercher des routes conflictuelles
# Exemple de route problématique :
# 0.0.0.0  0.0.0.0  192.168.1.1  192.168.1.x  → défaut Wi-Fi (ancienne connexion)
# 10.0.30.0  255.255.255.0  On-link  10.0.10.x  → route incorrecte
```

### Cause identifiée

Le PC admin avait une interface **Wi-Fi active** avec une route par défaut héritée d'une ancienne connexion. Cette route entrait en conflit avec la gateway de l'interface Ethernet (vers l'infra), causant un routage asymétrique ou incorrect :

- La requête ICMP vers `10.0.30.x` partait bien par la bonne interface.
- Mais la réponse d'OPNsense arrivait sur l'interface Ethernet du PC, alors que la table de routage du PC voulait retourner la réponse par le Wi-Fi.

### Résolution

```powershell
# Sur le PC admin Windows - Vérifier toutes les routes
route print

# Supprimer la route par défaut problématique sur l'interface Wi-Fi (si non nécessaire)
# (Identifier l'index de l'interface Wi-Fi dans "route print")
route delete 0.0.0.0 mask 0.0.0.0 <gateway-wifi>

# Ou augmenter la métrique de l'interface Wi-Fi pour forcer l'usage de l'Ethernet
Set-NetIPInterface -InterfaceAlias "Wi-Fi" -InterfaceMetric 5000

# Vérifier la nouvelle table de routage
route print

# Tester à nouveau
ping 10.0.30.254
```

### Leçon retenue

Lorsqu'un PC a plusieurs interfaces réseau actives (Ethernet + Wi-Fi), les routes par défaut peuvent entrer en conflit. Toujours vérifier `route print` en premier lors d'un problème de routage inter-VLAN inexpliqué côté client.

---

## Problème 2 - <img src="assets/logos/opnsense.svg" class="inline-logo" alt=""> OPNsense ne ping pas Internet (`1.1.1.1`)

### Symptôme

OPNsense peut pinger `10.0.99.1` (PC Windows) mais pas `1.1.1.1`.

### Diagnostic

```bash
# Sur OPNsense
ping 10.0.99.1        # OK → lien OPNsense ↔ Windows fonctionne
ping 1.1.1.1          # KO → NAT ou forwarding manquant

# Sur Windows
Get-NetNat            # Vérifier que le NAT est actif
Get-NetIPInterface | Where-Object { $_.Forwarding -eq "Enabled" }
```

### Causes possibles et résolutions

| Cause | Vérification | Résolution |
|---|---|---|
| NAT non créé | `Get-NetNat` → vide | Exécuter `windows-nat-setup.ps1` |
| Forwarding désactivé | `Get-NetIPInterface` → Forwarding=Disabled | `Set-NetIPInterface -Forwarding Enabled` |
| Firewall Windows bloque | Test depuis Windows direct | Désactiver temporairement le pare-feu Windows |
| Wi-Fi sans Internet | `ping 1.1.1.1` depuis Windows | Vérifier la connexion Wi-Fi |
| Gateway WAN OPNsense incorrecte | **System → Gateways** dans OPNsense | Corriger en `10.0.99.1` |

---

## Problème 3 - LACP Po1/Po2 ne monte pas (<img src="assets/logos/ceph.svg" class="inline-logo" alt=""> Ceph)

### Symptôme

Le bond LACP sur PRX1 ou PRX3 ne s'établit pas. L'interface `bond0` est dans l'état `DOWN` ou un seul lien est actif.

### Diagnostic

```bash
# Sur PRX1 ou PRX3 - état du bond
cat /proc/net/bonding/bond0

# Vérifier les logs
dmesg | grep -i bond | tail -20
journalctl -u networking | tail -30

# Sur le switch Arista
show port-channel summary
show lacp 1 peer   # pour Po1
show lacp 2 peer   # pour Po2
show interfaces Ethernet49/1 status
show interfaces Ethernet49/2 status
```

### Causes possibles

| Cause | Symptôme | Résolution |
|---|---|---|
| Mode LACP différent entre switch et serveur | Un seul lien actif | Vérifier `bond-mode 802.3ad` côté Linux et `channel-group X mode active` côté switch |
| Câble SFP mal branché | Interface `notconnect` sur switch | Re-brancher et vérifier l'interface |
| `channel-group` non configuré sur Et49/x | `(I)ndividual` dans `show port-channel summary` | Ajouter `channel-group X mode active` sur l'interface |
| Hash policy incompatible | Lien asymétrique | Ajuster `bond-xmit-hash-policy layer3+4` |
| `ifreload` pas exécuté | Ancienne config encore active | `ifreload -a` ou redémarrer networking |

### Vérification switch OK

```
YNOV-SW-LAB# show port-channel summary
Flags:  D - Down  P - bundled in port-channel  I - individual
        s - suspended  H - Hot-standby (LACP only)

Group  Port-Channel  Protocol  Ports
------+--------------+---------+-----------------------------
1      Po1(U)         LACP      Et49/1(P) Et49/2(P)
2      Po2(U)         LACP      Et49/3(P) Et49/4(P)
```

Tous les ports doivent être `(P)` (bundled).

---

## Problème 4 - Ceph en état HEALTH_WARN

### Symptôme

`ceph status` affiche `HEALTH_WARN` ou `HEALTH_ERR`.

### Diagnostics courants

```bash
# Détail de l'avertissement
ceph health detail

# Cas 1 : trop peu de replicas disponibles
# → Vérifier que les OSD sont tous UP
ceph osd stat
ceph osd tree

# Cas 2 : MON quorum insuffisant
ceph mon stat
ceph quorum_status

# Cas 3 : PG dégradés
ceph pg stat
ceph pg dump | grep -v "active+clean"

# Cas 4 : OSD hors ligne
ceph osd dump | grep "down"
journalctl -u ceph-osd@0 --since "1 hour ago"
```

### Résolution - OSD down

```bash
# Identifier l'OSD down
ceph osd tree

# Redémarrer l'OSD sur le nœud concerné
systemctl restart ceph-osd@<id>

# Forcer le marquage up (si nécessaire en cas de blocage)
ceph osd up <id>
ceph osd in <id>
```

---

## Problème 5 - Interface Proxmox inaccessible après modification `/etc/network/interfaces`

### Symptôme

Après modification du fichier interfaces et `ifreload -a`, l'interface web Proxmox (`https://10.0.10.x:8006`) n'est plus accessible.

### Diagnostic

```bash
# Vérifier que l'IP est bien assignée
ip addr show vmbr0

# Vérifier la route par défaut
ip route show

# Vérifier la gateway
ping 10.0.10.254
```

### Résolution

```bash
# Si l'IP vmbr0 est manquante, la reconfigurer manuellement
ip addr add 10.0.10.x/24 dev vmbr0
ip link set vmbr0 up
ip route add default via 10.0.10.254

# Corriger le fichier /etc/network/interfaces
# (utiliser la console IPMI si SSH inaccessible)
nano /etc/network/interfaces

# Réappliquer
ifreload -a
```

---

## Checklist de débogage rapide

```
[ ] Switch : show vlan → VLANs 10/20/30/99/101/102/4094 présents ?
[ ] Switch : show interfaces trunk → trunks Et2/3/4 avec bons VLANs ?
[ ] Switch : show port-channel summary → Po1/Po2 en U, liens en P ?
[ ] PRX1/2/3 : ip addr show → adresses 10.0.10.x, 10.0.101.x présentes ?
[ ] PRX1/3 : bond0 UP ? bond0.101 UP ? bond0.102 UP ?
[ ] PC Windows : Get-NetNat → NAT-OPNSENSE-WAN99 présent ?
[ ] PC Windows : Forwarding Enabled sur Ethernet + Wi-Fi ?
[ ] PC Windows : route print → pas de route par défaut conflictuelle ?
[ ] OPNsense : ping 10.0.99.1 → OK ?
[ ] OPNsense : ping 1.1.1.1 → OK ?
[ ] OPNsense : Block private networks → désactivé sur WAN ?
[ ] OPNsense : Gateway GW_WAN → Online ?
[ ] Règles firewall → pas de règle bloquante involontaire ?
```
