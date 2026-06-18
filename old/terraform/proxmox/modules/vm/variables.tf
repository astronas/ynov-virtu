variable "vm_id" {
  type = number
}

variable "name" {
  type = string
}

variable "node_name" {
  type = string
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "cpu_cores" {
  type    = number
  default = 1
}

variable "memory" {
  description = "RAM en Mo"
  type        = number
  default     = 1024
}

variable "disk_size" {
  description = "Taille du disque scsi0 (OS) — doit être >= taille dans le template (ex: \"48G\")"
  type        = string
  default     = "48G"
}

variable "datastore_id" {
  type    = string
  default = "local-lvm"
}

variable "network_devices" {
  description = "Liste des interfaces réseau de la VM"
  type = list(object({
    bridge  = string
    model   = string
    vlan_id = optional(number)
  }))
  default = []
}

variable "clone_template" {
  description = "Nom du template VM Proxmox à cloner (doit exister sur le nœud cible)"
  type        = string
}

variable "ipv4_address" {
  description = "IP statique en notation CIDR (ex: 10.0.20.5/24) injectée par cloud-init, ou \"dhcp\""
  type        = string
}

variable "ipv4_gateway" {
  description = "Passerelle IPv4 (ignorée si ipv4_address = dhcp)"
  type        = string
  default     = ""
}

# ── Cloud-init ──────────────────────────────────────────────────────────────

variable "cloud_init_user" {
  description = "Utilisateur créé par cloud-init"
  type        = string
  default     = "debian"
}

variable "cloud_init_password" {
  description = "Mot de passe de l'utilisateur cloud-init"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Clé(s) SSH publique(s) ajoutée(s) à l'utilisateur cloud-init (newline-delimited)"
  type        = string
  default     = ""
}

variable "nameserver" {
  description = "Serveur(s) DNS pour cloud-init (séparés par des espaces)"
  type        = string
  default     = "10.0.10.254 1.1.1.1"
}
