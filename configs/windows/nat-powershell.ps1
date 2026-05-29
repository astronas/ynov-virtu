# Script PowerShell — NAT Windows (inline reference)
# Ce fichier est la version de référence utilisée dans la documentation.
# Utiliser le script complet : scripts/windows-nat-setup.ps1

# Créer le NAT pour le réseau WAN OPNsense
New-NetNat -Name "NAT-OPNSENSE-WAN99" -InternalIPInterfaceAddressPrefix "10.0.99.0/24"

# Activer le forwarding sur l'interface Ethernet (vers le switch)
Set-NetIPInterface -InterfaceAlias "Ethernet" -Forwarding Enabled

# Activer le forwarding sur l'interface Wi-Fi (vers Internet)
Set-NetIPInterface -InterfaceAlias "Wi-Fi" -Forwarding Enabled
