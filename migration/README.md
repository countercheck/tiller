# migration

Python scripts for migrating historical data from Genovix into Breedbase.

Awaiting data dump from the the initial client. Format unknown.

## Approach

1. Assess dump format and map Genovix model → Breedbase/BrAPI model
2. Write idempotent migration scripts (safe to re-run)
3. Validate pedigree data with the breeder before committing

## Contents (to be added)

- `assess.py` — initial assessment of dump format
- `pedigree.py` — pedigree migration
- `trials.py` — trial data migration
- `validate.py` — post-migration validation
