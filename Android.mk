IPL_SRC=$(ANDROID_BUILD_TOP)/device/renesas/bootloaders/ipl/
SA_SRC=$(ANDROID_BUILD_TOP)/device/renesas/bootloaders/ipl/tools/dummy_create
export IPL_OUT=$(ANDROID_BUILD_TOP)/$(TARGET_OUT_INTERMEDIATES)/IPL_OBJ
IPL_DUMMY_OUT=$(ANDROID_BUILD_TOP)/$(TARGET_OUT_INTERMEDIATES)/IPL_DUMMY_OBJ
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

$(IPL_DUMMY_OUT):
	$(hide) mkdir -p $(IPL_DUMMY_OUT)

iplclean:
	$(hide) CROSS_COMPILE=$(IPL_COMPILE) make PLAT=$(PLATFORM) LSI=$(TARGET_LSI) -C $(IPL_SRC) O=$(IPL_OUT) distclean

dummy: $(IPL_OUT)
	@echo "Building dummy"
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

android_dummy: $(IPL_DUMMY_OUT)
	@echo "Building dummy"
	$(hide) cp -R $(IPL_SRC)/tools/ $(IPL_DUMMY_OUT)
	$(hide) cp -R $(IPL_SRC)/include/ $(IPL_DUMMY_OUT)
	$(hide) CROSS_COMPILE=$(IPL_COMPILE) make -C $(IPL_DUMMY_OUT)/tools/dummy_create clean
	$(hide) CROSS_COMPILE=$(IPL_COMPILE) make CPPFLAGS="-D=AARCH64" -C $(IPL_DUMMY_OUT)/tools/dummy_create

android_ipl: $(IPL_OUT)
	@echo "Building ipl"
	$(hide) CROSS_COMPILE=$(IPL_COMPILE) make IPL_OUT=$(IPL_OUT) RCAR_DRAM_SPLIT=$(RCAR_DRAM_SPLIT) RCAR_LOSSY_ENABLE=$(RCAR_LOSSY_ENABLE) PLAT=$(PLATFORM) LSI=$(TARGET_LSI) -C $(IPL_SRC) distclean
	$(hide) CROSS_COMPILE=$(IPL_COMPILE) make IPL_OUT=$(IPL_OUT) RCAR_DRAM_SPLIT=$(RCAR_DRAM_SPLIT) RCAR_LOSSY_ENABLE=$(RCAR_LOSSY_ENABLE) -e MAKEFLAGS= PLAT=$(PLATFORM) LSI=$(TARGET_LSI) -C $(IPL_SRC) all

.PHONY: ipl iplclean dummy

LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

BOOTPARAM_SA0_BIN_PATH := $(IPL_DUMMY_OUT)/tools/dummy_create/bootparam_sa0.bin
$(BOOTPARAM_SA0_BIN_PATH): android_dummy

LOCAL_MODULE := bootparam_sa0.bin
LOCAL_PREBUILT_MODULE_FILE:= $(BOOTPARAM_SA0_BIN_PATH)
LOCAL_MODULE_PATH := $(ANDROID_BUILD_TOP)/$(PRODUCT_OUT)

include $(BUILD_EXECUTABLE)


include $(CLEAR_VARS)

BOOTPARAM_SA0_SREC_PATH := $(IPL_DUMMY_OUT)/tools/dummy_create/bootparam_sa0.srec
$(BOOTPARAM_SA0_SREC_PATH): android_dummy

LOCAL_MODULE := bootparam_sa0.srec
LOCAL_PREBUILT_MODULE_FILE:= $(BOOTPARAM_SA0_SREC_PATH)
LOCAL_MODULE_PATH := $(ANDROID_BUILD_TOP)/$(PRODUCT_OUT)

include $(BUILD_EXECUTABLE)


include $(CLEAR_VARS)

CERT_HEADER_SA6_BIN_PATH := $(IPL_DUMMY_OUT)/tools/dummy_create/cert_header_sa6.bin
$(CERT_HEADER_SA6_BIN_PATH): android_dummy

LOCAL_MODULE := cert_header_sa6.bin
LOCAL_PREBUILT_MODULE_FILE:= $(CERT_HEADER_SA6_BIN_PATH)
LOCAL_MODULE_PATH := $(ANDROID_BUILD_TOP)/$(PRODUCT_OUT)

include $(BUILD_EXECUTABLE)


include $(CLEAR_VARS)

CERT_HEADER_SA6_SREC_PATH := $(IPL_DUMMY_OUT)/tools/dummy_create/cert_header_sa6.srec
$(CERT_HEADER_SA6_SREC_PATH): android_dummy

LOCAL_MODULE := cert_header_sa6.srec
LOCAL_PREBUILT_MODULE_FILE:= $(CERT_HEADER_SA6_SREC_PATH)
LOCAL_MODULE_PATH := $(ANDROID_BUILD_TOP)/$(PRODUCT_OUT)

include $(BUILD_EXECUTABLE)


include $(CLEAR_VARS)

BL2_BIN := $(IPL_OUT)/$(PLATFORM)/$(RELEASE)/bl2.bin
$(BL2_BIN): android_ipl

LOCAL_MODULE := bl2.bin
LOCAL_PREBUILT_MODULE_FILE:= $(BL2_BIN)
LOCAL_MODULE_PATH := $(ANDROID_BUILD_TOP)/$(PRODUCT_OUT)

include $(BUILD_EXECUTABLE)


include $(CLEAR_VARS)

BL2_SREC := $(IPL_OUT)/$(PLATFORM)/$(RELEASE)/bl2.srec
$(BL2_SREC): android_ipl

LOCAL_MODULE := bl2.srec
LOCAL_PREBUILT_MODULE_FILE:= $(BL2_SREC)
LOCAL_MODULE_PATH := $(ANDROID_BUILD_TOP)/$(PRODUCT_OUT)

include $(BUILD_EXECUTABLE)


include $(CLEAR_VARS)

BL31_BIN := $(IPL_OUT)/$(PLATFORM)/$(RELEASE)/bl31.bin
$(BL31_BIN): android_ipl

LOCAL_MODULE := bl31.bin
LOCAL_PREBUILT_MODULE_FILE:= $(BL31_BIN)
LOCAL_MODULE_PATH := $(ANDROID_BUILD_TOP)/$(PRODUCT_OUT)

include $(BUILD_EXECUTABLE)


include $(CLEAR_VARS)

BL31_SREC := $(IPL_OUT)/$(PLATFORM)/$(RELEASE)/bl31.srec
$(BL31_SREC): android_ipl

LOCAL_MODULE := bl31.srec
LOCAL_PREBUILT_MODULE_FILE:= $(BL31_SREC)
LOCAL_MODULE_PATH := $(ANDROID_BUILD_TOP)/$(PRODUCT_OUT)

include $(BUILD_EXECUTABLE)
