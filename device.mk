ifneq (,$(filter eng userdebug,$(TARGET_BUILD_VARIANT)))
WITH_ADB_INSECURE := true
endif

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)
$(call inherit-product, vendor/lineage/config/common_full_tablet_wifionly.mk)
$(call inherit-product-if-exists, vendor/eebbk/p22h190/p22h190-vendor.mk)
include vendor/eebbk/p22h190/vndk30.mk
include vendor/eebbk/p22h190/audio.mk

PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_CHARACTERISTICS := tablet
PRODUCT_SHIPPING_API_LEVEL := 30
TARGET_SUPPORTS_OMX_SERVICE := false
PRODUCT_EXTRA_VNDK_VERSIONS += 30
PRODUCT_VENDOR_PROPERTIES += \
    ro.vndk.version=30

PRODUCT_SYSTEM_PROPERTIES += \
    ro.surface_flinger.enable_frame_rate_override=false \
    ro.vendor.camera.preview_srgb=true \
    bluetooth.core.le.vendor_capabilities.enabled=0 \
    bluetooth.le.disable_apcf_extended_features=1

PRODUCT_SYSTEM_PROPERTIES += \
    lineage.updater.uri=https://weikaizhi4.github.io/p22h190-ota/updates/P22H190/UNOFFICIAL.json
PRODUCT_SOONG_NAMESPACES += $(LOCAL_PATH)

PRODUCT_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay

ifneq (,$(filter eng userdebug,$(TARGET_BUILD_VARIANT)))
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    persist.sys.usb.config=adb
endif

PRODUCT_PACKAGES += \
    EEBBK_NetworkStackOverlay \
    EEBBK_NetworkStackOverlayGsi \
    EEBBK_TetheringConfigOverlay \
    EEBBK_TetheringConfigOverlayGsi \
    eebbk_camera_provider_launcher

PRODUCT_PACKAGES += \
    libhwc2on1adapter \
    libhwc2onfbadapter \
    libeebbk_hidl_compat

PRODUCT_COPY_FILES += \
    vendor/eebbk/p22h190/proprietary/vendor/lib64/eebbk-vndk30/bbkbase.so:$(TARGET_COPY_OUT_VENDOR)/lib64/eebbk-vndk30/bbkbase.so \
    vendor/eebbk/p22h190/proprietary/vendor/lib64/eebbk-vndk30/bbkutil.so:$(TARGET_COPY_OUT_VENDOR)/lib64/eebbk-vndk30/bbkutil.so
PRODUCT_PACKAGES -= \
    android.hardware.audio@2.0-service \
    android.hardware.audio.service

PRODUCT_PACKAGES -= \
    android.hardware.health@2.1-impl \
    android.hardware.health@2.1-service

PRODUCT_PACKAGES -= \
    android.hardware.media.omx@1.0-service \
    libavservices_minijail_vendor

PRODUCT_PACKAGES -= \
    libtinyalsa

PRODUCT_COPY_FILES += \
    vendor/eebbk/p22h190/proprietary/vendor/bin/install-recovery.sh:$(TARGET_COPY_OUT_VENDOR)/bin/install-recovery.sh \
    vendor/eebbk/p22h190/proprietary/vendor/etc/recovery.img:$(TARGET_COPY_OUT_VENDOR)/etc/recovery.img

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/init.recovery.ums512_1h190.rc:root/init.recovery.ums512_1h190.rc \
    $(LOCAL_PATH)/recovery/ueventd.ums512_1h190.rc:root/ueventd.ums512_1h190.rc

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/permissions/default-permissions-p22h190.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/default-permissions/default-permissions-p22h190.xml

PRODUCT_PACKAGES += \
    fastbootd \
    fstab.enableswap \
    fstab.ums512_1h190 \
    fstab.ums512_1h190.first_stage

include $(LOCAL_PATH)/vendor_prop.mk
include $(LOCAL_PATH)/fixsymlinks/fixsymlinks.mk
PRODUCT_PACKAGES += p22h190_audio_firmware_links

PRODUCT_PACKAGES := $(filter-out com.android.hardware.cas libclearkeycasplugin \
    android.hardware.cas@1.2-service android.hardware.cas@1.2-service-lazy, \
    $(PRODUCT_PACKAGES))
PRODUCT_PACKAGES_SHIPPING_API_LEVEL_33 := $(filter-out \
    android.hardware.cas@1.2-service,$(PRODUCT_PACKAGES_SHIPPING_API_LEVEL_33))

# Let lmkd know the device has (zram) swap, so it uses swap aware limits.
PRODUCT_PROPERTY_OVERRIDES += ro.config.zram=true
