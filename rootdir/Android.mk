LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := fstab.ums512_1h190
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_SRC_FILES := fstab.ums512_1h190
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR_ETC)
LOCAL_REQUIRED_MODULES := fstab.ums512_1h190.first_stage
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := fstab.ums512_1h190.first_stage
LOCAL_MODULE_STEM := fstab.ums512_1h190
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_SRC_FILES := fstab.ums512_1h190.first_stage_ramdisk
LOCAL_MODULE_PATH := $(TARGET_RAMDISK_OUT)
LOCAL_REQUIRED_MODULES := fstab.ums512_1h190.first_stage_ramdisk
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := fstab.ums512_1h190.first_stage_ramdisk
LOCAL_MODULE_STEM := fstab.ums512_1h190
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_SRC_FILES := fstab.ums512_1h190.first_stage_ramdisk
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/first_stage_ramdisk
include $(BUILD_PREBUILT)

# Swap table consumed by the factory "swapon_all" call in init.ram.rc.
include $(CLEAR_VARS)
LOCAL_MODULE := fstab.enableswap
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_SRC_FILES := fstab.enableswap
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR_ETC)
include $(BUILD_PREBUILT)
