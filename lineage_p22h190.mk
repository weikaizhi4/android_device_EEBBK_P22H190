LINEAGE_BUILD := P22H190

$(call inherit-product, device/eebbk/p22h190/device.mk)

PRODUCT_BRAND := EEBBK
PRODUCT_DEVICE := p22h190
PRODUCT_MANUFACTURER := EEBBK
PRODUCT_MODEL := A2/X2/X2Pro
PRODUCT_NAME := lineage_p22h190
PRODUCT_RELEASE_NAME := EEBBK_P22H190

PRODUCT_SYSTEM_BRAND := EEBBK
PRODUCT_SYSTEM_DEVICE := P22H190
PRODUCT_SYSTEM_MANUFACTURER := EEBBK
PRODUCT_SYSTEM_MODEL := A2/X2/X2Pro
PRODUCT_SYSTEM_NAME := lineage_P22H190

BUILD_FINGERPRINT := EEBBK/lineage_P22H190/P22H190:$(PLATFORM_VERSION)/$(BUILD_ID)/$(BUILD_NUMBER_FROM_FILE):$(TARGET_BUILD_VARIANT)/$(BUILD_VERSION_TAGS)

PRODUCT_BUILD_PROP_OVERRIDES += \
    TARGET_DEVICE=P22H190 \
    LINEAGE_DEVICE=P22H190 \
    TARGET_PRODUCT=lineage_P22H190 \
    PRODUCT_MODEL=A2/X2/X2Pro

PRODUCT_SYSTEM_PROPERTIES += \
    ro.product.brand=EEBBK \
    ro.product.device=P22H190 \
    ro.product.manufacturer=EEBBK \
    ro.product.model=A2/X2/X2Pro \
    ro.product.name=lineage_P22H190

TARGET_OTA_ASSERT_DEVICE := P22H190

PRODUCT_CHARACTERISTICS := tablet

PRODUCT_PACKAGES := $(filter-out android.hardware.audio@2.0-service android.hardware.audio.service,$(PRODUCT_PACKAGES))

PRODUCT_PACKAGES := $(filter-out android.hardware.graphics.allocator@4.0-service,$(PRODUCT_PACKAGES))

PRODUCT_PACKAGES := $(filter-out android.hardware.graphics.composer@2.1-service,$(PRODUCT_PACKAGES))

PRODUCT_PACKAGES := $(filter-out android.hardware.health@2.1-service,$(PRODUCT_PACKAGES))
PRODUCT_PACKAGES := $(filter-out android.hardware.health@2.1-impl,$(PRODUCT_PACKAGES))

P22H190_FACTORY_REPLACED_PACKAGES := \
    android.hardware.camera.provider@2.4-service \
    android.hardware.camera.provider@2.4-service_64 \
    android.hardware.camera.provider@2.4-service-lazy \
    android.hardware.camera.provider@2.4-service-lazy_64 \
    android.hardware.audio@2.0-service \
    android.hardware.audio.service \
    android.hardware.graphics.allocator@4.0-service \
    android.hardware.graphics.composer@2.1-service \
    gralloc.default \
    android.hardware.health@2.1-service \
    android.hardware.health@2.1-impl \
    android.hardware.media.omx@1.0-service \
    libavservices_minijail_vendor \
    android.hardware.soundtrigger@2.0-impl
PRODUCT_PACKAGES := $(filter-out $(P22H190_FACTORY_REPLACED_PACKAGES),$(PRODUCT_PACKAGES))

PRODUCT_PACKAGES := $(filter-out android.hardware.media.omx@1.0-service,$(PRODUCT_PACKAGES))
PRODUCT_PACKAGES_SHIPPING_API_LEVEL_33 := $(filter-out android.hardware.media.omx@1.0-service,$(PRODUCT_PACKAGES_SHIPPING_API_LEVEL_33))

PRODUCT_PACKAGES := $(filter-out \
    android.hardware.cas@1.2-service \
    android.hardware.cas@1.2-service-lazy \
    com.android.hardware.cas,$(PRODUCT_PACKAGES))
PRODUCT_PACKAGES_SHIPPING_API_LEVEL_33 := $(filter-out \
    android.hardware.cas@1.2-service,$(PRODUCT_PACKAGES_SHIPPING_API_LEVEL_33))
PRODUCT_PACKAGES -= com.android.hardware.cas
PRODUCT_PACKAGES_SHIPPING_API_LEVEL_33 -= android.hardware.cas@1.2-service

PRODUCT_PACKAGES := $(filter-out com.android.hardware.cas libclearkeycasplugin,$(PRODUCT_PACKAGES))
PRODUCT_PACKAGES_SHIPPING_API_LEVEL_33 := $(filter-out android.hardware.cas@1.2-service,$(PRODUCT_PACKAGES_SHIPPING_API_LEVEL_33))
