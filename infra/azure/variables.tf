# infra/azure/variables.tf

variable "client_name" {
  description = "Short client identifier, e.g. edmonton. Used in resource names."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "canadacentral"
}

variable "vm_size" {
  description = "VM SKU."
  type        = string
  default     = "Standard_B2ms"
}

variable "admin_username" {
  description = "SSH username on the VM."
  type        = string
  default     = "tiller"
}

variable "admin_ssh_public_key" {
  description = "SSH public key content (full string, e.g. 'ssh-ed25519 AAAA...')."
  type        = string
}

variable "backup_storage_account_name" {
  description = "Name of the pre-existing shared Azure Storage account, e.g. tillerbackups."
  type        = string
}

variable "backup_storage_resource_group" {
  description = "Resource group of the pre-existing shared backup storage account."
  type        = string
}
