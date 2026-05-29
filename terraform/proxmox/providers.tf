terraform {
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
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
  endpoint = var.proxmox_endpoint
  username = var.proxmox_username
  password = var.proxmox_password

  # Désactiver la vérification TLS si certificat auto-signé (lab uniquement)
  insecure = var.proxmox_insecure

  ssh {
    agent    = false
    username = var.proxmox_ssh_user
    password = var.proxmox_ssh_password
  }
}
