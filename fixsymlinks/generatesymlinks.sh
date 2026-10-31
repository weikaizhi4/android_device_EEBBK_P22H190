#!/bin/bash

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
PRODUCT_OUT="${ROOT_DIR}/out/target/product/p22h190"
PREBUILT_DIR="${ROOT_DIR}/device/eebbk/p22h190/prebuilt"

mkdir -p "${PRODUCT_OUT}"
install -m 0644 "${PREBUILT_DIR}/dtb" "${PRODUCT_OUT}/dtb.img"
# Keep a raw copy available for recovery/packaging helpers.  The board config
# also points the normal image rule at this same factory input.
install -m 0644 "${PREBUILT_DIR}/dtbo.img" "${PRODUCT_OUT}/dtbo.img"

VENDOR_OUT="${PRODUCT_OUT}/vendor"
mkdir -p "${VENDOR_OUT}/firmware" "${VENDOR_OUT}/lib/hw" \
    "${VENDOR_OUT}/lib64/hw" "${VENDOR_OUT}/lib/npidevice"

ln -sfn /data/vendor/local/media/audio_params/audio_structure \
    "${VENDOR_OUT}/firmware/audio_structure"
ln -sfn /data/vendor/local/media/audio_params/cvs \
    "${VENDOR_OUT}/firmware/cvs"
ln -sfn /data/vendor/local/media/audio_params/dsp_smartamp \
    "${VENDOR_OUT}/firmware/dsp_smartamp"
ln -sfn /data/vendor/local/media/audio_params/dsp_vbc \
    "${VENDOR_OUT}/firmware/dsp_vbc"
ln -sfn ../egl/libGLES_mali.so "${VENDOR_OUT}/lib/hw/vulkan.ums512.so"
ln -sfn ../egl/libGLES_mali.so "${VENDOR_OUT}/lib64/hw/vulkan.ums512.so"
ln -sfn ./hw/enhance.ums512.so "${VENDOR_OUT}/lib/enhance.ums512.so"
ln -sfn ./hw/enhance.ums512.so "${VENDOR_OUT}/lib64/enhance.ums512.so"
ln -sfn /vendor/lib/libaudionpi.so "${VENDOR_OUT}/lib/npidevice/libaudionpi.so"
ln -sfn /vendor/lib/libcamcalitest.so "${VENDOR_OUT}/lib/npidevice/libcamcalitest.so"
ln -sfn /vendor/lib/libcustomnpi.so "${VENDOR_OUT}/lib/npidevice/libcustomnpi.so"
ln -sfn /vendor/lib/libnpi_rtc.so "${VENDOR_OUT}/lib/npidevice/libnpi_rtc.so"
ln -sfn /vendor/lib/libsensornpi.so "${VENDOR_OUT}/lib/npidevice/libsensornpi.so"
