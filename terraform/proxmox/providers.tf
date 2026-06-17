terraform {
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      # Dernière version publiée sur le registre Terraform (la 3.0.2 stable
      # n'existe pas encore — seules des release candidates sont publiées).
      # La branche v3 corrige le bug de vérification de permission VM.Monitor
      # présent en 2.9.x sur Proxmox 8/9.
      version = "3.0.2-rc07"
    }
  }

  # Backend optionnel — décommenter pour stocker le state sur un serveur distant
  # backend "http" {
  #   address        = "http://10.0.10.x:8500/v1/kv/terraform/proxmox-vms"
  #   lock_address   = "http://10.0.10.x:8500/v1/session/create"
  #   unlock_address = "http://10.0.10.x:8500/v1/session/destroy/"
  # }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = var.proxmox_insecure
}
