#!/usr/bin/env bash
set -euo pipefail

# node-modules-clean: find and delete node_modules directories

TARGET_PATH="${HOME}"
DELETE=false
MIN_SIZE_BYTES=0
OUTPUT_FORMAT="text"

usage() {
  cat <<'EOF'
Usage: node-modules-clean [OPTIONS] [path]

Find and optionally delete node_modules directories to reclaim disk space.

Options:
  --delete          Actually delete found directories (default: dry-run)
  --min-size <size> Minimum size to report (e.g., 100M, 1G)
  --json            Output as JSON array
  --help            Show this help message

Arguments:
  [path]            Root directory to scan (default: $HOME)

Without --delete, this runs in dry-run mode and only reports what it finds.
EOF
}

parse_size() {
  local size_str="$1"
  local num unit
  num=$(echo "$size_str" | sed 's/[^0-9.]//g')
  unit=$(echo "$size_str" | sed 's/[0-9.]//g' | tr '[:lower:]' '[:upper:]')

  case "$unit" in
    K|KB) echo "$num * 1024" | bc | cut -d. -f1 ;;
    M|MB) echo "$num * 1024 * 1024" | bc | cut -d. -f1 ;;
    G|GB) echo "$num * 1024 * 1024 * 1024" | bc | cut -d. -f1 ;;
    *)    echo "${num:-0}" ;;
  esac
}

human_size() {
  local bytes="$1"
  if [ "$bytes" -ge 1073741824 ]; then
    echo "$(echo "scale=1; $bytes / 1073741824" | bc)G"
  elif [ "$bytes" -ge 1048576 ]; then
    echo "$(echo "scale=1; $bytes / 1048576" | bc)M"
  elif [ "$bytes" -ge 1024 ]; then
    echo "$(echo "scale=1; $bytes / 1024" | bc)K"
  else
    echo "${bytes}B"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --delete)   DELETE=true; shift ;;
    --min-size) MIN_SIZE_BYTES=$(parse_size "$2"); shift 2 ;;
    --json)     OUTPUT_FORMAT="json"; shift ;;
    --help)     usage; exit 0 ;;
    -*)         echo "Error: unknown option '$1'" >&2; exit 1 ;;
    *)          TARGET_PATH="$1"; shift ;;
  esac
done

if [ ! -d "$TARGET_PATH" ]; then
  echo "Error: path '$TARGET_PATH' does not exist" >&2
  exit 1
fi

# Find all node_modules directories (skip nested ones inside other node_modules)
FOUND_DIRS=$(find "$TARGET_PATH" -type d -name "node_modules" -prune 2>/dev/null || true)

if [ -z "$FOUND_DIRS" ]; then
  if [ "$OUTPUT_FORMAT" = "json" ]; then
    echo "[]"
  else
    echo "No node_modules directories found"
  fi
  exit 0
fi

# Calculate sizes and collect results
RESULTS=""
TOTAL_BYTES=0
ERRORS=0

while IFS= read -r dir; do
  [ -z "$dir" ] && continue

  # Get size in bytes
  size_bytes=$(du -sk "$dir" 2>/dev/null | cut -f1 || echo "0")
  size_bytes=$((size_bytes * 1024))

  # Apply min-size filter
  if [ "$size_bytes" -lt "$MIN_SIZE_BYTES" ]; then
    continue
  fi

  size_human=$(human_size "$size_bytes")
  TOTAL_BYTES=$((TOTAL_BYTES + size_bytes))

  if $DELETE; then
    if rm -rf "$dir" 2>/dev/null; then
      RESULTS="${RESULTS}deleted|${dir}|${size_bytes}|${size_human}\n"
    else
      RESULTS="${RESULTS}failed|${dir}|${size_bytes}|${size_human}\n"
      ((ERRORS++)) || true
    fi
  else
    RESULTS="${RESULTS}found|${dir}|${size_bytes}|${size_human}\n"
  fi
done <<< "$FOUND_DIRS"

TOTAL_HUMAN=$(human_size "$TOTAL_BYTES")

# Output
if [ "$OUTPUT_FORMAT" = "json" ]; then
  echo "["
  first=true
  printf '%b' "$RESULTS" | while IFS='|' read -r status path size_bytes size_human; do
    [ -z "$status" ] && continue
    if [ "$first" = "true" ]; then first=false; else echo ","; fi
    printf '  {"status": "%s", "path": "%s", "size_bytes": %s, "size_human": "%s"}' \
      "$status" "$path" "$size_bytes" "$size_human"
  done
  echo ""
  echo "]"
else
  COUNT=$(printf '%b' "$RESULTS" | grep -c '.' || true)

  if $DELETE; then
    printf "%-8s %-10s %s\n" "STATUS" "SIZE" "PATH"
  else
    printf "%-10s %s\n" "SIZE" "PATH"
  fi

  printf '%b' "$RESULTS" | sort -t'|' -k3 -rn | while IFS='|' read -r status path size_bytes size_human; do
    [ -z "$status" ] && continue
    if $DELETE; then
      printf "%-8s %-10s %s\n" "$status" "$size_human" "$path"
    else
      printf "%-10s %s\n" "$size_human" "$path"
    fi
  done

  echo ""
  if $DELETE; then
    echo "Deleted $COUNT directories, reclaimed $TOTAL_HUMAN"
    if [ "$ERRORS" -gt 0 ]; then
      echo "Warning: $ERRORS directories failed to delete (permission denied)"
    fi
  else
    echo "Found $COUNT node_modules directories totaling $TOTAL_HUMAN"
    echo "Run with --delete to remove them"
  fi
fi

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
