# node-modules-clean

Finds and optionally deletes node_modules directories to reclaim disk space.

## Quick Start

```bash
# Scan home directory (dry-run)
./scripts/run.sh

# Scan a specific path
./scripts/run.sh /path/to/projects

# Actually delete them
./scripts/run.sh --delete /path/to/projects

# Only show large ones
./scripts/run.sh --min-size 100M
```

## Prerequisites

- Standard Unix tools (find, du, rm)
- bc (for size calculations)
