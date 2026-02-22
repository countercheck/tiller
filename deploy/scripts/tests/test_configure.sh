#!/usr/bin/env bash
# deploy/scripts/tests/test_configure.sh
# Run from repo root: bash deploy/scripts/tests/test_configure.sh
set -euo pipefail

CONFIGURE="deploy/scripts/configure.sh"
WORKDIR=$(mktemp -d)
trap "rm -rf $WORKDIR" EXIT

pass=0
fail=0

assert_contains() {
    local label="$1" pattern="$2" file="$3"
    if grep -q "$pattern" "$file"; then
        echo "  PASS: $label"
        ((pass++)) || true
    else
        echo "  FAIL: $label — expected '$pattern' not found"
        echo "  File contents:"
        cat "$file" | sed 's/^/    /'
        ((fail++)) || true
    fi
}

assert_not_contains() {
    local label="$1" pattern="$2" file="$3"
    if ! grep -q "$pattern" "$file"; then
        echo "  PASS: $label"
        ((pass++)) || true
    else
        echo "  FAIL: $label — '$pattern' should not be present"
        ((fail++)) || true
    fi
}

echo "--- Test: all placeholders are substituted ---"

cat > "$WORKDIR/test.template" <<'TMPL'
host={{CLIENT_HOSTNAME}}
name={{CLIENT_NAME}}
pass={{DB_PASSWORD}}
prog={{PROGRAM_NAME}}
email={{CONTACT_EMAIL}}
stor={{AZURE_STORAGE_ACCOUNT}}
cont={{AZURE_CONTAINER}}
TMPL

export CLIENT_HOSTNAME="test.example.com"
export CLIENT_NAME="testclient"
export DB_PASSWORD="secret123"
export PROGRAM_NAME="TEST_BARLEY"
export CONTACT_EMAIL="breeder@example.com"
export AZURE_STORAGE_ACCOUNT="teststore"
export AZURE_CONTAINER="test-backups"

bash "$CONFIGURE" "$WORKDIR/test.template" "$WORKDIR/test.output"

assert_contains     "CLIENT_HOSTNAME substituted"    "host=test.example.com"     "$WORKDIR/test.output"
assert_contains     "CLIENT_NAME substituted"        "name=testclient"           "$WORKDIR/test.output"
assert_contains     "DB_PASSWORD substituted"        "pass=secret123"            "$WORKDIR/test.output"
assert_contains     "PROGRAM_NAME substituted"       "prog=TEST_BARLEY"          "$WORKDIR/test.output"
assert_contains     "CONTACT_EMAIL substituted"      "email=breeder@example.com" "$WORKDIR/test.output"
assert_contains     "AZURE_STORAGE_ACCOUNT subst."   "stor=teststore"            "$WORKDIR/test.output"
assert_contains     "AZURE_CONTAINER substituted"    "cont=test-backups"         "$WORKDIR/test.output"
assert_not_contains "No unreplaced placeholders"     "{{"                        "$WORKDIR/test.output"

echo ""
echo "--- Test: missing required variable causes failure ---"

unset DB_PASSWORD
if bash "$CONFIGURE" "$WORKDIR/test.template" "$WORKDIR/test.output2" 2>/dev/null; then
    echo "  FAIL: should have exited non-zero with missing DB_PASSWORD"
    ((fail++)) || true
else
    echo "  PASS: exits non-zero when required variable is missing"
    ((pass++)) || true
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
