# deploy

Deployment artefacts for the Breedbase T3 stack on Azure.

Contains everything needed to stand up a new client instance: containers, reverse
proxy config, Breedbase configuration, and backup automation. See `RUNBOOK.md`
for the step-by-step procedure (to be written).

## Contents (to be added)

- `docker-compose.yml` — Breedbase web + PostgreSQL 12 containers
- `nginx/` — nginx config template (reverse proxy + SSL termination)
- `breedbase/` — sgn_local.conf template for new breeding programs
- `scripts/` — backup cron script, certbot renewal hook
- `RUNBOOK.md` — step-by-step deployment guide
