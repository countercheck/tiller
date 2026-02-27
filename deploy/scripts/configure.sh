#!/usr/bin/env bash
# deploy/scripts/configure.sh
# Substitutes {{PLACEHOLDER}} values in a template file.
#
# Usage:
#   configure.sh <source_template> <destination_file>
#
# Required environment variables:
#   CLIENT_HOSTNAME  e.g. violet-moose-lantern.ourplatform.ca
#   CLIENT_NAME      e.g. violet-moose-lantern
#   DB_PASSWORD      PostgreSQL password for web_usr
#   CONTACT_EMAIL    admin contact address
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
    CONTACT_EMAIL
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
CONTACT_EMAIL_ESC=$(escape_replacement "$CONTACT_EMAIL")

# Create destination directory if it doesn't exist
DST_DIR=$(dirname "$DST")
mkdir -p "$DST_DIR"

sed \
    -e "s|{{CLIENT_HOSTNAME}}|${CLIENT_HOSTNAME_ESC}|g" \
    -e "s|{{CLIENT_NAME}}|${CLIENT_NAME_ESC}|g" \
    -e "s|{{DB_PASSWORD}}|${DB_PASSWORD_ESC}|g" \
    -e "s|{{CONTACT_EMAIL}}|${CONTACT_EMAIL_ESC}|g" \
    "$SRC" > "$DST"

echo "Configured: $SRC → $DST"
