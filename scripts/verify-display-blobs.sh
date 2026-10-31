#!/bin/bash

set -euo pipefail

VENDOR_DIR="${1:?usage: verify-display-blobs.sh <vendor-directory>}"
READELF="${READELF:-readelf}"

verify_enhance() {
    local relative_path="$1"
    local expected_sha256="$2"
    local blob="$VENDOR_DIR/$relative_path"
    local actual_sha256

    if [ ! -f "$blob" ]; then
        echo "Missing stock display blob: $blob" >&2
        return 1
    fi

    actual_sha256="$(sha256sum "$blob" | awk '{print $1}')"
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        echo "Unexpected stock display blob: $blob" >&2
        echo "  expected SHA-256: $expected_sha256" >&2
        echo "  actual SHA-256:   $actual_sha256" >&2
        return 1
    fi

    if ! "$READELF" -Ws "$blob" | grep -E '[[:space:]]HIDL_FETCH_IEnhance([[:space:]]|$)' >/dev/null; then
        echo "Stock display blob does not export HIDL_FETCH_IEnhance: $blob" >&2
        return 1
    fi
}

verify_factory_blob() {
    local relative_path="$1"
    local expected_sha256="$2"
    local required_symbol="${3:-}"
    local blob="$VENDOR_DIR/$relative_path"
    local actual_sha256

    if [ ! -f "$blob" ]; then
        echo "Missing stock factory blob: $blob" >&2
        return 1
    fi

    actual_sha256="$(sha256sum "$blob" | awk '{print $1}')"
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        echo "Unexpected stock factory blob: $blob" >&2
        echo "  expected SHA-256: $expected_sha256" >&2
        echo "  actual SHA-256:   $actual_sha256" >&2
        return 1
    fi

    if [ -n "$required_symbol" ] && ! "$READELF" -Ws "$blob" | grep -E "[[:space:]]${required_symbol}([[:space:]]|$)" >/dev/null; then
        echo "Stock factory blob does not export $required_symbol: $blob" >&2
        return 1
    fi
}

verify_enhance \
    vendor/lib/hw/vendor.sprd.hardware.enhance@1.0-impl.so \
    59616d23ca1d758daf9e6e263054bded78caacb005da53c91e82d7d39aaf4485
verify_enhance \
    vendor/lib64/hw/vendor.sprd.hardware.enhance@1.0-impl.so \
    7ef1f6bda6c6c79c846aff4f4ead69e9489cb31e2f029c1cfa9f40f2624509d4

verify_factory_blob \
    vendor/lib/hw/vendor.sprd.hardware.cplog_connmgr@1.0-impl.so \
    d7a21127315158f2d165fd6a594afdd986cb80cc2cb3b88f56fb24374ba877eb \
    HIDL_FETCH_IConnectControl
verify_factory_blob \
    vendor/lib64/hw/vendor.sprd.hardware.cplog_connmgr@1.0-impl.so \
    dea489a50068f7b42e68d67196a50962e56b515ec7b1358fca27042f87fbbbb3 \
    HIDL_FETCH_IConnectControl
verify_factory_blob \
    vendor/lib/libTfliteWrapper.so \
    5f83a097d590ec678d80d85e3abdf9660240e1fa4686c0183463b025cac140cf \
    __emutls_get_address
verify_factory_blob \
    vendor/lib64/libTfliteWrapper.so \
    1bd371b9dd423ad31fbaea07b6145c1d65933604fe5d7686c502fdec37537fca \
    __emutls_get_address

echo "Verified stock P22H190 display and camera HAL blobs"
