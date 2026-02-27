# deploy

Deployment artefacts for the Breedbase T3 application stack on Azure.

Contains everything needed to stand up a new client instance after the VM is provisioned.
The T3 Breedbase repo (github.com/TriticeaeToolbox/breedbase) is cloned separately on each
VM — this directory holds only what T3 doesn't provide. See `infra/` for Terraform templates
that provision the VM.

## Contents

- `nginx/breedbase.conf.template` — nginx server block: HTTP→HTTPS redirect, SSL termination, proxy_pass to Breedbase on localhost:8082
- `breedbase/sgn_local.conf.template` — Breedbase application config for the barley (hordeum) instance
- `scripts/configure.sh` — substitutes `{{PLACEHOLDER}}` values in templates via sed; takes (source, destination) arguments
- `scripts/backup.sh` — pg_dump from the breedbase_db container to Azure Blob Storage; install as a weekly cron job
- `scripts/tests/test_configure.sh` — bash test suite for configure.sh
- `RUNBOOK.md` — step-by-step guide: bare Azure VM → running Breedbase instance

## Deployment

See [RUNBOOK.md](RUNBOOK.md) for the full procedure.

Quick summary:
1. Provision VM with Terraform (`infra/`)
2. Set DNS A record pointing the client hostname to the VM's public IP
3. Set client environment variables (see Placeholders below)
4. Follow RUNBOOK.md steps in order

## Placeholders

All templates use `{{PLACEHOLDER}}` syntax. `configure.sh` reads these from environment
variables and performs substitution via sed.

| Placeholder | Description | Used in |
|---|---|---|
| `{{CLIENT_HOSTNAME}}` | Public hostname, e.g. `violet-moose-lantern.ourplatform.ca` | nginx, sgn_local.conf |
| `{{CLIENT_NAME}}` | Short client identifier, e.g. `violet-moose-lantern` | sgn_local.conf |
| `{{DB_PASSWORD}}` | PostgreSQL password for `web_usr` — generate at deploy time | sgn_local.conf |
| `{{CONTACT_EMAIL}}` | Admin contact address | sgn_local.conf |

The Breedbase breeding program name (e.g. `AB_Barley`) is set through the Breedbase web UI
after deployment, not via a template placeholder.

## Backup environment variables

`backup.sh` is not a template — it reads these at runtime from the environment:

| Variable | Description |
|---|---|
| `CLIENT_NAME` | Used in backup filename |
| `AZURE_STORAGE_ACCOUNT` | Azure storage account name |
| `AZURE_CONTAINER` | Azure blob container name |

These are stored in `/etc/breedbase-client.env` alongside the template placeholders. The file
is created by `sudo tee` (root-owned by default); the RUNBOOK immediately `chown`s it to the
deployment user so it can be sourced directly and read by cron jobs running as that user.

## Tests

```bash
bash deploy/scripts/tests/test_configure.sh
```
