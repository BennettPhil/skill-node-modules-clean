#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="$SCRIPT_DIR/run.sh"
PASS=0; FAIL=0; TOTAL=0
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  ((TOTAL++))
  if echo "$haystack" | grep -qF -- "$needle"; then
    ((PASS++)); echo "  PASS: $desc"
  else
    ((FAIL++)); echo "  FAIL: $desc (output missing '$needle')"
  fi
}

assert_exit_code() {
  local desc="$1" expected="$2"
  shift 2
  local output
  set +e; output=$("$@" 2>&1); local actual=$?; set -e
  ((TOTAL++))
  if [ "$expected" -eq "$actual" ]; then
    ((PASS++)); echo "  PASS: $desc"
  else
    ((FAIL++)); echo "  FAIL: $desc (expected exit $expected, got $actual)"
  fi
}

# Set up test directories
mkdir -p "$TMPDIR/project1/node_modules/fake-pkg"
echo "test" > "$TMPDIR/project1/node_modules/fake-pkg/index.js"
mkdir -p "$TMPDIR/project2/node_modules/another-pkg"
echo "test" > "$TMPDIR/project2/node_modules/another-pkg/index.js"
mkdir -p "$TMPDIR/project3/src"  # no node_modules

echo "=== Tests for node-modules-clean ==="

echo "Core:"
# Dry run should find node_modules
result=$("$RUN" "$TMPDIR" --dry-run 2>&1 || true)
assert_contains "finds node_modules dirs" "node_modules" "$result"
assert_contains "shows size info" "project" "$result"

# After dry run, dirs should still exist
((TOTAL++))
if [[ -d "$TMPDIR/project1/node_modules" ]]; then
  ((PASS++)); echo "  PASS: dry run doesn't delete"
else
  ((FAIL++)); echo "  FAIL: dry run deleted directories!"
fi

echo "Edge cases:"
# Dir with no node_modules
result=$("$RUN" "$TMPDIR/project3" --dry-run 2>&1 || true)
assert_contains "no node_modules found" "No node_modules" "$result"

echo "Help:"
result=$("$RUN" --help 2>&1)
assert_contains "help works" "Usage:" "$result"

echo "Errors:"
assert_exit_code "missing dir fails" 1 "$RUN" "/nonexistent/path/xyz123"

echo ""
echo "=== Results: $PASS/$TOTAL passed ==="
[ "$FAIL" -eq 0 ] || { echo "BLOCKED: $FAIL test(s) failed"; exit 1; }
