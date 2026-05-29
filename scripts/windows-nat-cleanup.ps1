#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Suppression du NAT Windows OPNsense et remise en état par défaut.

.DESCRIPTION
    Supprime la règle NAT "NAT-OPNSENSE-WAN99" et désactive le forwarding
    IP sur les interfaces Ethernet et Wi-Fi.

.PARAMETER EthernetAlias
    Nom de l'interface Ethernet. Par défaut : "Ethernet"

.PARAMETER WifiAlias
    Nom de l'interface Wi-Fi. Par défaut : "Wi-Fi"

.EXAMPLE
    .\windows-nat-cleanup.ps1
    .\windows-nat-cleanup.ps1 -EthernetAlias "Ethernet 2"
#>

[CmdletBinding()]
param(
    [string]$EthernetAlias = "Ethernet",
    [string]$WifiAlias     = "Wi-Fi"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$NatName = "NAT-OPNSENSE-WAN99"

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

# ── Suppression du NAT ────────────────────────────────────────────────────────

Write-Step "Suppression de la règle NAT ($NatName)"

$existingNat = Get-NetNat -Name $NatName -ErrorAction SilentlyContinue
if ($existingNat) {
    Remove-NetNat -Name $NatName -Confirm:$false
    Write-OK "NAT '$NatName' supprimé"
} else {
    Write-Warn "NAT '$NatName' introuvable — rien à supprimer"
}

# ── Désactivation du forwarding ───────────────────────────────────────────────

Write-Step "Désactivation du forwarding IP"

$ethIface = Get-NetAdapter -Name $EthernetAlias -ErrorAction SilentlyContinue
if ($ethIface) {
    Set-NetIPInterface -InterfaceAlias $EthernetAlias -Forwarding Disabled
    Write-OK "Forwarding désactivé sur $EthernetAlias"
} else {
    Write-Warn "Interface '$EthernetAlias' introuvable — forwarding non modifié"
}

$wifiIface = Get-NetAdapter -Name $WifiAlias -ErrorAction SilentlyContinue
if ($wifiIface) {
    Set-NetIPInterface -InterfaceAlias $WifiAlias -Forwarding Disabled
    Write-OK "Forwarding désactivé sur $WifiAlias"
} else {
    Write-Warn "Interface '$WifiAlias' introuvable — forwarding non modifié"
}

# ── Remise à zéro de la métrique Ethernet ─────────────────────────────────────

Write-Step "Remise de la métrique Ethernet à automatique"

if ($ethIface) {
    Set-NetIPInterface -InterfaceAlias $EthernetAlias -AutomaticMetric Enabled
    Write-OK "Métrique automatique rétablie sur $EthernetAlias"
}

# ── Résumé ────────────────────────────────────────────────────────────────────

Write-Host "`n========================================" -ForegroundColor White
Write-Host " NAT Windows supprimé" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor White
Write-Host ""
Write-Host "  La règle NAT '$NatName' a été supprimée."
Write-Host "  Le forwarding IP a été désactivé sur $EthernetAlias et $WifiAlias."
Write-Host ""
Write-Host "  OPNsense n'a plus accès à Internet via ce PC."
Write-Host ""

# ── Vérification ─────────────────────────────────────────────────────────────

Write-Step "État final"
Write-Host "  NAT actifs :"
Get-NetNat | Format-Table Name, InternalIPInterfaceAddressPrefix
Write-Host "  Forwarding :"
Get-NetIPInterface | Where-Object { $_.Forwarding -eq "Enabled" } | Select-Object InterfaceAlias, Forwarding | Format-Table
