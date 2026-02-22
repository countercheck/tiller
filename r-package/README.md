# r-package

Internal R helper package wrapping QBMS. Provides opinionated, pre-built query
functions against the Breedbase BrAPI endpoint.

## Purpose

- Abstracts BrAPI connection and authentication
- Provides clean functions for common queries (get_trials, get_germplasm, get_observations)
- Reusable across all client deployments (same package, different connection strings)

## Example usage

```r
con       <- bb_connect("https://clientname.ourplatform.ca", token = Sys.getenv("BB_TOKEN"))
trials    <- get_trials(con, program = "AB_Barley", year = 2024)
germplasm <- get_germplasm(con, trial = trials$trialDbId[1])
obs       <- get_observations(con, trial = trials$trialDbId[1])
```

## Contents (to be added)

Standard R package structure: `DESCRIPTION`, `NAMESPACE`, `R/`, `tests/`
