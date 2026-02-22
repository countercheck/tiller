# CLAUDE.md — Breeding Informatics Platform

This file provides context for AI-assisted development of a challenger breeding information
management system. Read this before any coding, architecture, or design work.

---

## Project Overview

We are building a commercial, hosted breeding information management system (BIMS) to compete
with and replace Genovix — a proprietary system used by a small barley and triticale breeding
program.

**The problem with Genovix:**
- Costs ~$25k CAD/year
- Covers only pedigree and trials — no genomics
- Inflexible, hard-to-read outputs
- Clients don't know what to ask for

**Our goal:** A lower-cost, better-output system built from open-source components, designed
to be repeatable across multiple small breeding programs.

---

## Team

- **Software engineer** architecture, build, deployment, maintenance
- **Senior plant breeder** domain expertise, advisory relationship with the
  initial client, analytical pipeline, report design
- The breeder has an existing trusted advisory relationship with the Edmonton client, which
  is the initial commercial opportunity.

---

## Languages and Tooling Split

The two team members have different language strengths, and the work is divided accordingly.

**Software engineer owns (Python):**
- Deployment tooling and infrastructure-as-code
- Genovix data migration scripts
- BrAPI integration scripts and glue code
- Any custom web layer or automation

**Breeder owns (R):**
- Analytical pipeline (trial analysis, GBLUP, breeding values)
- Quarto report templates
- Shiny dashboard logic
- R helper package for BrAPI queries from the analytical environment

**Rationale:**
- The statistical genetics ecosystem (rrBLUP, sommer, lme4, emmeans, ASReml-R) is R-only
  with no mature Python equivalents — the analytical pipeline must be R
- Migration tooling, BrAPI scripting, and infrastructure work are better suited to Python
  and fall to the software engineer
- This division avoids forcing either person into an uncomfortable language for their domain

**When writing code, default to:**
- Python for anything in the software engineer's domain
- R for anything in the breeder's domain
- If ambiguous, ask before assuming

---

## Business Model

- **Target price:** $10,000–$15,000 CAD/year per client
- **Infrastructure cost target:** ~$1,200 CAD/year per client (Azure B2ms VM)
- **Initial implementation and migration:** Either a modest setup fee (~$3–5k) or a loss
  leader for the first client to establish a reference deployment
- **Repeatability is the strategy:** The first deployment builds the runbook, IaC templates,
  migration tooling, and helper package that make subsequent clients cheaper to onboard
- Each client gets their own VM and isolated deployment (no multi-tenancy for now)

---

## Domain Background

### Breeding Informatics Concepts

A BIMS typically covers:

- **Pedigree component** — tracking germplasm (accessions), crosses, and derivation of new
  lines. Core genealogy of the breeding program.
- **Phenotyping component** — field trials with experimental design (RCBD, alpha-lattice,
  augmented designs), metadata (location, year, design), and trait observations.
- **Genotyping component** — DNA polymorphism data (SNPs), genomic relationship matrices,
  haplotype tracking. Linked to pedigree via genotype identifier.
- **Analytical pipeline** — connects phenotypic and genotypic data. Generates breeding values
  (GBLUP/rrBLUP), runs individual and combined trial analyses.

### Relevant Open Source Tools

| Tool | Role | Notes |
|---|---|---|
| Breedbase (T3 fork) | Core BIMS — pedigree, trials | Maintained by TriticeaeToolbox for cereals |
| Gigwa | Genotyping database | BrAPI compliant, handles VCF/SNP data |
| Field Book | Android app for field data collection | BrAPI compliant, connects to Breedbase |
| QBMS | R package — BrAPI client | Queries Breedbase, Gigwa etc. from R |
| RStudio Server | Browser-based R IDE | For analytical pipeline and power users |
| Quarto | Report generation | R + prose → PDF/HTML/Word |
| R Shiny | Interactive web apps in R | For client-facing dashboards |

---

## Chosen Architecture

### Core Stack

```
[Field Book Android App]
        |
        | BrAPI v1.3
        |
[Breedbase — T3 Fork]  ←——— primary BIMS
[PostgreSQL 12]
        |
        | BrAPI (via QBMS R package)
        |
[RStudio Server]  ←——— analytical pipeline + report development
        |
        ├── [Quarto Reports]  ←——— structured periodic reports (end of season)
        └── [R Shiny App]     ←——— client-facing interactive interface
        
[Gigwa]  ←——— genomics (Phase 3, not immediate)
```

