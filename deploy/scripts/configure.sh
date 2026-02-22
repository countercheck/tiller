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

# Use | as sed delimiter so hostnames/URLs (containing /) don't break substitution
sed \
    -e "s|{{CLIENT_HOSTNAME}}|${CLIENT_HOSTNAME}|g" \
    -e "s|{{CLIENT_NAME}}|${CLIENT_NAME}|g" \
    -e "s|{{DB_PASSWORD}}|${DB_PASSWORD}|g" \
    -e "s|{{PROGRAM_NAME}}|${PROGRAM_NAME}|g" \
    -e "s|{{CONTACT_EMAIL}}|${CONTACT_EMAIL}|g" \
    -e "s|{{AZURE_STORAGE_ACCOUNT}}|${AZURE_STORAGE_ACCOUNT}|g" \
    -e "s|{{AZURE_CONTAINER}}|${AZURE_CONTAINER}|g" \
    "$SRC" > "$DST"

echo "Configured: $SRC → $DST"
