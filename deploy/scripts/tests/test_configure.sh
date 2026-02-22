#!/usr/bin/env bash
# deploy/scripts/tests/test_configure.sh
# Run from any directory — the script self-locates.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGURE="$SCRIPT_DIR/../configure.sh"
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

pass=0
fail=0

assert_contains() {
    local label="$1" pattern="$2" file="$3"
    if grep -q "$pattern" "$file"; then
        echo "  PASS: $label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $label — expected '$pattern' not found"
        echo "  File contents:"
        sed 's/^/    /' "$file"
        fail=$((fail + 1))
    fi
}

assert_not_contains() {
    local label="$1" pattern="$2" file="$3"
    if ! grep -q "$pattern" "$file"; then
        echo "  PASS: $label"
        pass=$((pass + 1))
    else
        echo "  FAIL: $label — '$pattern' should not be present"
        fail=$((fail + 1))
    fi
}

assert_fails() {
    local label="$1"
    shift
    if "$@" 2>/dev/null; then
        echo "  FAIL: $label — expected non-zero exit"
        fail=$((fail + 1))
    else
        echo "  PASS: $label"
        pass=$((pass + 1))
    fi
}

echo "--- Test: all placeholders are substituted ---"

cat > "$WORKDIR/test.template" <<'TMPL'
host={{CLIENT_HOSTNAME}}
name={{CLIENT_NAME}}
pass={{DB_PASSWORD}}
email={{CONTACT_EMAIL}}
TMPL

export CLIENT_HOSTNAME="test.example.com"
export CLIENT_NAME="testclient"
export DB_PASSWORD="secret123"
export CONTACT_EMAIL="breeder@example.com"

bash "$CONFIGURE" "$WORKDIR/test.template" "$WORKDIR/test.output"

assert_contains     "CLIENT_HOSTNAME substituted"    "host=test.example.com"     "$WORKDIR/test.output"
assert_contains     "CLIENT_NAME substituted"        "name=testclient"           "$WORKDIR/test.output"
assert_contains     "DB_PASSWORD substituted"        "pass=secret123"            "$WORKDIR/test.output"
assert_contains     "CONTACT_EMAIL substituted"      "email=breeder@example.com" "$WORKDIR/test.output"
assert_not_contains "No unreplaced placeholders"     "{{"                        "$WORKDIR/test.output"

echo ""
echo "--- Test: pipe character in DB_PASSWORD is handled correctly ---"

export DB_PASSWORD="secret|p@ss"
bash "$CONFIGURE" "$WORKDIR/test.template" "$WORKDIR/test.pipe_output"
assert_contains "pipe in DB_PASSWORD substituted correctly" 'pass=secret|p@ss' "$WORKDIR/test.pipe_output"
assert_not_contains "no unreplaced placeholders after pipe test" '{{' "$WORKDIR/test.pipe_output"
export DB_PASSWORD="secret123"

echo ""
echo "--- Test: destination directory is created if missing ---"

bash "$CONFIGURE" "$WORKDIR/test.template" "$WORKDIR/newdir/test.output"
assert_contains "output written to new directory" "host=test.example.com" "$WORKDIR/newdir/test.output"

echo ""
echo "--- Test: missing required variables cause failure ---"

for var in CLIENT_HOSTNAME CLIENT_NAME DB_PASSWORD CONTACT_EMAIL; do
    saved="${!var}"
    unset "$var"
    assert_fails "exits non-zero when $var is missing" bash "$CONFIGURE" "$WORKDIR/test.template" "$WORKDIR/test.fail_output"
    export "$var"="$saved"
done

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