### Key Architectural Decisions

**BrAPI as the integration boundary.** All connections between components go through BrAPI
endpoints, not direct database queries. This keeps the architecture portable — if Breedbase
is replaced later, the analytical layer and reporting layer don't change.

**Breedbase T3 fork, not canonical Breedbase.** The TriticeaeToolbox fork
(github.com/TriticeaeToolbox/breedbase) ships with barley trait ontologies pre-loaded and
helper scripts for setup/update. This is the right starting point for a barley/triticale
program.

**Deployment via Docker Compose.** Two containers: `breedbase_web` (Perl/Catalyst app server)
and `breedbase_db` (PostgreSQL 12). nginx in front for SSL termination. All managed via the
T3 `breedbase` helper script.

**Separate user tiers for R access:**
- *Client breeder* — clean Shiny/Quarto interface, no R required
- *Analyst* — RStudio Server with BrAPI-authenticated R access via helper package
- *Power user (future)* — direct read-only PostgreSQL access as a subsequent feature

---

## R Helper Package

A thin internal R package (to be named) that wraps QBMS and provides opinionated,
pre-built query functions against the Breedbase BrAPI endpoint.

**Purpose:**
- Abstracts BrAPI connection and authentication
- Provides clean functions for common queries (get trials, get germplasm, get observations)
- Becomes a reusable asset across all client deployments (same package, different connection
  strings)
- Serves as the foundation for the analytical pipeline

**Example API:**
```r
con <- bb_connect("https://clientname.ourplatform.ca", token = Sys.getenv("BB_TOKEN"))
trials <- get_trials(con, program = "AB_Barley", year = 2024)
germplasm <- get_germplasm(con, trial = trials$trialDbId[1])
obs <- get_observations(con, trial = trials$trialDbId[1])
```

**Authentication:** BrAPI token auth (Breedbase user account with read permissions).
Credentials stored in `.Renviron` on the RStudio Server instance.

**V2 feature:** Direct read-only PostgreSQL access for power users who need queries that
BrAPI doesn't cleanly expose. Scoped to a read-only DB role. Gated behind a conversation,
not self-serve.

---

## Reporting Layer

The reporting layer is where we differentiate from Genovix. The client's core complaint is
inflexible, hard-to-read outputs. Reports should be opinionated and designed around actual
breeding decisions:

- Which lines to advance this cycle
- Which crosses performed well
- Parent performance summaries
- End-of-season trial summaries for funders/boards

**Two tools, two audiences:**

| Tool | Audience | Use case |
|---|---|---|
| Quarto | Client breeder, funders | Structured periodic reports, PDF/HTML, end of season |
| R Shiny | Client breeder (interactive) | In-season exploration, line comparison, filtering by trial/trait |

**Build order:** Quarto first. It's simpler, closer to scripting, and directly solves the
"bad outputs" problem. Shiny later, once we understand what interactive exploration the
client actually needs.

**Shiny notes:**
- All server-side, pre-written — breeders interact via UI widgets (dropdowns, sliders etc.)
- Use `golem` package for structure if/when Shiny app grows beyond simple scripts
- Open source Shiny Server on the same Azure VM — no need for shinyapps.io or Posit Connect
- Concurrency limitation (one R process per session) is not a concern at this scale

---

## Deployment

### Infrastructure

- **Cloud provider:** Microsoft Azure
- **Region:** Canada Central (Toronto) — data stays in Canada, no hard residency requirement
  but good practice for government-adjacent clients
- **VM size:** B2ms (2 vCPU, 8GB RAM) — ~$90–100 CAD/month, adequate for small programs
- **Per-client isolation:** Separate VM and resource group per client
- **Backups:** Automated pg_dump to Azure Blob Storage on cron
- **DNS:** Subdomain per client (e.g. `clientname.ourplatform.ca`) via Azure DNS
- **SSL:** Let's Encrypt via certbot, managed by nginx
- **Monitoring:** Azure Monitor for VM health alerting

### Repeatable Deployment Assets (to build)

- Bicep or ARM template for VM + networking + storage per client
- Docker Compose file (standardised, parameterised)
- `sgn_local.conf` template for new breeding programs
- nginx config template
- Backup cron script
- Deployment runbook

### Breedbase-Specific Deployment Notes

