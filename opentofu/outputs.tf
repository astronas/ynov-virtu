output "vm_ips" {
  description = "Adresses IPv4 configurees via cloud-init (statiques ou allouees par NetBox)."
  value       = { for k, v in var.vms : k => split("/", local.vm_ip_cidr[k])[0] }
}

output "ssh_commands" {
  description = "Commandes SSH utiles apres initialisation cloud-init."
  value       = { for k, v in var.vms : k => "ssh ${var.ci_user}@${split("/", local.vm_ip_cidr[k])[0]}" }
}

