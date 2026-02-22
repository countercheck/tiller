#!/usr/bin/env bash
# deploy/scripts/configure.sh
# Substitutes {{PLACEHOLDER}} values in a template file.
#
# Usage:
#   configure.sh <source_template> <destination_file>
#
# Required environment variables:
#   CLIENT_HOSTNAME        e.g. edmonton.ourplatform.ca
#   CLIENT_NAME            e.g. edmonton
#   DB_PASSWORD            PostgreSQL password for web_usr
#   PROGRAM_NAME           e.g. AB_Barley (used in future templates)
#   CONTACT_EMAIL          admin contact address
#   AZURE_STORAGE_ACCOUNT  Azure storage account name
#   AZURE_CONTAINER        Azure blob container name
set -euo pipefail

usage() {
    echo "Usage: $0 <source_template> <destination_file>" >&2
    exit 1
}

[[ $# -eq 2 ]] || usage

SRC="$1"
DST="$2"

[[ -f "$SRC" ]] || { echo "Error: template not found: $SRC" >&2; exit 1; }

# Verify all required variables are set
required_vars=(
    CLIENT_HOSTNAME
    CLIENT_NAME
    DB_PASSWORD
    PROGRAM_NAME
    CONTACT_EMAIL
    AZURE_STORAGE_ACCOUNT
    AZURE_CONTAINER
)

for var in "${required_vars[@]}"; do
    [[ -n "${!var:-}" ]] || { echo "Error: required variable $var is not set" >&2; exit 1; }
done

# Escape characters that are special in a sed replacement expression (\, &, and the | delimiter)
escape_replacement() {
    printf '%s' "$1" | sed 's/[\\|&]/\\&/g'
}

CLIENT_HOSTNAME_ESC=$(escape_replacement "$CLIENT_HOSTNAME")
CLIENT_NAME_ESC=$(escape_replacement "$CLIENT_NAME")
DB_PASSWORD_ESC=$(escape_replacement "$DB_PASSWORD")
PROGRAM_NAME_ESC=$(escape_replacement "$PROGRAM_NAME")
CONTACT_EMAIL_ESC=$(escape_replacement "$CONTACT_EMAIL")
AZURE_STORAGE_ACCOUNT_ESC=$(escape_replacement "$AZURE_STORAGE_ACCOUNT")
AZURE_CONTAINER_ESC=$(escape_replacement "$AZURE_CONTAINER")

# Create destination directory if it doesn't exist
DST_DIR=$(dirname "$DST")
mkdir -p "$DST_DIR"

sed \
    -e "s|{{CLIENT_HOSTNAME}}|${CLIENT_HOSTNAME_ESC}|g" \
    -e "s|{{CLIENT_NAME}}|${CLIENT_NAME_ESC}|g" \
    -e "s|{{DB_PASSWORD}}|${DB_PASSWORD_ESC}|g" \
    -e "s|{{PROGRAM_NAME}}|${PROGRAM_NAME_ESC}|g" \
    -e "s|{{CONTACT_EMAIL}}|${CONTACT_EMAIL_ESC}|g" \
    -e "s|{{AZURE_STORAGE_ACCOUNT}}|${AZURE_STORAGE_ACCOUNT_ESC}|g" \
    -e "s|{{AZURE_CONTAINER}}|${AZURE_CONTAINER_ESC}|g" \
    "$SRC" > "$DST"

echo "Configured: $SRC → $DST"
