# infra/azure/modules/backup-container/variables.tf

variable "client_name" {
  description = "Short client identifier."
  type        = string
}

variable "backup_storage_account_name" {
  description = "Name of the pre-existing shared backup storage account."
  type        = string
}

variable "backup_storage_resource_group" {
  description = "Resource group of the shared backup storage account."
  type        = string
}
