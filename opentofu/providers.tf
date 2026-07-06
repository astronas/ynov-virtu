terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
    # NetBox comme allocateur d'IP / source de verite IPAM.
    # NB: la compat provider<->NetBox est sensible. NetBox deploye ici = 4.3 ;
    # si `tofu plan` renvoie une erreur d'API, ajuste la version (voir
    # registry.terraform.io/providers/e-breuninger/netbox).
    netbox = {
      source  = "e-breuninger/netbox"
      version = "~> 4.0"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_user             = var.proxmox_user
  pm_password         = var.proxmox_password
  pm_tls_insecure     = var.proxmox_tls_insecure
  pm_parallel         = 1
}

provider "netbox" {
  server_url           = var.netbox_url
  api_token            = var.netbox_api_token
  allow_insecure_https = true
}
