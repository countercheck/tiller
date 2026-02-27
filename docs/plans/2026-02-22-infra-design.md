# infra/ Design

## Goal

Automate provisioning of a per-client Azure VM and backup storage container using
Terraform, with a clear provider boundary so switching cloud providers requires only
adding a new provider directory.

## Architecture

Terraform with provider-prefixed directories. The `azure/` directory is the Azure
implementation; `variables.tf` and `outputs.tf` define the contract any future
provider implementation must satisfy. Terraform is provider-agnostic at the tool
level; the directory structure makes the implementation boundary explicit.

No abstraction layer across providers — that would be misleading. Real isolation
means: "I know exactly what to change and where to add it."

## Tech Stack

- Terraform (HCL)
- azurerm provider
- State: local (`terraform.tfstate`, gitignored)

## Decisions

**DNS:** Manual. Terraform outputs the public IP; the operator sets the A record by hand.
This matches the existing RUNBOOK flow.

**Backup storage:** One shared storage account (`tillerbackups`) created manually once
during platform setup. Terraform adds a per-client blob container to it. The shared
account is referenced via a data source, not managed by per-client Terraform state.

**State backend:** Local file. Solo operator, no collaboration needed now. Migrate to
Azure Blob Storage backend if/when a second operator is added.

## Directory Structure

```
infra/
├── README.md                         # contract documentation
├── azure/
│   ├── providers.tf                  # azurerm provider + version constraints
│   ├── variables.tf                  # input contract
│   ├── outputs.tf                    # output contract
│   ├── main.tf                       # resource group + module composition
│   ├── modules/
│   │   ├── vm/                       # VM, VNet, NSG, managed identity, role assignment
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── backup-container/         # blob container in shared storage account
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── clients/
│       └── violet-moose-lantern.tfvars           # per-client values (committed, no secrets)
└── (future: aws/, gcp/)
```

## Input Contract (`variables.tf`)

| Variable | Default | Notes |
|---|---|---|
| `client_name` | — | Short identifier, e.g. `violet-moose-lantern` |
| `location` | `canadacentral` | Azure region |
| `vm_size` | `Standard_B2ms` | |
| `admin_username` | `tiller` | SSH user on the VM |
| `admin_ssh_public_key` | — | Public key content |
| `backup_storage_account_name` | — | Pre-existing shared account, e.g. `tillerbackups` |
| `backup_storage_resource_group` | — | Resource group of the shared storage account |

## Output Contract (`outputs.tf`)

| Output | Purpose |
|---|---|
| `public_ip_address` | Set DNS A record |
| `resource_group_name` | `az` CLI operations |
| `backup_container_name` | `AZURE_CONTAINER` in `breedbase-client.env` |

## Azure Resources

### `modules/vm/`

- `azurerm_resource_group` — `tiller-{client_name}`
- `azurerm_virtual_network` + `azurerm_subnet`
- `azurerm_public_ip` (static)
- `azurerm_network_security_group` — inbound: SSH (22), HTTP (80), HTTPS (443)
- `azurerm_network_interface`
- `azurerm_user_assigned_identity`
- `azurerm_linux_virtual_machine` — B2ms, Ubuntu 22.04 LTS, identity attached
- `azurerm_role_assignment` — Storage Blob Data Contributor on shared backup account
  (enables `az storage blob upload --auth-mode login` without stored credentials)

### `modules/backup-container/`

- `data.azurerm_storage_account` — references pre-existing shared account
- `azurerm_storage_container` — `{client_name}-backups`

## Deployment Workflow

```bash
cd infra/azure
terraform init
terraform plan  -var-file=clients/violet-moose-lantern.tfvars
terraform apply -var-file=clients/violet-moose-lantern.tfvars

# Consume outputs in RUNBOOK:
terraform output public_ip_address      # → set DNS A record
terraform output backup_container_name  # → AZURE_CONTAINER in breedbase-client.env
```

## Provider Isolation Seam

A future provider (e.g. `infra/aws/`) would:
1. Accept the same variables defined in the input contract
2. Produce the same outputs defined in the output contract
3. Contain AWS-specific resources (EC2, Security Groups, IAM role, S3 bucket/prefix)

The `infra/README.md` documents the contract abstractly. The provider directories
implement it concretely.
