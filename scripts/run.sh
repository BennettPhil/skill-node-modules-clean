#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage: run.sh [DIR] [OPTIONS]

Finds and removes node_modules directories to reclaim disk space.

Options:
  --dry-run     Show what would be deleted without deleting
  --json        Output results as JSON
  --max-depth N Maximum search depth (default: 10)
  --help        Show this help message

Examples:
  run.sh ~                    # clean all node_modules under home
  run.sh ~/Projects --dry-run # preview what would be cleaned
  run.sh . --json             # JSON output
EOF
  exit 0
}

SEARCH_DIR=""
DRY_RUN=false
JSON_OUTPUT=false
MAX_DEPTH=10

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) usage ;;
    --dry-run) DRY_RUN=true; shift ;;
    --json) JSON_OUTPUT=true; shift ;;
    --max-depth) MAX_DEPTH="$2"; shift 2 ;;
    -*)
      echo "Error: Unknown option '$1'" >&2
      exit 1
      ;;
    *)
      SEARCH_DIR="$1"
      shift
      ;;
  esac
done

if [[ -z "$SEARCH_DIR" ]]; then
  echo "Error: Search directory is required. Use --help for usage." >&2
  exit 1
fi

if [[ ! -d "$SEARCH_DIR" ]]; then
  echo "Error: Directory not found: $SEARCH_DIR" >&2
  exit 1
fi

# Find all node_modules directories (skip nested ones)
DIRS=()
while IFS= read -r dir; do
  DIRS+=("$dir")
done < <(find "$SEARCH_DIR" -maxdepth "$MAX_DEPTH" -type d -name "node_modules" -not -path "*/node_modules/*/node_modules" 2>/dev/null || true)

if [[ ${#DIRS[@]} -eq 0 ]]; then
  if [[ "$JSON_OUTPUT" = true ]]; then
    echo '{"found": 0, "total_size": "0B", "directories": []}'
  else
    echo "No node_modules directories found in $SEARCH_DIR"
  fi
  exit 0
fi

# Calculate sizes
TOTAL_BYTES=0
RESULTS=()

for dir in "${DIRS[@]}"; do
  # Get size
  if [[ "$(uname -s)" = "Darwin" ]]; then
    size_bytes=$(du -sk "$dir" 2>/dev/null | awk '{print $1 * 1024}' || echo 0)
  else
    size_bytes=$(du -sb "$dir" 2>/dev/null | awk '{print $1}' || echo 0)
  fi
  TOTAL_BYTES=$((TOTAL_BYTES + size_bytes))

  # Human-readable size
  if [[ $size_bytes -ge 1073741824 ]]; then
    size_human="$(echo "scale=1; $size_bytes / 1073741824" | bc)GB"
  elif [[ $size_bytes -ge 1048576 ]]; then
    size_human="$(echo "scale=1; $size_bytes / 1048576" | bc)MB"
  elif [[ $size_bytes -ge 1024 ]]; then
    size_human="$(echo "scale=0; $size_bytes / 1024" | bc)KB"
  else
    size_human="${size_bytes}B"
  fi

  # Parent project directory
  project_dir=$(dirname "$dir")
  project_name=$(basename "$project_dir")

  RESULTS+=("${dir}|${size_bytes}|${size_human}|${project_name}")
done

# Human-readable total
if [[ $TOTAL_BYTES -ge 1073741824 ]]; then
  total_human="$(echo "scale=2; $TOTAL_BYTES / 1073741824" | bc)GB"
elif [[ $TOTAL_BYTES -ge 1048576 ]]; then
  total_human="$(echo "scale=1; $TOTAL_BYTES / 1048576" | bc)MB"
else
  total_human="$(echo "scale=0; $TOTAL_BYTES / 1024" | bc)KB"
fi

if [[ "$JSON_OUTPUT" = true ]]; then
  echo "{"
  echo "  \"found\": ${#DIRS[@]},"
  echo "  \"total_size\": \"$total_human\","
  echo "  \"dry_run\": $DRY_RUN,"
  echo "  \"directories\": ["
  first=true
  for entry in "${RESULTS[@]}"; do
    IFS='|' read -r dir size_bytes size_human project_name <<< "$entry"
    if [[ "$first" = true ]]; then first=false; else echo ","; fi
    printf '    {"path": "%s", "size": "%s", "project": "%s"}' "$dir" "$size_human" "$project_name"
  done
  echo ""
  echo "  ]"
  echo "}"
else
  echo "Found ${#DIRS[@]} node_modules directories (${total_human} total):"
  echo ""
  for entry in "${RESULTS[@]}"; do
    IFS='|' read -r dir size_bytes size_human project_name <<< "$entry"
    echo "  ${size_human}  ${project_name}/node_modules"
  done
  echo ""

  if [[ "$DRY_RUN" = true ]]; then
    echo "Dry run — no files deleted. Run without --dry-run to clean up."
  else
    echo "Deleting..."
    for dir in "${DIRS[@]}"; do
      rm -rf "$dir"
      echo "  Deleted: $dir"
    done
    echo ""
    echo "Reclaimed ${total_human} of disk space!"
  fi
fi
