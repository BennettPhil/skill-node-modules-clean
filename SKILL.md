---
name: node-modules-clean
description: Finds and optionally deletes node_modules directories to reclaim disk space
version: 0.1.0
license: Apache-2.0
---

# node-modules-clean

Finds all `node_modules` directories under a given path, shows how much space each consumes, and optionally deletes them to reclaim disk space.

## Instructions

When a user wants to clean up node_modules directories:

1. Run `./scripts/run.sh <path>` to scan for node_modules directories (dry-run by default)
2. Review the output showing each directory and its size
3. If the user confirms, run with `--delete` to actually remove them
4. The tool shows a total space reclaimed summary after deletion

## Input Contract

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `path` | positional | no | `$HOME` | Root directory to scan |
| `--delete` | flag | no | false | Actually delete found directories |
| `--min-size` | string | no | `0` | Minimum size to report (e.g., `100M`, `1G`) |
| `--json` | flag | no | false | JSON output |
| `--help` | flag | no | false | Show usage |

## Output Contract

**Dry-run mode** (default): List of node_modules paths with sizes, sorted largest first. Exit code 0.

**Delete mode**: List of deleted paths with sizes and a total reclaimed summary. Exit code 0 on success, 1 on any deletion failure.

**JSON mode**: Array of objects with `path`, `size_bytes`, and `size_human` fields.

## Error Handling

| Error | Exit Code | Message |
|-------|-----------|---------|
| Path does not exist | 1 | `Error: path '<path>' does not exist` |
| No node_modules found | 0 | `No node_modules directories found` |
| Permission denied on delete | 1 | Reports the failed path but continues |
