# Repo Scaffold Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create the tiller monorepo directory structure with domain directories, stub READMEs, root tooling configs, and an initial git commit.

**Architecture:** Domain-based top-level directories, one tooling config per language at root. No code yet — just the skeleton that all future work slots into.

**Tech Stack:** Python (ruff, black, pre-commit), R (lintr), git

---

### Task 1: Create domain directories and stub READMEs

**Files:**
- Create: `infra/README.md`
- Create: `deploy/README.md`
- Create: `migration/README.md`
- Create: `brapi/README.md`
- Create: `r-package/README.md`
- Create: `pipeline/README.md`
- Create: `reports/README.md`
- Create: `shiny/README.md`

**Step 1: Create infra/README.md**

```markdown
# infra

Bicep/ARM templates for provisioning Azure infrastructure per client deployment.

Each client gets an isolated resource group containing a VM, networking, and storage.

## Contents (to be added)

- `main.bicep` — top-level Bicep template
- `vm.bicep` — VM + networking module
- `storage.bicep` — Azure Blob Storage for backups
- `parameters/` — per-client parameter files
```

**Step 2: Create deploy/README.md**

```markdown
# deploy

Deployment artefacts for the Breedbase T3 stack on Azure.

## Contents (to be added)

- `docker-compose.yml` — Breedbase web + PostgreSQL 12 containers
- `nginx/` — nginx config template (reverse proxy + SSL termination)
- `breedbase/` — sgn_local.conf template for new breeding programs
- `scripts/` — backup cron script, certbot renewal hook
- `RUNBOOK.md` — step-by-step deployment guide
```

**Step 3: Create migration/README.md**

```markdown
# migration

Python scripts for migrating historical data from Genovix into Breedbase.

Awaiting data dump from the Edmonton client. Format unknown.

## Approach

1. Assess dump format and map Genovix model → Breedbase/BrAPI model
2. Write idempotent migration scripts (safe to re-run)
3. Validate pedigree data with the breeder before committing

## Contents (to be added)

- `assess.py` — initial assessment of dump format
- `pedigree.py` — pedigree migration
- `trials.py` — trial data migration
- `validate.py` — post-migration validation
```

**Step 4: Create brapi/README.md**

```markdown
# brapi

Python glue scripts for BrAPI integration (Breedbase v1.3 endpoints).

Used for bulk operations, data loading, and automation that the R helper package
doesn't cover.

## Contents (to be added)

- Scripts added as needed during deployment and migration work
```

**Step 5: Create r-package/README.md**

```markdown
# r-package

Internal R helper package wrapping QBMS. Provides opinionated, pre-built query
functions against the Breedbase BrAPI endpoint.

## Purpose

- Abstracts BrAPI connection and authentication
- Provides clean functions for common queries (get_trials, get_germplasm, get_observations)
- Reusable across all client deployments (same package, different connection strings)

## Example usage

```r
con <- bb_connect("https://clientname.ourplatform.ca", token = Sys.getenv("BB_TOKEN"))
trials <- get_trials(con, program = "AB_Barley", year = 2024)
obs    <- get_observations(con, trial = trials$trialDbId[1])
```

## Contents (to be added)

Standard R package structure: `DESCRIPTION`, `NAMESPACE`, `R/`, `tests/`
```

**Step 6: Create pipeline/README.md**

```markdown
# pipeline

R analytical pipeline: trial analysis, combined analysis, GBLUP, breeding values.

Connects to Breedbase via the r-package BrAPI client.

## Key R packages

- lme4 + emmeans — trial analysis
- rrBLUP / sommer — GBLUP and breeding value estimation
- QBMS (via r-package) — BrAPI data access

## Contents (to be added)

- Analysis scripts added as pipeline is developed (Phase 2)
```

**Step 7: Create reports/README.md**

```markdown
# reports

Quarto report templates for end-of-season reporting.

## Audience

Client breeders and funders. No R knowledge required to read outputs.

## Report types (to be developed)

- Line advancement recommendations
- Cross performance summary
- Parent performance summary
- End-of-season trial summary

## Contents (to be added)

- `templates/` — Quarto .qmd templates
- `assets/` — shared styles, logos
```

**Step 8: Create shiny/README.md**

```markdown
# shiny

R Shiny dashboard for in-season interactive exploration.

Hosted on open-source Shiny Server on the client Azure VM.

## Audience

Client breeder. UI-only — no R knowledge required.

## Contents (to be added)

Built in Phase 2. Will use golem package structure if app grows beyond simple scripts.
```

**Step 9: Verify directories exist**

```bash
ls tiller/
```

Expected output includes: `infra/  deploy/  migration/  brapi/  r-package/  pipeline/  reports/  shiny/  docs/  CLAUDE.md`

**Step 10: Commit**

```bash
git add infra/ deploy/ migration/ brapi/ r-package/ pipeline/ reports/ shiny/
git commit -m "chore: scaffold domain directories with stub READMEs"
```

---

### Task 2: Create .gitignore

**Files:**
- Create: `.gitignore`

