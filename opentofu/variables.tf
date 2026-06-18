variable "proxmox_api_url" {
  description = "URL API Proxmox, exemple: https://pve.example.local:8006/api2/json"
  type        = string
}

variable "proxmox_tls_insecure" {
  description = "Accepte le certificat auto-signe de Proxmox."
  type        = bool
  default     = true
}

variable "proxmox_api_token_id" {
  description = "ID du token API Proxmox, exemple: terraform-prov@pve!terraform."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Secret du token API Proxmox."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_user" {
  description = "Utilisateur Proxmox si authentification par mot de passe, exemple: root@pam."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_password" {
  description = "Mot de passe Proxmox si authentification par utilisateur/mot de passe."
  type        = string
  default     = null
  sensitive   = true
}

variable "target_node" {
  description = "Nom du noeud Proxmox qui heberge les VMs."
  type        = string
}

variable "template_name" {
  description = "Nom du template Proxmox compatible cloud-init a cloner."
  type        = string
}

variable "storage" {
  description = "Stockage Proxmox pour les disques des VMs."
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Bridge Proxmox utilise pour net0."
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "Tag VLAN applique a l'interface reseau des VMs. Mettre null pour ne pas taguer."
  type        = number
  default     = null
}

variable "ci_user" {
  description = "Utilisateur principal cree par cloud-init."
  type        = string
  default     = "admin"
}

variable "ci_password" {
  description = "Mot de passe optionnel pour l'utilisateur cloud-init. Laisser a null pour ne pas en injecter."
  type        = string
  default     = null
  sensitive   = true
}

variable "dns_servers" {
  description = "Serveurs DNS injectes par cloud-init."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "search_domain" {
  description = "Domaine de recherche DNS."
  type        = string
  default     = "lab.local"
}

variable "gateway" {
  description = "Passerelle IPv4 du reseau des VMs."
  type        = string
}

variable "vms" {
  description = "Definition des VMs finales issues du template."
  type = map(object({
    vmid        = optional(number)
    hostname    = string
    ip          = string
    cidr        = number
    vlan_id     = optional(number)
    cores       = number
    memory      = number
    disk_size   = string
    description = string
    role        = string
  }))

  default = {
    bastion = {
      hostname    = "bastion"
      ip          = "192.168.10.10"
      cidr        = 24
      vlan_id     = 30
      cores       = 1
      memory      = 1024
      disk_size   = "16G"
      description = "Administration intermediaire"
      role        = "bastion"
    }
    web = {
      hostname    = "web"
      ip          = "192.168.10.20"
      cidr        = 24
      vlan_id     = 30
      cores       = 2
      memory      = 2048
      disk_size   = "20G"
      description = "Frontal web nginx/php"
      role        = "web"
    }
    db = {
      hostname    = "db"
      ip          = "192.168.10.30"
      cidr        = 24
      vlan_id     = 30
      cores       = 2
      memory      = 2048
      disk_size   = "24G"
      description = "Base de donnees MariaDB"
      role        = "db"
    }
    zabbix = {
      hostname    = "zabbix"
      ip          = "192.168.10.40"
      cidr        = 24
      vlan_id     = 30
      cores       = 2
      memory      = 3072
      disk_size   = "24G"
      description = "Supervision centralisee"
      role        = "zabbix"
    }
  }
}
