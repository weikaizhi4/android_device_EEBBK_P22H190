#!/bin/bash

set -euo pipefail

MY_DIR="${BASH_SOURCE%/*}"
DEVICE_DIR="$(cd "$MY_DIR/.." && pwd)"
ROOT_DIR="$(cd "$DEVICE_DIR/../../.." && pwd)"
PATCHELF="$ROOT_DIR/prebuilts/extract-tools/linux-x86/bin/patchelf-0_18"
OUTPUT_DIR="$ROOT_DIR/vendor/eebbk/p22h190/proprietary/vendor"

if [ ! -x "$PATCHELF" ]; then
    echo "Missing host patchelf: $PATCHELF" >&2
    exit 1
fi

prepare_arch() {
    local ARCH_DIR="$1"
    local DEST_DIR="$2"
    local RUNTIME_DIR="$3"
    local SOURCE_DIR="$ROOT_DIR/prebuilts/vndk/v30/arm64/$ARCH_DIR/shared"

    mkdir -p "$DEST_DIR"
    cp "$SOURCE_DIR/vndk-sp/libbase.so" "$DEST_DIR/libbase.so"
    "$PATCHELF" --set-soname libbase.so "$DEST_DIR/libbase.so"
    "$PATCHELF" --set-rpath "$RUNTIME_DIR" "$DEST_DIR/libbase.so"

    cp "$SOURCE_DIR/vndk-sp/libcutils.so" "$DEST_DIR/libcutils.so"
    "$PATCHELF" --set-soname libcutils.so "$DEST_DIR/libcutils.so"
    "$PATCHELF" --set-rpath "$RUNTIME_DIR" "$DEST_DIR/libcutils.so"

    cp "$SOURCE_DIR/vndk-core/libbinder.so" "$DEST_DIR/libbinder.so"
    "$PATCHELF" --set-soname libbinder.so "$DEST_DIR/libbinder.so"
    "$PATCHELF" --set-rpath "$RUNTIME_DIR" "$DEST_DIR/libbinder.so"

    cp "$SOURCE_DIR/vndk-core/libssl.so" "$DEST_DIR/libssl.so"
    "$PATCHELF" --set-soname libssl.so "$DEST_DIR/libssl.so"
    "$PATCHELF" --set-rpath "$RUNTIME_DIR" "$DEST_DIR/libssl.so"

    cp "$SOURCE_DIR/vndk-core/libcrypto.so" "$DEST_DIR/libcrypto.so"
    "$PATCHELF" --set-soname libcrypto.so "$DEST_DIR/libcrypto.so"
    "$PATCHELF" --set-rpath "$RUNTIME_DIR" "$DEST_DIR/libcrypto.so"

    cp "$SOURCE_DIR/vndk-core/libui.so" \
        "$DEST_DIR/libeebbk_p22h190_ui.so"
    "$PATCHELF" --set-soname libeebbk_p22h190_ui.so \
        "$DEST_DIR/libeebbk_p22h190_ui.so"
    "$PATCHELF" --set-rpath "$RUNTIME_DIR" \
        "$DEST_DIR/libeebbk_p22h190_ui.so"

    cp "$SOURCE_DIR/vndk-core/libaudioutils.so" \
        "$DEST_DIR/libeebbk_p22h190_audioutils.so"
    "$PATCHELF" --set-soname libeebbk_p22h190_audioutils.so \
        "$DEST_DIR/libeebbk_p22h190_audioutils.so"
    "$PATCHELF" --set-rpath "$RUNTIME_DIR" \
        "$DEST_DIR/libeebbk_p22h190_audioutils.so"

    cp "$SOURCE_DIR/vndk-core/libmedia_helper.so" \
        "$DEST_DIR/libmedia_helper.so"
    "$PATCHELF" --set-soname libmedia_helper.so "$DEST_DIR/libmedia_helper.so"
    "$PATCHELF" --set-rpath "$RUNTIME_DIR" \
        "$DEST_DIR/libmedia_helper.so"
}

prepare_arch arch-arm-armv8-a "$OUTPUT_DIR/lib/eebbk-vndk30" /vendor/lib/eebbk-vndk30
prepare_arch arch-arm64-armv8-a "$OUTPUT_DIR/lib64/eebbk-vndk30" /vendor/lib64/eebbk-vndk30
