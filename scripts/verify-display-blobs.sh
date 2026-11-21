#!/bin/bash

set -euo pipefail

VENDOR_DIR="${1:?usage: verify-display-blobs.sh <vendor-directory>}"
READELF="${READELF:-readelf}"
PATCHELF="${PATCHELF:-patchelf}"

verify_blob() {
    local relative_path="$1"
    local required_symbol="$2"
    local blob="$VENDOR_DIR/$relative_path"
    local rpath

    if [ ! -f "$blob" ]; then
        echo "Missing stock blob: $blob" >&2
        return 1
    fi

    if ! "$READELF" -Ws "$blob" | grep -E "[[:space:]]${required_symbol}([[:space:]]|$)" >/dev/null; then
        echo "Stock blob does not export $required_symbol: $blob" >&2
        return 1
    fi

    rpath="$("$PATCHELF" --print-rpath "$blob" 2>/dev/null || true)"
    if [ -n "$rpath" ]; then
        echo "Stock blob must stay unpatched but carries RUNPATH ${rpath}: $blob" >&2
        return 1
    fi

    printf '  %s %s\n' "$(sha256sum "$blob" | awk '{print $1}')" "$relative_path"
}

verify_blob vendor/lib/hw/vendor.sprd.hardware.enhance@1.0-impl.so HIDL_FETCH_IEnhance
verify_blob vendor/lib64/hw/vendor.sprd.hardware.enhance@1.0-impl.so HIDL_FETCH_IEnhance
verify_blob vendor/lib/hw/vendor.sprd.hardware.cplog_connmgr@1.0-impl.so HIDL_FETCH_IConnectControl
verify_blob vendor/lib64/hw/vendor.sprd.hardware.cplog_connmgr@1.0-impl.so HIDL_FETCH_IConnectControl
verify_blob vendor/lib/libTfliteWrapper.so __emutls_get_address
verify_blob vendor/lib64/libTfliteWrapper.so __emutls_get_address

echo "Verified stock P22H190 display and camera HAL blobs"
