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

function p22_replace_needed() {
    local OLD="$1"
    local NEW="$2"
    local BLOB="$3"

    if "$PATCHELF" --print-needed "$BLOB" | grep -Fqx "$OLD"; then
        "$PATCHELF" --replace-needed "$OLD" "$NEW" "$BLOB"
    fi
}

function p22_set_soname() {
    local NAME="$1"
    local BLOB="$2"

    if [ "$("$PATCHELF" --print-soname "$BLOB" 2>/dev/null)" = "$NAME" ]; then
        return 0
    fi

    "$PATCHELF" --set-soname "$NAME" "$BLOB"
}

function p22_add_needed() {
    local LIB="$1"
    local BLOB="$2"

    if "$PATCHELF" --print-needed "$BLOB" | grep -Fqx "$LIB"; then
        return 0
    fi

    "$PATCHELF" --add-needed "$LIB" "$BLOB"
}

function p22_set_legacy_rpath() {
    local SOURCE="$1"
    local BLOB="$2"
    local RPATH

    case "$SOURCE" in
        vendor/lib64/*) RPATH=/vendor/lib64/eebbk-vndk30 ;;
        vendor/lib/*) RPATH=/vendor/lib/eebbk-vndk30 ;;
        vendor/bin/*)
            if file "$BLOB" | grep -q 'ELF 64-bit'; then
                RPATH=/vendor/lib64/eebbk-vndk30
            else
                RPATH=/vendor/lib/eebbk-vndk30
            fi
            ;;
        *) return 0 ;;
    esac

    if [ "$("$PATCHELF" --print-rpath "$BLOB")" = "$RPATH" ]; then
        return 0
    fi

    "$PATCHELF" --set-rpath "$RPATH" "$BLOB"
}

function p22_patch_mali_dataspace() {
    python3 "${MY_DIR}/scripts/patch-mali-dataspace.py" "$1"
}

function p21_socko_to_vendor_modules() {
    local SOURCE="$1"
    local BLOB="$2"

    case "$SOURCE" in
        vendor/bin/init.bbk.post_fs.sh|\
        vendor/etc/init/camera.rc|\
        vendor/etc/init/wcn.rc|\
        vendor/etc/init/init.md.rc|\
        vendor/etc/init/init.sprd_flash.rc|\
        vendor/etc/init/init.sprd_vdsp.rc|\
        vendor/etc/init/init.leddrv.rc|\
        vendor/etc/init/init.vibdrv.rc|\
        vendor/etc/init/factorytest.rc|\
        vendor/etc/init/hw/init.factorytest.rc)
            sed -i \
                -e 's|/mnt/vendor/socko/|/vendor/lib/modules/|g' \
                -e 's|\${ro\.vendor\.ko\.mount\.point}/socko/|/vendor/lib/modules/|g' \
                "$BLOB"
            sed -i -E \
                '/insmod[[:space:]]+[^[:space:]]*\/(flash_ic_sy7807|flash_ic_sc2720|flash_ic_sc2721|flash_ic_wd3124da|flash_ic_wd3610da|flash_ic_aw3641|akm4377)\.ko/d' \
                "$BLOB"
            ;;
    esac
}

function blob_fixup() {
    local BLOB="$2"

    case "$1" in
        vendor/etc/init/eebbk.graphics.composer-service.rc)
            sed -i \
                's|/vendor/bin/hw/android\.hardware\.graphics\.composer@2\.1-service|/vendor/bin/hw/eebbk.graphics.composer-service|' \
                "$BLOB"
            ;;
        vendor/etc/init/refnotify.rc)
            if ! grep -q '^    disabled$' "$BLOB"; then
                sed -i '/^service vendor\.refnotify /a\    disabled' "$BLOB"
            fi
            ;;
        vendor/etc/init/vendor.sprd.hardware.thermal@2.0-service.rc)
            if ! grep -q '^    disabled$' "$BLOB"; then
                sed -i '/^service vendor\.thermal-hal-2-0 /a\    disabled' "$BLOB"
            fi
            ;;
        vendor/lib/hw/audio.bluetooth.ums512.so)
            cp "${LINEAGE_ROOT}/vendor/${VENDOR}/${DEVICE}/audio/lib/hw/audio.bluetooth.ums512.so" \
                "$BLOB"
            ;;
        vendor/lib64/hw/audio.bluetooth.ums512.so)
            cp "${LINEAGE_ROOT}/vendor/${VENDOR}/${DEVICE}/audio/lib64/hw/audio.bluetooth.ums512.so" \
                "$BLOB"
            ;;
        vendor/lib64/android.hardware.audio.common-util.so|\
        vendor/lib64/android.hardware.audio.common@6.0-util.so)
            cp "${LINEAGE_ROOT}/vendor/${VENDOR}/${DEVICE}/audio/lib64/${1##*/}" \
                "$BLOB"
            ;;
        vendor/etc/primary_audio_policy_configuration.xml)
            cp "${LINEAGE_ROOT}/vendor/${VENDOR}/${DEVICE}/audio/config/primary_audio_policy_configuration.xml" \
                "$BLOB"
            ;;
        vendor/etc/primary_audio_policy_configuration_smart_pa.xml|\
        vendor/etc/audio/sku_sprd/primary_audio_policy_configuration.xml|\
        vendor/etc/audio/sku_sprd/primary_audio_policy_configuration_smart_pa.xml|\
        vendor/etc/audio/sku_sprd/audio_policy_configuration.xml|\
        vendor/etc/audio/sku_sprd/audio_policy_configuration_a2dp_offload_disabled.xml)
            python3 "${MY_DIR}/scripts/patch-audio-policy-backmic.py" "$BLOB"
            ;;
        vendor/etc/audio_pcm.xml)
            cp "${LINEAGE_ROOT}/vendor/${VENDOR}/${DEVICE}/audio/config/audio_pcm.xml" "$BLOB"
            ;;
        vendor/bin/hw/eebbk.graphics.composer-service)
            p22_replace_needed android.hardware.graphics.composer@2.1-resources.so \
                libeebbk_p22h190_composer_resources.so "$BLOB"
            p22_add_needed libeebbk_hidl_compat.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/bin/hw/android.hardware.drm@1.3-service.clearkey)
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/etc/init/init.md.rc|vendor/etc/init/camera.rc)
            sed -i \
                's/^on post-fs && property:persist.sys.bootAsyncInsmodModule=false$/on post-fs/' \
                "$BLOB"
            p21_socko_to_vendor_modules "$1" "$BLOB"
            ;;
        vendor/bin/init.bbk.post_fs.sh|\
        vendor/etc/init/camera.rc|\
        vendor/etc/init/wcn.rc|\
        vendor/etc/init/init.md.rc|\
        vendor/etc/init/init.sprd_flash.rc|\
        vendor/etc/init/init.sprd_vdsp.rc|\
        vendor/etc/init/init.leddrv.rc|\
        vendor/etc/init/init.vibdrv.rc|\
        vendor/etc/init/factorytest.rc|\
        vendor/etc/init/hw/init.factorytest.rc)
            p21_socko_to_vendor_modules "$1" "$BLOB"
            ;;
        vendor/lib/libeebbk_p22h190_hidltransport.so|\
        vendor/lib64/libeebbk_p22h190_hidltransport.so)
            p22_set_soname libeebbk_p22h190_hidltransport.so "$BLOB"
            ;;
        vendor/lib/libeebbk_p22h190_hwbinder.so|\
        vendor/lib64/libeebbk_p22h190_hwbinder.so)
            p22_set_soname libeebbk_p22h190_hwbinder.so "$BLOB"
            ;;
        vendor/lib/libeebbk_p22h190_trusty.so|\
        vendor/lib64/libeebbk_p22h190_trusty.so)
            p22_set_soname libeebbk_p22h190_trusty.so "$BLOB"
            ;;
        vendor/lib/libeebbk_p22h190_wpa_client.so)
            p22_set_soname libeebbk_p22h190_wpa_client.so "$BLOB"
            ;;
        vendor/lib/libeebbk_p22h190_drm.so|\
        vendor/lib64/libeebbk_p22h190_drm.so)
            p22_set_soname libeebbk_p22h190_drm.so "$BLOB"
            ;;
        vendor/lib64/libeebbk_p22h190_keymaster4.so)
            p22_set_soname libeebbk_p22h190_keymaster4.so "$BLOB"
            p22_replace_needed libkeymaster_messages.so \
                libeebbk_p22h190_keymaster_messages.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/lib64/libeebbk_p22h190_keymaster41.so)
            p22_set_soname libeebbk_p22h190_keymaster41.so "$BLOB"
            p22_replace_needed libkeymaster4.so \
                libeebbk_p22h190_keymaster4.so "$BLOB"
            p22_replace_needed libkeymaster_messages.so \
                libeebbk_p22h190_keymaster_messages.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/lib64/libeebbk_p22h190_keymaster_messages.so)
            p22_set_soname libeebbk_p22h190_keymaster_messages.so "$BLOB"
            ;;
        vendor/lib64/libeebbk_p22h190_composer_resources.so)
            p22_set_soname libeebbk_p22h190_composer_resources.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/lib64/eebbk-vndk30/libpuresoftkeymasterdevice.so)
            p22_replace_needed libkeymaster_messages.so \
                libeebbk_p22h190_keymaster_messages.so "$BLOB"
            p22_replace_needed libcutils.so \
                libeebbk_p22h190_cutils.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/lib64/eebbk-vndk30/libkeymaster4_1support.so|\
        vendor/lib64/eebbk-vndk30/libkeymaster4support.so|\
        vendor/lib64/eebbk-vndk30/libkeymaster_portable.so|\
        vendor/lib64/eebbk-vndk30/libsoft_attestation_cert.so)
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/bin/factorytest)
            p22_replace_needed libhidltransport.so \
                libeebbk_p22h190_hidltransport.so "$BLOB"
            p22_replace_needed libhwbinder.so \
                libeebbk_p22h190_hwbinder.so "$BLOB"
            p22_replace_needed libwpa_client.so \
                libeebbk_p22h190_wpa_client.so "$BLOB"
            ;;
        vendor/bin/hw/android.hardware.wifi@1.0-service)
            p22_replace_needed libwifi-hal.so \
                libeebbk_p22h190_wifi_hal.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/bin/hw/android.hardware.audio.service|\
        vendor/lib/hw/android.hardware.audio@6.0-impl.so|\
        vendor/lib/hw/android.hardware.audio.effect@6.0-impl.so|\
        vendor/lib64/hw/android.hardware.audio@6.0-impl.so|\
        vendor/lib64/hw/android.hardware.audio.effect@6.0-impl.so)
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/bin/init.bbk.post_fs.sh|\
        vendor/etc/init/camera.rc|\
        vendor/etc/init/wcn.rc|\
        vendor/etc/init/init.md.rc|\
        vendor/etc/init/init.sprd_flash.rc|\
        vendor/etc/init/init.sprd_vdsp.rc|\
        vendor/etc/init/init.leddrv.rc|\
        vendor/etc/init/init.vibdrv.rc|\
        vendor/etc/init/factorytest.rc|\
        vendor/etc/init/hw/init.factorytest.rc)
            sed -i \
                -e 's|/mnt/vendor/socko/|/vendor/lib/modules/|g' \
                -e 's|\${ro\.vendor\.ko\.mount\.point}/socko/|/vendor/lib/modules/|g' \
                "$BLOB"
            sed -i -E \
                '/insmod[[:space:]]+[^[:space:]]*\/(flash_ic_sy7807|flash_ic_sc2720|flash_ic_sc2721|flash_ic_wd3124da|flash_ic_wd3610da|flash_ic_aw3641|akm4377)\.ko/d' \
                "$BLOB"
            ;;
        vendor/bin/hw/android.hardware.memtrack@1.0-service|\
        vendor/bin/hw/vendor.sprd.hardware.broadcastradio@2.0-service|\
        vendor/lib64/hw/android.hardware.memtrack@1.0-impl.so)
            p22_replace_needed libbase.so bbkbase.so "$BLOB"
            p22_add_needed bbkutil.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/bin/hw/android.hardware.health@2.1-service|\
        vendor/lib/hw/android.hardware.health@2.0-impl-2.1.so|\
        vendor/lib64/hw/android.hardware.health@2.0-impl-2.1.so)
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/bin/hw/wpa_supplicant)
            p22_replace_needed libkeystore-wifi-hidl.so \
                libeebbk_p22h190_keystore-wifi-hidl.so "$BLOB"
            p22_replace_needed libkeystore-engine-wifi-hidl.so \
                libeebbk_p22h190_keystore-engine-wifi-hidl.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/lib64/libkeystore-engine-wifi-hidl.so|\
        vendor/lib64/libkeystore-wifi-hidl.so|\
        vendor/lib/libwifi-hal.so)
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/lib64/libeebbk_p22h190_keystore-engine-wifi-hidl.so)
            p22_set_soname libeebbk_p22h190_keystore-engine-wifi-hidl.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/lib64/libeebbk_p22h190_keystore-wifi-hidl.so)
            p22_set_soname libeebbk_p22h190_keystore-wifi-hidl.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/lib64/libeebbk_p22h190_wifi_hal.so)
            python3 "${MY_DIR}/scripts/patch-wifi-module-hal.py" "$BLOB"
            p22_set_soname libeebbk_p22h190_wifi_hal.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/bin/hw/android.hardware.audio.service|\
        vendor/lib/hw/android.hardware.audio@6.0-impl.so|\
        vendor/lib/hw/android.hardware.audio.effect@6.0-impl.so|\
        vendor/lib64/hw/android.hardware.audio@6.0-impl.so|\
        vendor/lib64/hw/android.hardware.audio.effect@6.0-impl.so)
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/lib/hw/audio.r_submix.default.so|\
        vendor/lib64/hw/audio.r_submix.default.so)
            p22_replace_needed libnbaio_mono.so \
                libeebbk_p22h190_nbaio_mono.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/lib/libeebbk_p22h190_nbaio_mono.so|\
        vendor/lib64/libeebbk_p22h190_nbaio_mono.so)
            p22_set_soname libeebbk_p22h190_nbaio_mono.so "$BLOB"
            p22_replace_needed libaudioutils.so \
                libeebbk_p22h190_audioutils.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/bin/hw/vendor.sprd.hardware.network@1.0-service|\
        vendor/lib/libcustomnpi.so|vendor/lib/libsensornpi.so|\
        vendor/lib64/libcustomnpi.so|vendor/lib64/libsensornpi.so)
            p22_replace_needed libhidltransport.so \
                libeebbk_p22h190_hidltransport.so "$BLOB"
            ;;
        vendor/bin/hw/android.hardware.gatekeeper@1.0-service.trusty|\
        vendor/bin/sprdstorageproxyd|vendor/bin/tsupplicant|\
        vendor/lib/libteeproduction.so|vendor/lib/libvsp_ca.so|\
        vendor/lib64/libkernelbootcp.trusty.so|\
        vendor/lib64/libteeproduction.so|vendor/lib64/libvsp_ca.so)
            p22_replace_needed libtrusty.so \
                libeebbk_p22h190_trusty.so "$BLOB"
            ;;
        vendor/lib/npidevice/autotestwifi.so)
            p22_replace_needed libwpa_client.so \
                libeebbk_p22h190_wpa_client.so "$BLOB"
            ;;
        vendor/lib/hw/camera.ums512.so|\
        vendor/lib64/hw/camera.ums512.so)
            p22_replace_needed libui.so \
                libeebbk_p22h190_ui.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/bin/hw/android.hardware.camera.provider@2.4-service)
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/lib/hw/android.hardware.graphics.allocator@4.0-impl-arm.so|\
        vendor/lib/hw/android.hardware.graphics.mapper@4.0-impl-arm.so|vendor/lib/hw/dpu.ums512.so|\
        vendor/lib/hw/gsp.ums512.so|vendor/lib/hw/hwcomposer.ums512.so|\
        vendor/lib/npidevice/PQTune.ums512.so|vendor/lib/npidevice/liblcdnpi.so|\
        vendor/lib64/hw/android.hardware.graphics.allocator@4.0-impl-arm.so|\
        vendor/lib64/hw/android.hardware.graphics.mapper@4.0-impl-arm.so|vendor/lib64/hw/dpu.ums512.so|\
        vendor/lib64/hw/gsp.ums512.so|vendor/lib64/hw/hwcomposer.ums512.so|\
        vendor/lib64/npidevice/PQTune.ums512.so|vendor/lib64/npidevice/liblcdnpi.so)
            p22_replace_needed libdrm.so libeebbk_p22h190_drm.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/lib64/egl/libGLES_mali.so)
            p22_patch_mali_dataspace "$BLOB"
            p22_replace_needed libdrm.so libeebbk_p22h190_drm.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/lib/egl/libGLES_mali.so)
            p22_replace_needed libdrm.so libeebbk_p22h190_drm.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/bin/hw/android.hardware.keymaster@4.1-unisoc.service)
            p22_replace_needed libtrusty.so \
                libeebbk_p22h190_trusty.so "$BLOB"
            p22_replace_needed libkeymaster4.so \
                libeebbk_p22h190_keymaster4.so "$BLOB"
            p22_replace_needed libkeymaster41.so \
                libeebbk_p22h190_keymaster41.so "$BLOB"
            p22_replace_needed libkeymaster_messages.so \
                libeebbk_p22h190_keymaster_messages.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/bin/hw/android.hardware.media.omx@1.0-service)
            if [ "$("$PATCHELF" --print-rpath "$BLOB")" != /vendor/lib/eebbk-vndk30 ]; then
                "$PATCHELF" --set-rpath /vendor/lib/eebbk-vndk30 "$BLOB"
            fi
            ;;
        vendor/lib/libavservices_minijail.so)
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
        vendor/bin/thermald)
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
    esac

    case "$1" in
        vendor/bin/hw/hostapd|\
        vendor/bin/hw/android.hardware.usb@1.1-service|\
        vendor/bin/hw/android.hardware.power.stats@1.0-service.mock)
            ;;
        vendor/bin/*|vendor/lib/eebbk-vndk30/*|vendor/lib64/eebbk-vndk30/*)
            p22_set_legacy_rpath "$1" "$BLOB"
            ;;
    esac

    # Kernel modules moved from /vendor/lib/modules to the vendor_dlkm
    # partition. The factory init scripts load them by absolute path, so rewrite
    # those references. Running this twice is harmless: the replacement no
    # longer contains the pattern it matches.
    case "$1" in
        vendor/etc/init/*.rc|vendor/etc/init/hw/*.rc|vendor/bin/*.sh)
            sed -i 's|/vendor/lib/modules/|/vendor_dlkm/lib/modules/|g' "$BLOB"
            ;;
    esac

    case "$1" in
        vendor/etc/bluetooth_audio_policy_configuration_disable_offload.xml|\
        vendor/etc/audio/sku_sprd/bluetooth_audio_policy_configuration_disable_offload.xml|\
        vendor/etc/init/eebbk.graphics.composer-service.rc|\
        vendor/etc/init/init.md.rc|\
        vendor/etc/init/vendor.sprd.hardware.enhance@1.0-service.rc|\
        vendor/etc/media_codecs.xml|\
        vendor/etc/usb_audio_policy_configuration.xml|\
        vendor/etc/vintf/manifest/android.hardware.keymaster@4.1-unisoc.service.xml)
            python3 "${MY_DIR}/scripts/patch-vendor-text.py" "$BLOB"
            ;;
    esac

    if [ "${P22H190_LIBUI_SHIM:-0}" = 1 ] &&
        [ -f "$BLOB" ] && file "$BLOB" | grep -q ELF; then
        if "$PATCHELF" --print-needed "$BLOB" | grep -Fxq libui.so; then
            p22_replace_needed libui.so libeebbk_p22h190_ui.so "$BLOB"
            p22_set_legacy_rpath "$1" "$BLOB"
        fi
    fi
}

CLEAN_VENDOR=true
while [ "$1" != "" ]; do
    case "$1" in
        -n|--no-cleanup) CLEAN_VENDOR=false ;;
        -s|--section) shift; SECTION="$1"; CLEAN_VENDOR=false ;;
        *) SRC="$1" ;;
    esac
    shift
done
[ -n "$SRC" ] || SRC=adb

setup_vendor "$DEVICE" "$VENDOR" "$LINEAGE_ROOT" false "$CLEAN_VENDOR"
extract "$MY_DIR/proprietary-files.txt" "$SRC"
extract "$MY_DIR/proprietary-files-vendor.txt" "$SRC"
PHDR_VENDOR_DIR="$LINEAGE_ROOT/vendor/$VENDOR/$DEVICE/proprietary/vendor"
if [ ! -d "$PHDR_VENDOR_DIR" ]; then
    echo "Unable to find extracted vendor blobs at $PHDR_VENDOR_DIR"
    exit 1
fi
restore_local_artifacts() {
    local repo="$LINEAGE_ROOT/vendor/$VENDOR/$DEVICE"
    local artifact

    git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || return 0

    for artifact in \
        proprietary/vendor/bin/install-recovery.sh \
        proprietary/vendor/etc/recovery.img; do
        if [ ! -e "$repo/$artifact" ]; then
            git -C "$repo" checkout -- "$artifact" 2>/dev/null || true
        fi
    done
}

restore_local_artifacts
python3 "$MY_DIR/scripts/repair-hwcomposer-layout.py" "$PHDR_VENDOR_DIR"
python3 "$MY_DIR/scripts/fix-elf-phdr.py" "$PHDR_VENDOR_DIR"
"$MY_DIR/scripts/prepare-vndk30-compat.sh"
"$MY_DIR/scripts/verify-display-blobs.sh" \
    "$LINEAGE_ROOT/vendor/$VENDOR/$DEVICE/proprietary"
"$MY_DIR/setup-makefiles.sh"
"$MY_DIR/scripts/verify-vndk30-install.sh" \
    "$LINEAGE_ROOT/vendor/$VENDOR/$DEVICE" "$MY_DIR"
