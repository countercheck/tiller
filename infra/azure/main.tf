# infra/azure/main.tf

module "vm" {
  source = "./modules/vm"

  client_name                   = var.client_name
  location                      = var.location
  vm_size                       = var.vm_size
  admin_username                = var.admin_username
  admin_ssh_public_key          = var.admin_ssh_public_key
  backup_storage_account_name   = var.backup_storage_account_name
  backup_storage_resource_group = var.backup_storage_resource_group
}

module "backup_container" {
  source = "./modules/backup-container"

  client_name                   = var.client_name
  backup_storage_account_name   = var.backup_storage_account_name
  backup_storage_resource_group = var.backup_storage_resource_group
}
