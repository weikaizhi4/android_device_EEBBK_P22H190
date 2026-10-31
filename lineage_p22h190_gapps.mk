$(call inherit-product, device/eebbk/p22h190/lineage_p22h190.mk)
$(call inherit-product-if-exists, vendor/gapps/arm64/arm64-vendor.mk)

PRODUCT_NAME := lineage_p22h190_gapps
PRODUCT_DEVICE := p22h190
