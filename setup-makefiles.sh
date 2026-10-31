#!/bin/bash

set -e

DEVICE=p22h190
VENDOR=eebbk
MY_DIR="${BASH_SOURCE%/*}"
[ -d "$MY_DIR" ] || MY_DIR="$PWD"
LINEAGE_ROOT="${MY_DIR}/../../.."
HELPER="${LINEAGE_ROOT}/tools/extract-utils/extract_utils.sh"

if [ ! -f "$HELPER" ]; then
    echo "Unable to find helper script at $HELPER"
    exit 1
fi
source "$HELPER"

setup_vendor "$DEVICE" "$VENDOR" "$LINEAGE_ROOT"
write_headers "$DEVICE"
write_makefiles "$MY_DIR/proprietary-files.txt" true
write_makefiles "$MY_DIR/proprietary-files-vendor.txt" true
write_footers
