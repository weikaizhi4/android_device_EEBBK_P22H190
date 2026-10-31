$(INSTALLED_DTBIMAGE_TARGET): $(DEVICE_PATH)/prebuilt/dtb
	@mkdir -p $(dir $@)
	cp $< $@
