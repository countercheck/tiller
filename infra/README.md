# infra

Bicep/ARM templates for provisioning Azure infrastructure per client deployment.

Each client gets an isolated resource group containing a VM, networking, and storage.

## Contents (to be added)

- `main.bicep` — top-level Bicep template
- `vm.bicep` — VM + networking module
- `storage.bicep` — Azure Blob Storage for backups
- `parameters/` — per-client parameter files
