# infra/azure/clients/violet-moose-lantern.tfvars
# Per-client values for the violet-moose-lantern deployment.
# No secrets here — admin_ssh_public_key is a public key.

client_name                   = "violet-moose-lantern"
location                      = "canadacentral"
vm_size                       = "Standard_B2ms"
admin_username                = "tiller"
admin_ssh_public_key          = "ssh-ed25519 REPLACE_WITH_ACTUAL_PUBLIC_KEY operator@host"
backup_storage_account_name   = "tillerbackups"
backup_storage_resource_group = "tiller-platform"
