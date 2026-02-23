# infra/azure/modules/vm/variables.tf

variable "client_name" {
  description = "Short client identifier."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "vm_size" {
  description = "VM SKU."
  type        = string
}

variable "admin_username" {
  description = "SSH username on the VM."
  type        = string
}

variable "admin_ssh_public_key" {
  description = "SSH public key content."
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
