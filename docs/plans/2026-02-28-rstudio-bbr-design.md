# Design: RStudio Server + bbr R Package

Date: 2026-02-28

## Context

Breedbase T3 is live on Azure. The breeder is exploring the web UI but has no way to connect
from R. RStudio Server is not yet deployed and the R helper package does not exist. This
deliverable gives the breeder a complete programmatic environment in one shot.

## Deliverable

Two things ship together:

1. **RStudio Server** on the existing VM, proxied by nginx
2. **`bbr` R package** pre-installed on RStudio Server, wrapping QBMS for Breedbase access

## Architecture

```
[Breeder / Analyst]
       |
       | HTTPS /rstudio
       |
[nginx — existing]
       |
       | proxy localhost:8787
       |
[RStudio Server — open source]
       |
       | bbr::bb_connect()
       |
[Breedbase BrAPI v1.3]
```

## RStudio Server Deployment

### bootstrap.sh changes

- Install R (system package)
- Install RStudio Server (`.deb` from Posit)
- Both steps idempotent (skip if already installed)

### deploy.sh changes

- Add `location /rstudio` nginx proxy block (to existing nginx config template)
- Create `breeder` and `analyst` OS accounts
- Install `bbr` and its R dependencies into the system R library

### Post-deploy manual steps (RUNBOOK)

- Set passwords: `sudo passwd breeder` and `sudo passwd analyst`
- Each user configures `~/.Renviron` with their Breedbase credentials

## bbr Package

### Package structure

```
r-package/
  DESCRIPTION
  NAMESPACE
  R/
    connect.R       # bb_connect()
    trials.R        # get_trials()
    germplasm.R     # get_germplasm()
    observations.R  # get_observations()
  tests/testthat/
    test-connect.R
    test-trials.R
    test-germplasm.R
    test-observations.R
```

### API

```r
# Connection — reads BB_URL and BB_TOKEN from .Renviron if not supplied
con <- bb_connect(
  url   = Sys.getenv("BB_URL"),
  token = Sys.getenv("BB_TOKEN")
)

# Queries — all return tidy data frames
get_trials(con, program = NULL, year = NULL)
get_germplasm(con, trial_id)
get_observations(con, trial_id, traits = NULL)
```

### Dependencies

- `QBMS` — BrAPI v1.3 HTTP client (handles pagination, auth)
- Tests: `testthat` + `httptest2` (mocked BrAPI responses, no live instance required)

### Error handling

`bb_connect()` fails fast with a clear message if:
- `BB_URL` or `BB_TOKEN` are missing or empty
- The Breedbase endpoint returns an auth error

No silent failures.

## Credentials

Each user stores credentials in `~/.Renviron` on the server:

```
BB_URL=https://<client-hostname>
BB_TOKEN=<token from Breedbase admin panel>
```

Not committed to git. Documented in RUNBOOK.

## User Accounts

| Account    | Purpose                            |
|------------|------------------------------------|
| `breeder`  | Day-to-day R use, reports, Shiny   |
| `analyst`  | Pipeline development, power use    |

Both accounts have `bbr` available. Further access differentiation (e.g. read-only DB
access for power users) is out of scope for this phase.

## Out of Scope

- Shiny Server deployment
- Analytical pipeline (rrBLUP, lme4, etc.)
- Quarto report templates
- Direct PostgreSQL access for power users
