# infra/azure/variables.tf

variable "client_name" {
  description = "Short client identifier, e.g. violet-moose-lantern. Used in resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.client_name)) && length(var.client_name) >= 3 && length(var.client_name) <= 40
    error_message = "client_name must be 3-40 characters long and contain only lowercase letters, digits, and hyphens to satisfy Azure naming constraints."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "canadacentral"
}

variable "vm_size" {
  description = "VM SKU."
  type        = string
  default     = "Standard_B4ls_v2"
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
