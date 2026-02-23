# infra/azure/modules/vm/outputs.tf

output "public_ip_address" {
  description = "Public IP address of the VM."
  value       = azurerm_public_ip.main.ip_address
}

output "resource_group_name" {
  description = "Resource group name."
  value       = azurerm_resource_group.main.name
}
