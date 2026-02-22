#!/usr/bin/env bash
# deploy/scripts/backup.sh
# Weekly database backup: pg_dump from breedbase_db container → Azure Blob Storage.
#
# Install as cron job (as root or user with Docker access):
#   0 2 * * 0  CLIENT_NAME=edmonton AZURE_STORAGE_ACCOUNT=tillerbackups \
#              AZURE_CONTAINER=edmonton-backups /path/to/backup.sh
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
BACKUP_FILE="/tmp/breedbase_${CLIENT_NAME}_${TIMESTAMP}.sql.gz"
BLOB_NAME="breedbase_${CLIENT_NAME}_${TIMESTAMP}.sql.gz"

echo "[$(date)] Starting backup for client: ${CLIENT_NAME}"

# Dump database from running container
docker exec breedbase_db \
    pg_dump -U postgres cxgn_hordeum \
    | gzip > "$BACKUP_FILE"

echo "[$(date)] Dump complete: ${BACKUP_FILE}"

# Upload to Azure Blob Storage (uses VM managed identity — no stored credentials)
az storage blob upload \
    --account-name "${AZURE_STORAGE_ACCOUNT}" \
    --container-name "${AZURE_CONTAINER}" \
    --name "${BLOB_NAME}" \
    --file "${BACKUP_FILE}" \
    --auth-mode login \
    --output none

echo "[$(date)] Uploaded: ${BLOB_NAME}"

# Remove local dump
rm "${BACKUP_FILE}"

echo "[$(date)] Backup complete"
