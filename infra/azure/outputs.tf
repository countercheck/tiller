# infra/azure/outputs.tf

output "public_ip_address" {
  description = "Public IP of the VM. Set the DNS A record for CLIENT_HOSTNAME to this value."
  value       = module.vm.public_ip_address
}

output "resource_group_name" {
  description = "Azure resource group containing all client resources."
  value       = module.vm.resource_group_name
}

output "backup_container_name" {
  description = "Blob container name for backups. Use as AZURE_CONTAINER in breedbase-client.env."
  value       = module.backup_container.container_name
}
