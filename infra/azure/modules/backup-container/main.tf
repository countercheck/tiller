# infra/azure/modules/backup-container/main.tf

data "azurerm_storage_account" "backup" {
  name                = var.backup_storage_account_name
  resource_group_name = var.backup_storage_resource_group
}

resource "azurerm_storage_container" "main" {
  name               = "${var.client_name}-backups"
  storage_account_id = data.azurerm_storage_account.backup.id
}
