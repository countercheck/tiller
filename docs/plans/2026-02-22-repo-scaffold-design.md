# Repo Scaffold Design

**Date:** 2026-02-22
**Status:** Approved

---

## Decision

Single monorepo, domain-based top-level directories. One tooling config per language at the root.

## Directory Structure

```
tiller/
├── infra/                    # Bicep/ARM templates
│   └── README.md
├── deploy/                   # Docker Compose, nginx, breedbase config, backup cron
│   └── README.md
├── migration/                # Python: Genovix → Breedbase migration
│   └── README.md
├── brapi/                    # Python: BrAPI integration/glue scripts
│   └── README.md
├── r-package/                # R helper package (wraps QBMS)
│   └── README.md
├── pipeline/                 # R analytical pipeline
│   └── README.md
├── reports/                  # Quarto report templates
│   └── README.md
├── shiny/                    # R Shiny dashboard
│   └── README.md
├── docs/                     # Runbooks, architecture notes
│   └── plans/                # Design docs
├── .gitignore                # Python, R, OS artefacts
├── pyproject.toml            # ruff + black config covering all Python dirs
├── .lintr                    # lintr config covering all R files
├── .pre-commit-config.yaml   # ruff, black, lintr hooks
└── CLAUDE.md
```

## Tooling

- **Python linting/formatting:** ruff (lint) + black (format), configured in root `pyproject.toml`, covering `migration/`, `brapi/`, `infra/`
- **R linting:** lintr, configured in root `.lintr`, applies to all R files
- **Pre-commit hooks:** ruff-check, ruff-format, lintr — runs on changed files by extension at commit time

## Deferred

- `renv.lock` — breeder initialises when R work begins
- Python dependencies — added per subdirectory as needed
- CI config — added once tooling config is settled
