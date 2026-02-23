# infra/azure/modules/backup-container/outputs.tf

output "container_name" {
  description = "Blob container name for client backups."
  value       = azurerm_storage_container.main.name
}
