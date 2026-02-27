#!/usr/bin/env bash
# deploy/scripts/backup.sh
# Weekly database backup: pg_dump from breedbase_db container → Azure Blob Storage.
#
# Install as cron job (as root or user with Docker access):
#   0 2 * * 0  CLIENT_NAME=violet-moose-lantern AZURE_STORAGE_ACCOUNT=tillerbackups \
#              AZURE_CONTAINER=violet-moose-lantern-backups /path/to/backup.sh
#
# Required environment variables:
#   CLIENT_NAME            used in backup filename
#   AZURE_STORAGE_ACCOUNT  Azure storage account name
#   AZURE_CONTAINER        Azure blob container name
#
# Prerequisites:
#   - azure-cli installed and VM has Storage Blob Data Contributor role
#   - breedbase_db container is running
set -euo pipefail

: "${CLIENT_NAME:?CLIENT_NAME is required}"
: "${AZURE_STORAGE_ACCOUNT:?AZURE_STORAGE_ACCOUNT is required}"
: "${AZURE_CONTAINER:?AZURE_CONTAINER is required}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="/tmp/breedbase_${CLIENT_NAME}_${TIMESTAMP}.sql"
BACKUP_FILE="${DUMP_FILE}.gz"
BLOB_NAME="breedbase_${CLIENT_NAME}_${TIMESTAMP}.sql.gz"

# Clean up temp files on any exit (success or failure)
cleanup() { rm -f "$DUMP_FILE" "$BACKUP_FILE"; }
trap cleanup EXIT

echo "[$(date)] Starting backup for client: ${CLIENT_NAME}"

# Verify container is running before attempting dump
if ! docker inspect --format '{{.State.Running}}' breedbase_db 2>/dev/null | grep -q true; then
    echo "[$(date)] ERROR: breedbase_db container is not running" >&2
    exit 1
fi

# Dump database to a temp file first (not piped — detects partial dumps correctly)
# Uses postgres superuser: web_usr lacks DUMP privileges; postgres has trust auth in the container
docker exec breedbase_db pg_dump -U postgres cxgn_hordeum > "$DUMP_FILE"
chmod 600 "$DUMP_FILE"

echo "[$(date)] Dump complete: ${DUMP_FILE}"

# Compress the verified dump
gzip "$DUMP_FILE"

echo "[$(date)] Compressed: ${BACKUP_FILE}"

# Upload to Azure Blob Storage (uses VM managed identity — no stored credentials)
az storage blob upload \
    --account-name "${AZURE_STORAGE_ACCOUNT}" \
    --container-name "${AZURE_CONTAINER}" \
    --name "${BLOB_NAME}" \
    --file "${BACKUP_FILE}" \
    --auth-mode login \
    --output none

echo "[$(date)] Uploaded: ${BLOB_NAME}"

echo "[$(date)] Backup complete"
