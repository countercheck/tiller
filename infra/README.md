# infra

OpenTofu configuration for provisioning Azure infrastructure per client deployment.

Each client gets an isolated resource group containing a VM, networking, managed identity,
and a blob container in the shared backup storage account.

## Provider isolation

The `azure/` directory is the Azure-specific implementation. The `variables.tf` and
`outputs.tf` in that directory define the contract: what goes in, what comes out. A future
provider implementation (`aws/`, `gcp/`) would accept the same variables and produce the
same outputs using provider-specific resources.

## Prerequisites

- OpenTofu >= 1.9 installed (`brew install opentofu`)
- Azure CLI authenticated: `az login`
- `ARM_SUBSCRIPTION_ID` environment variable set
- Shared backup storage account pre-created (once, manually):
  ```bash
  az group create --name tiller-platform --location canadacentral
  az storage account create \
      --name tillerbackups \
      --resource-group tiller-platform \
      --location canadacentral \
      --sku Standard_LRS \
      --kind StorageV2
  ```

## Deploying a new client

```bash
cd infra/azure

# 1. Edit clients/<client>.tfvars with correct values (copy from violet-moose-lantern.tfvars)
# 2. Provision
export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
tofu init
tofu plan  -var-file=clients/<client>.tfvars
tofu apply -var-file=clients/<client>.tfvars

# 3. Note outputs for use in the RUNBOOK
tofu output public_ip_address     # → set DNS A record
tofu output backup_container_name # → AZURE_CONTAINER in breedbase-client.env
```

## Contents

- `providers.tf` — OpenTofu and azurerm provider version constraints
- `variables.tf` — input contract
- `outputs.tf` — output contract
- `main.tf` — composes modules
- `modules/vm/` — VM, VNet, NSG, managed identity, Storage Blob Data Contributor role
- `modules/backup-container/` — blob container in shared storage account
- `clients/` — per-client `.tfvars` files (committed, no secrets)
