---
name: node-modules-clean
description: Finds and removes node_modules directories to reclaim disk space, with dry-run preview and size reporting.
version: 0.1.0
license: Apache-2.0
---

# Node Modules Clean

## Purpose

Find all `node_modules` directories under a given path and optionally delete them to reclaim disk space. Shows sizes per project so you can see where your disk space went. Supports dry-run mode to preview before deleting.

## Quick Start

```bash
$ ./scripts/run.sh ~/Projects --dry-run
Found 5 node_modules directories (2.3GB total):

  450MB  my-app/node_modules
  380MB  dashboard/node_modules
  ...

Dry run — no files deleted.
```

## Usage Examples

### Preview (Dry Run)

```bash
$ ./scripts/run.sh ~ --dry-run
```

### Actually Delete

```bash
$ ./scripts/run.sh ~/Projects
```

### JSON Output

```bash
$ ./scripts/run.sh . --json --dry-run
```

## Options Reference

| Flag          | Default | Description                     |
|---------------|---------|---------------------------------|
| `--dry-run`   | false   | Preview without deleting        |
| `--json`      | false   | Output as JSON                  |
| `--max-depth` | 10      | Maximum search depth            |
| `--help`      |         | Show usage                      |

## Error Handling

| Exit Code | Meaning            |
|-----------|--------------------|
| 0         | Success            |
| 1         | Usage/input error  |

## Validation

Run `scripts/test.sh` — 6 assertions.
