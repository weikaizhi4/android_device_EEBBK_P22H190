#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' 'socko is intentionally not built: P22H190 modules are installed in /vendor/lib/modules.' >&2
printf '%s\n' 'Factory-only modules are patched by scripts/patch-factory-modules.sh during the kernel build.' >&2
exit 1
