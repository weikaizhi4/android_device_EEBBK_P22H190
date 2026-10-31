#!/bin/bash

set -euo pipefail

VENDOR_DIR="${1:?usage: verify-vndk30-install.sh VENDOR_REPO_DIR DEVICE_REPO_DIR}"
DEVICE_DIR="${2:?usage: verify-vndk30-install.sh VENDOR_REPO_DIR DEVICE_REPO_DIR}"

mapfile -t RULE_FILES < <(
    find "$DEVICE_DIR" -maxdepth 2 \( -name '*.mk' -o -name 'proprietary-files*.txt' \)
    find "$VENDOR_DIR" -maxdepth 1 -name '*.mk'
)

if [ "${#RULE_FILES[@]}" -eq 0 ]; then
    echo "verify-vndk30-install: no install rules found under $DEVICE_DIR" >&2
    exit 1
fi

missing=()
for arch in lib lib64; do
    dir="$VENDOR_DIR/proprietary/vendor/$arch/eebbk-vndk30"
    [ -d "$dir" ] || continue
    while IFS= read -r blob; do
        name="$(basename "$blob")"
        if ! grep -qhF -- "$name" "${RULE_FILES[@]}"; then
            missing+=("$arch/$name")
        fi
    done < <(find "$dir" -maxdepth 1 -type f -name '*.so')
done

if [ "${#missing[@]}" -gt 0 ]; then
    echo "verify-vndk30-install: these VNDK30 blobs are not installed by any rule:" >&2
    printf '  %s\n' "${missing[@]}" >&2
    echo "Add them to vendor/*/*/vndk30.mk (or the blob list) before building." >&2
    exit 1
fi

echo "verify-vndk30-install: all eebbk-vndk30 blobs are referenced by an install rule"
