IPL_SRC=$(ANDROID_BUILD_TOP)/device/renesas/salvator/bootloaders/ipl/
SA_SRC=$(ANDROID_BUILD_TOP)/device/renesas/salvator/bootloaders/ipl/tools/dummy_create
export IPL_OUT=$(ANDROID_BUILD_TOP)/$(TARGET_OUT_INTERMEDIATES)/IPL_OBJ
IPL_COMPILE=$(ANDROID_BUILD_TOP)/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-gnu-5.1/bin/aarch64-linux-gnu-

PLATFORM=rcar
RELEASE=release
USE_MULTIMEDIA=1

ifeq ($(USE_MULTIMEDIA), 1)
export RCAR_LOSSY_ENABLE=1
endif

ifeq ($(TARGET_PRODUCT),salvator_car_h3)
    TARGET_LSI=H3
    export RCAR_DRAM_SPLIT=1
else ifeq ($(TARGET_PRODUCT),salvator_car_m3)
    TARGET_LSI=M3
    export RCAR_DRAM_SPLIT=2
else
    PLATFORM=fvp
endif

$(IPL_OUT):
	$(hide) mkdir -p $(IPL_OUT)

iplclean:
	$(hide) CROSS_COMPILE=$(IPL_COMPILE) make PLAT=$(PLATFORM) LSI=$(TARGET_LSI) -C $(IPL_SRC) O=$(IPL_OUT) distclean

dummy: $(IPL_OUT)
	@echo "Building dymmy"
	$(hide) CROSS_COMPILE=$(IPL_COMPILE) make -C $(SA_SRC) O=$(IPL_OUT) clean
	$(hide) CROSS_COMPILE=$(IPL_COMPILE) make -C $(SA_SRC) O=$(IPL_OUT)
	$(hide) cp $(SA_SRC)/*.bin $(ANDROID_BUILD_TOP)/$(PRODUCT_OUT)/
	$(hide) cp $(SA_SRC)/*.srec $(ANDROID_BUILD_TOP)/$(PRODUCT_OUT)/

ipl: $(IPL_OUT) dummy
	@echo "Building ipl"
	$(hide) CROSS_COMPILE=$(IPL_COMPILE) make PLAT=$(PLATFORM) LSI=$(TARGET_LSI) -C $(IPL_SRC) O=$(IPL_OUT) distclean
	$(hide) CROSS_COMPILE=$(IPL_COMPILE) make -e MAKEFLAGS= PLAT=$(PLATFORM) LSI=$(TARGET_LSI) -C $(IPL_SRC) O=$(IPL_OUT) all
	$(hide) cp $(IPL_OUT)/$(PLATFORM)/$(RELEASE)/*.bin $(ANDROID_BUILD_TOP)/$(PRODUCT_OUT)/
	$(hide) cp $(IPL_OUT)/$(PLATFORM)/$(RELEASE)/*.srec $(ANDROID_BUILD_TOP)/$(PRODUCT_OUT)/

.PHONY: ipl iplclean dummy
