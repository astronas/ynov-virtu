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
  description = "Taille du disque OS en Go"
  type        = number
  default     = 16
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

variable "cloud_init_user" {
  type      = string
  sensitive = true
}

variable "cloud_init_password" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

variable "ipv4_address" {
  description = "IP statique en notation CIDR (ex: 10.0.20.5/24)"
  type        = string
}

variable "ipv4_gateway" {
  type = string
}