- Use T3 helper script: `./bin/breedbase setup`, `start`, `stop`, `update`
- First image pull is large (several GB) and slow — expected
- Cold boot of web container takes 3–5 minutes — normal, not a broken deployment
- `sgn_local.conf` configuration is the main complexity — document carefully
- Updates require pulling new Docker image + running DB migration patches via `breedbase update`
- Use bind-mounted directories (not Docker-managed volumes) for PostgreSQL data and uploaded
  files — makes backups straightforward filesystem operations
- Barley Composite Ontology (CO_202) is pre-loaded in the T3 fork
- Triticale traits: use overlapping wheat/barley ontology terms where possible, define custom
  terms for triticale-specific traits

---

## Data Migration (Genovix → Breedbase)

### Status
Waiting for a data dump from the client. Format unknown.

### What to assess when dump arrives

**Pedigree data:**
- Are parents consistently identified by the same identifier?
- How are unknown/unrecorded parents handled?
- How deep do pedigree records go?
- Name variants for the same accession (common in older systems)

**Trial data:**
- Does experimental structure have proper location/year/design metadata, or does that context
  live elsewhere?
- Are trait names consistent across years?

**Format:**
- If clean CSVs → migration tooling is straightforward
- If proprietary DB dump → may require reverse engineering

### Migration approach
1. Map Genovix data model to Breedbase/BrAPI data model before writing any code
2. Identify hard problems early (pedigree consistency is highest risk)
3. Build migration scripts that can be re-run (idempotent)
4. Validate pedigree data with the breeder before committing — this is the irreplaceable asset

---

## Phased Build Plan

### Phase 1 — Match Genovix, better outputs
- Deploy Breedbase T3 on Azure
- Migrate historical pedigree and trial data from Genovix
- Connect Field Book for trial data collection
- Build Quarto report templates around actual breeding decisions
- R helper package v1 (BrAPI auth, core query functions)

### Phase 2 — Interactive reporting and analyst tooling
- RStudio Server deployment
- R Shiny dashboard for in-season exploration
- Analytical pipeline (trial analysis, combined analysis)
- Refine reports based on what client actually uses

### Phase 3 — Genomics
- Deploy Gigwa
- Connect to Breedbase via shared germplasm identifiers
- Extend analytical pipeline: GBLUP, genomic selection, genomic relationship matrix

---

## Tools and Technologies Reference

| Technology | Version/Notes |
|---|---|
| Breedbase | T3 fork — github.com/TriticeaeToolbox/breedbase |
| PostgreSQL | 12 (as per Breedbase Docker image) |
| BrAPI | v1.3 (Breedbase native) — use as integration boundary |
| Docker / Docker Compose | Standard deployment |
| nginx | Reverse proxy + SSL termination |
| R | Analytical pipeline, reporting |
| QBMS | R package — BrAPI client |
| rrBLUP / sommer | R packages — GBLUP and breeding value estimation |
| lme4 + emmeans | R packages — trial analysis |
| Quarto | Report generation |
| R Shiny + golem | Interactive dashboards |
| RStudio Server (open source) | Browser-based R IDE for analysts |
| Gigwa | Genotyping database (Phase 3) |
| Azure (Canada Central) | Cloud hosting |
| Let's Encrypt / certbot | SSL certificates |

---

## Known Limitations and Risks

**Breedbase BrAPI transaction handling.** Breedbase v1.3 does not enforce atomic transactions.
Partial uploads from Field Book with no error messaging have been documented. Mitigation:
design Field Book workflow as offline-first with explicit QC step before committing data.
Do not rely on live multi-user sync.

**Breedbase Perl stack.** Niche technology. Deep debugging requires Perl knowledge or
reliance on the SGN/Cornell community. Operational risk is manageable once running; the
risk is if something breaks at the application layer.

**BrAPI version gap.** Breedbase is v1.3; current standard is v2.1. Newer BrAPPs may target
v2.x. Not an immediate problem for this stack but worth monitoring.

**Genovix migration scope unknown** until data dump is received and assessed.

---

## DeltaBreed — Ruled Out (for now)

DeltaBreed (Breeding Insight / Cornell / USDA-ARS) was assessed and ruled out for this
deployment:
- It is a managed hosted platform administered by Breeding Insight — not self-hostable
- v1.0 was published December 2025 — explicitly an MVP
- Designed for USDA-ARS partner programs; access not available to external Canadian programs

Worth monitoring. If a self-hostable version is released, its fully BrAPI-native v2.1
architecture is cleaner than Breedbase. Potential backend swap candidate in 2–3 years.
