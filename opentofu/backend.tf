# Backend local par defaut.
# Pour GitLab HTTP backend, decommenter et adapter:
#
# terraform {
#   backend "http" {
#     address        = "https://gitlab.example.com/api/v4/projects/<PROJECT_ID>/terraform/state/proxmox-workshop"
#     lock_address   = "https://gitlab.example.com/api/v4/projects/<PROJECT_ID>/terraform/state/proxmox-workshop/lock"
#     unlock_address = "https://gitlab.example.com/api/v4/projects/<PROJECT_ID>/terraform/state/proxmox-workshop/lock"
#     lock_method    = "POST"
#     unlock_method  = "DELETE"
#     retry_wait_min = 5
#   }
# }

