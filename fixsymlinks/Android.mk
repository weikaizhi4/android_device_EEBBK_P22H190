LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := p22h190_audio_firmware_links
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/.p22h190
LOCAL_SRC_FILES := marker
LOCAL_POST_INSTALL_CMD := \
    ln -sf /data/vendor/local/media/audio_params/audio_structure $(TARGET_OUT_VENDOR)/firmware/audio_structure; \
    ln -sf /data/vendor/local/media/audio_params/cvs $(TARGET_OUT_VENDOR)/firmware/cvs; \
    ln -sf /data/vendor/local/media/audio_params/dsp_vbc $(TARGET_OUT_VENDOR)/firmware/dsp_vbc; \
    ln -sf /data/vendor/local/media/audio_params/dsp_smartamp $(TARGET_OUT_VENDOR)/firmware/dsp_smartamp
LOCAL_ALL_SYMLINKS := \
    $(TARGET_OUT_VENDOR)/firmware/audio_structure \
    $(TARGET_OUT_VENDOR)/firmware/cvs \
    $(TARGET_OUT_VENDOR)/firmware/dsp_vbc \
    $(TARGET_OUT_VENDOR)/firmware/dsp_smartamp
ALL_DEFAULT_INSTALLED_MODULES += $(LOCAL_ALL_SYMLINKS)
include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_ALL_SYMLINKS): $(LOCAL_BUILT_MODULE)

$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/marker
	@mkdir -p $(dir $@) $(TARGET_OUT_VENDOR)/firmware
	@cp -f $< $@
