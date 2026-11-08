TARGET_UNOFFICIAL_BUILD_ID := gapps
P22H190_UPDATER_FEED := UNOFFICIAL-gapps.json
P22H190_VARIANT := gapps

$(call inherit-product, device/eebbk/p22h190/lineage_p22h190.mk)
$(call inherit-product-if-exists, vendor/gapps/arm64/arm64-vendor.mk)

PRODUCT_NAME := lineage_p22h190_gapps
PRODUCT_DEVICE := p22h190
