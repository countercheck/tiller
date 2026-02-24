# infra/azure/providers.tf
terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  # subscription_id is read from ARM_SUBSCRIPTION_ID environment variable.
  # Set it before running tofu: export ARM_SUBSCRIPTION_ID="<your-sub-id>"
}