**Step 1: Create .gitignore**

```gitignore
# Python
__pycache__/
*.py[cod]
*.egg-info/
.venv/
venv/
dist/
build/
.pytest_cache/
.ruff_cache/
*.egg

# R
.Rhistory
.RData
.Rproj.user/
renv/library/
renv/staging/
*.Rcheck/

# Quarto
_site/
_freeze/
/.quarto/

# OS
.DS_Store
Thumbs.db

# Secrets / environment
.env
.Renviron
*.pem
```

**Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore for Python, R, Quarto, OS artefacts"
```

---

### Task 3: Create pyproject.toml

**Files:**
- Create: `pyproject.toml`

**Step 1: Create pyproject.toml**

```toml
[tool.ruff]
src = ["migration", "brapi", "infra"]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = [
    "E",   # pycodestyle errors
    "W",   # pycodestyle warnings
    "F",   # pyflakes
    "I",   # isort
    "UP",  # pyupgrade
]

[tool.black]
line-length = 100
target-version = ["py311"]
```

**Step 2: Commit**

```bash
git add pyproject.toml
git commit -m "chore: add pyproject.toml with ruff and black config"
```

---

### Task 4: Create .lintr

**Files:**
- Create: `.lintr`

**Step 1: Create .lintr**

```
linters: linters_with_defaults(
  line_length_linter(100),
  object_name_linter("snake_case")
)
encoding: "UTF-8"
```

**Step 2: Commit**

```bash
git add .lintr
git commit -m "chore: add .lintr config for R linting"
```

---

### Task 5: Create .pre-commit-config.yaml

**Files:**
- Create: `.pre-commit-config.yaml`

**Step 1: Create .pre-commit-config.yaml**

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.9.0
    hooks:
      - id: ruff
        args: [--fix]
        types_or: [python]
      - id: ruff-format
        types_or: [python]

  - repo: https://github.com/lorenzwalthert/precommit
    rev: v0.4.3
    hooks:
      - id: lintr
        types: [r]
```

**Step 2: Note on activation**

Pre-commit hooks are not active until `pre-commit install` is run in the repo. This is intentional — each developer runs it once after cloning. The R pre-commit hook also requires `precommit` R package installed: `install.packages("precommit")`.

Document this in the root README (Task 6).

**Step 3: Commit**

```bash
git add .pre-commit-config.yaml
git commit -m "chore: add pre-commit hooks for ruff and lintr"
```

---

### Task 6: Create root README.md

**Files:**
- Create: `README.md`

**Step 1: Create README.md**

```markdown
# tiller

Breeding informatics platform  for small barley and triticale
breeding programs. Built on Breedbase T3, deployed on Azure.

See `CLAUDE.md` for full architecture and domain context.

## Repository structure

| Directory    | Owner              | Contents |
|---|---|---|
| `infra/`     | Software engineer  | Bicep/ARM IaC templates |
| `deploy/`    | Software engineer  | Docker Compose, nginx, Breedbase config, backup scripts |
| `migration/` | Software engineer  | Python: Genovix → Breedbase migration scripts |
| `brapi/`     | Software engineer  | Python: BrAPI integration/glue scripts |
| `r-package/` | Breeder            | R helper package wrapping QBMS |
| `pipeline/`  | Breeder            | R analytical pipeline |
| `reports/`   | Breeder            | Quarto report templates |
| `shiny/`     | Breeder            | R Shiny dashboard |
| `docs/`      | Both               | Runbooks, architecture notes, design docs |

## Tooling

### Python (migration/, brapi/, infra/)

- **Linter:** ruff — `ruff check .`
- **Formatter:** black — `black .`
- Config in root `pyproject.toml`

### R (r-package/, pipeline/, reports/, shiny/)

- **Linter:** lintr — `lintr::lint_dir(".")`
- Config in root `.lintr`

### Pre-commit hooks

After cloning:

```bash
pip install pre-commit
pre-commit install
```

For R hooks also run in R:

```r
install.packages("precommit")
```

## Build phases

- **Phase 1** — Deploy Breedbase T3, migrate Genovix data, Field Book connection, Quarto reports, R helper package v1
- **Phase 2** — RStudio Server, Shiny dashboard, analytical pipeline
- **Phase 3** — Gigwa (genomics)
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add root README with repo structure and tooling guide"
```

---

### Task 7: Verify final state

**Step 1: Check tree**

```bash
find . -not -path './.git/*' | sort
```

Expected output:
```
.
./CLAUDE.md
./README.md
./.gitignore
./.lintr
./.pre-commit-config.yaml
./pyproject.toml
./brapi/README.md
./deploy/README.md
./docs/plans/2026-02-22-repo-scaffold-design.md
./docs/plans/2026-02-22-repo-scaffold.md
./infra/README.md
./migration/README.md
./pipeline/README.md
./r-package/README.md
./reports/README.md
./shiny/README.md
```

**Step 2: Check git log**

```bash
git log --oneline
```

Expected: 6–7 commits from initial to this point, all clean conventional commit messages.
