# tiller

Breeding informatics platform. Challenger to Genovix for small barley and triticale
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
