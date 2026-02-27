# deploy/ — Breedbase T3 Application Deployment Design

**Date:** 2026-02-22
**Status:** Approved
**Branch:** feature/deploy

---

## Decision

Templates + scripts + RUNBOOK. Terraform handles VM provisioning (infra/); this
directory covers everything that happens after the VM exists.

T3 Breedbase repo (github.com/TriticeaeToolbox/breedbase) is cloned separately on
each client VM. deploy/ holds only what T3 doesn't provide: nginx config, Breedbase
app config, backup automation, and the deployment runbook.

## Directory Structure

```
deploy/
├── nginx/
│   └── breedbase.conf.template       # nginx server block, SSL, proxy_pass
├── breedbase/
│   └── sgn_local.conf.template       # Breedbase app config
├── scripts/
│   ├── configure.sh                  # substitutes {{PLACEHOLDERS}} in templates
│   └── backup.sh                     # pg_dump → Azure Blob Storage
└── RUNBOOK.md                        # VM → running Breedbase, step by step
```

## Placeholders

| Placeholder | Example | Used in |
|---|---|---|
| `{{CLIENT_HOSTNAME}}` | `violet-moose-lantern.ourplatform.ca` | nginx, sgn_local.conf |
| `{{CLIENT_NAME}}` | `violet-moose-lantern` | sgn_local.conf, backup.sh |
| `{{DB_PASSWORD}}` | *(generated at deploy time)* | sgn_local.conf |
| `{{CONTACT_EMAIL}}` | `admin@ourplatform.ca` | sgn_local.conf |
| `{{AZURE_STORAGE_ACCOUNT}}` | `tillerbackups` | backup.sh |
| `{{AZURE_CONTAINER}}` | `violet-moose-lantern-backups` | backup.sh |

Note: `PROGRAM_NAME` (the Breedbase breeding program, e.g. `AB_Barley`) is not a
config file value — it is created through the Breedbase UI after deployment.

`configure.sh` accepts these as environment variables and runs `sed` substitution,
writing configured files to their install paths.

## RUNBOOK Scope

1. Initial VM setup — Docker, nginx, certbot, azure-cli
2. Clone T3: `git clone https://github.com/TriticeaeToolbox/breedbase`
3. `./bin/breedbase setup` — first image pull, DB init, password setup
4. `configure.sh` — writes nginx config and sgn_local.conf from templates
5. Obtain SSL cert via certbot
6. `./bin/breedbase start`
7. Install backup cron (weekly backup.sh)
8. Smoke test checklist

## Out of Scope

- Azure VM provisioning — infra/ (Terraform)
- DNS record creation — manual step documented in RUNBOOK
- RStudio Server — Phase 2
