#!/bin/bash

set -euo pipefail

MODULES_INTERMEDIATES="${1:?missing kernel modules staging directory}"
KERNEL_OUT="${2:?missing kernel output directory}"
KERNEL_SRC="${3:?missing kernel source directory}"
OBJCOPY="${4:?missing llvm-objcopy path}"
KERNEL_RELEASE="$(cat "$KERNEL_OUT/include/config/kernel.release")"
MODULE_DIR="$MODULES_INTERMEDIATES/lib/modules/$KERNEL_RELEASE"
PATCHER="$KERNEL_SRC/tools/patch-module-metadata.pl"
FACTORY_DIR="$(cd "$(dirname "$0")/../prebuilt/factory-modules" && pwd -P)"
PERL_BIN="${P22H190_PERL_BIN:-/usr/bin/perl}"

if [[ ! -f "$KERNEL_OUT/Module.symvers" ]]; then
    printf 'error: missing Module.symvers: %s\n' "$KERNEL_OUT/Module.symvers" >&2
    exit 1
fi
if [[ ! -x "$PATCHER" ]]; then
    printf 'error: module metadata patcher not found: %s\n' "$PATCHER" >&2
    exit 1
fi
if [[ ! -x "$PERL_BIN" ]]; then
    printf 'error: Perl interpreter not found: %s\n' "$PERL_BIN" >&2
    exit 1
fi
if [[ -z "$OBJCOPY" || ! -x "$OBJCOPY" ]]; then
    printf 'error: llvm-objcopy is required to patch stock modules\n' >&2
    exit 1
fi

REFERENCE_MODULE="$(find "$MODULE_DIR/kernel" -type f -name '*.ko' -print -quit 2>/dev/null || true)"
if [[ -z "$REFERENCE_MODULE" ]]; then
    printf 'error: no built kernel module found below %s\n' "$MODULE_DIR/kernel" >&2
    exit 1
fi
KERNEL_VERMAGIC="$(PATH=/usr/sbin:/usr/bin:/sbin:/bin modinfo -F vermagic "$REFERENCE_MODULE")"
if [[ -z "$KERNEL_VERMAGIC" ]]; then
    printf 'error: cannot read vermagic from %s\n' "$REFERENCE_MODULE" >&2
    exit 1
fi

STAGE="$(mktemp -d /tmp/p22h190-factory-modules.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE" "$MODULE_DIR"

SOURCE_BUILT_MODULES=(
    flash_ic_sc2703.ko
    incrementalfs.ko
    tcs3430.ko
)

for factory_module in "$FACTORY_DIR"/*.ko; do
    factory_name="$(basename "$factory_module")"
    skip=false
    for built_name in "${SOURCE_BUILT_MODULES[@]}"; do
        if [[ "$factory_name" == "$built_name" ]]; then
            skip=true
            break
        fi
    done
    if $skip; then
        printf 'skipping stock %s (built from source)\n' "$factory_name"
        continue
    fi
    cp "$factory_module" "$STAGE"/
done

for built_name in "${SOURCE_BUILT_MODULES[@]}"; do
    if [[ -e "$MODULE_DIR/$built_name" ]]; then
        rm -f "$MODULE_DIR/$built_name"
        printf 'removed stale stock %s (built from source)\n' "$built_name"
    fi
done

if ! compgen -G "$STAGE/*.ko" > /dev/null; then
    printf 'no stock modules left to patch for %s\n' "$KERNEL_RELEASE"
    exit 0
fi

PATH=/usr/sbin:/usr/bin:/sbin:/bin "$PERL_BIN" "$PATCHER" "$KERNEL_OUT/Module.symvers" "$KERNEL_VERMAGIC" "$OBJCOPY" \
    "$STAGE"/*.ko
cp -f "$STAGE"/*.ko "$MODULE_DIR"/

printf 'installed patched stock modules for %s:\n' "$KERNEL_RELEASE"
printf 'vermagic: %s\n' "$KERNEL_VERMAGIC"
printf '  %s\n' "$STAGE"/*.ko | sed "s#^$STAGE/##"
