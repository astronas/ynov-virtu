#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Mise en place du NAT Windows pour la passerelle WAN OPNsense.

.DESCRIPTION
    Ce script configure le PC Windows comme passerelle WAN temporaire
    pour OPNsense. Il crée une règle NAT sur le réseau 10.0.99.0/24
    et active le forwarding IP sur les interfaces Ethernet et Wi-Fi.

    Architecture :
        OPNsense WAN (10.0.99.2) → PC Windows (10.0.99.1) → Wi-Fi → Internet

.PARAMETER EthernetAlias
    Nom de l'interface Ethernet connectée au switch (vers VLAN 99).
    Par défaut : "Ethernet"

.PARAMETER WifiAlias
    Nom de l'interface Wi-Fi connectée à Internet.
    Par défaut : "Wi-Fi"

.EXAMPLE
    .\windows-nat-setup.ps1
    .\windows-nat-setup.ps1 -EthernetAlias "Ethernet 2" -WifiAlias "Wi-Fi 2"

.NOTES
    Requiert PowerShell en tant qu'Administrateur.
    Testé sur Windows 10/11.
#>

[CmdletBinding()]
param(
    [string]$EthernetAlias = "Ethernet",
    [string]$WifiAlias     = "Wi-Fi"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$NatName    = "NAT-OPNSENSE-WAN99"
$NatNetwork = "10.0.99.0/24"
$EthernetIP = "10.0.99.1"
$PrefixLen  = 24

function Write-Step {
    param([string]$Message)
    Write-Host "`n[>>] $Message" -ForegroundColor Cyan
}

function Write-OK {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [!]  $Message" -ForegroundColor Yellow
}

# ── Vérification des interfaces ────────────────────────────────────────────────

Write-Step "Vérification des interfaces réseau"

$ethIface = Get-NetAdapter -Name $EthernetAlias -ErrorAction SilentlyContinue
if (-not $ethIface) {
    Write-Error "Interface Ethernet '$EthernetAlias' introuvable. Interfaces disponibles :`n$(Get-NetAdapter | Select-Object Name, Status | Format-Table | Out-String)"
}
Write-OK "Interface Ethernet trouvée : $EthernetAlias (Status: $($ethIface.Status))"

$wifiIface = Get-NetAdapter -Name $WifiAlias -ErrorAction SilentlyContinue
if (-not $wifiIface) {
    Write-Error "Interface Wi-Fi '$WifiAlias' introuvable. Interfaces disponibles :`n$(Get-NetAdapter | Select-Object Name, Status | Format-Table | Out-String)"
}
Write-OK "Interface Wi-Fi trouvée : $WifiAlias (Status: $($wifiIface.Status))"

# ── Configuration IP de l'interface Ethernet ──────────────────────────────────

Write-Step "Configuration IP de l'interface Ethernet ($EthernetAlias)"

$existingIP = Get-NetIPAddress -InterfaceAlias $EthernetAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
if ($existingIP -and $existingIP.IPAddress -eq $EthernetIP) {
    Write-OK "IP $EthernetIP déjà configurée sur $EthernetAlias"
} else {
    # Supprimer les IP existantes sur cette interface
    $existingIP | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

    # Supprimer les gateways existantes sur cette interface (important)
    Remove-NetRoute -InterfaceAlias $EthernetAlias -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue

    # Configurer la nouvelle IP statique sans gateway
    New-NetIPAddress `
        -InterfaceAlias $EthernetAlias `
        -IPAddress $EthernetIP `
        -PrefixLength $PrefixLen | Out-Null

    Write-OK "IP $EthernetIP/$PrefixLen configurée sur $EthernetAlias (sans gateway)"
}

# ── Métrique de l'interface Ethernet (éviter conflit de route par défaut) ─────

Write-Step "Ajustement de la métrique de l'interface Ethernet"

Set-NetIPInterface -InterfaceAlias $EthernetAlias -InterfaceMetric 9000
Write-OK "Métrique Ethernet = 9000 (ne sera pas utilisée comme route par défaut)"

# ── Création de la règle NAT ──────────────────────────────────────────────────

Write-Step "Création de la règle NAT ($NatName)"

$existingNat = Get-NetNat -Name $NatName -ErrorAction SilentlyContinue
if ($existingNat) {
    Write-Warn "NAT '$NatName' existe déjà — suppression et recréation"
    Remove-NetNat -Name $NatName -Confirm:$false
}

New-NetNat -Name $NatName -InternalIPInterfaceAddressPrefix $NatNetwork | Out-Null
Write-OK "NAT '$NatName' créé pour le réseau $NatNetwork"

# ── Activation du forwarding IP ───────────────────────────────────────────────

Write-Step "Activation du forwarding IP"

Set-NetIPInterface -InterfaceAlias $EthernetAlias -Forwarding Enabled
Write-OK "Forwarding activé sur $EthernetAlias"

Set-NetIPInterface -InterfaceAlias $WifiAlias -Forwarding Enabled
Write-OK "Forwarding activé sur $WifiAlias"

# ── Résumé ────────────────────────────────────────────────────────────────────

Write-Host "`n========================================" -ForegroundColor White
Write-Host " NAT Windows configuré avec succès" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor White
Write-Host ""
Write-Host "  Interface Ethernet : $EthernetAlias — IP : $EthernetIP/$PrefixLen"
Write-Host "  Interface Wi-Fi    : $WifiAlias"
Write-Host "  NAT                : $NatName ($NatNetwork)"
Write-Host ""
Write-Host "  OPNsense WAN doit être configuré avec :"
Write-Host "    IP      : 10.0.99.2/24"
Write-Host "    Gateway : 10.0.99.1"
Write-Host ""
Write-Host "  Pour tester depuis OPNsense :"
Write-Host "    ping 10.0.99.1   → doit répondre"
Write-Host "    ping 1.1.1.1     → doit répondre (Internet via NAT)"
Write-Host ""

# ── Vérification rapide ───────────────────────────────────────────────────────

Write-Step "Vérification de la configuration"
Get-NetNat | Where-Object { $_.Name -eq $NatName } | Format-List Name, InternalIPInterfaceAddressPrefix
Get-NetIPInterface | Where-Object { $_.Forwarding -eq "Enabled" } | Select-Object InterfaceAlias, Forwarding | Format-Table
