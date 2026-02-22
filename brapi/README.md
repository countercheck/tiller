# brapi

Python glue scripts for BrAPI integration (Breedbase v1.3 endpoints).

Used for bulk operations, data loading, and automation that the R helper package
doesn't cover.

## Contents (to be added)

Scripts are added here as needed. This directory covers BrAPI operations that are
not part of the one-time migration (which lives in `migration/`): bulk data loading,
programmatic data management, and automation against the Breedbase API.

Illustrative examples of what might live here:
- `load_germplasm.py` — bulk-load accession records via BrAPI
- `bulk_upload_trials.py` — programmatic trial creation
- `sync_observations.py` — automated observation record management
