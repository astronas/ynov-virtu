output "vm_ips" {
  description = "Adresses IPv4 configurees via cloud-init."
  value       = { for name, vm in var.vms : name => vm.ip }
}

output "ssh_commands" {
  description = "Commandes SSH utiles apres initialisation cloud-init."
  value       = { for name, vm in var.vms : name => "ssh ${var.ci_user}@${vm.ip}" }
}

