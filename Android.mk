#
# Copyright (C) 2011 The Android Open-Source Project
# Copyright (C) 2018 GlobalLogic
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

PRODUCT_OUT_ABS := $(abspath $(PRODUCT_OUT))

IPL_SRC       := $(abspath ./device/renesas/bootloaders/ipl/)
IPL_SA_SRC    := $(abspath ./device/renesas/bootloaders/ipl/tools/dummy_create)
IPL_OUT       := $(PRODUCT_OUT_ABS)/obj/IPL_OBJ
IPL_DUMMY_OUT := $(PRODUCT_OUT_ABS)/obj/IPL_DUMMY_OBJ
IPL_DUMMY_HF_OUT := $(PRODUCT_OUT_ABS)/obj/IPL_DUMMY_HF_OBJ
IPL_CROSS_COMPILE := $(abspath ./prebuilts/gcc/linux-x86/aarch64/aarch64-linux-gnu/bin/aarch64-linux-gnu-)

BUILD=release
USE_MULTIMEDIA=1

PLATFORM_FLAGS = \
    PLAT=rcar \
    PSCI_DISABLE_BIGLITTLE_IN_CA57BOOT=0

ifeq ($(H3_OPTION),4GB2x2)
PLATFORM_FLAGS += \
    LSI=H3N \
    RCAR_DRAM_SPLIT=2
else
PLATFORM_FLAGS += \
    LSI=AUTO \
    RCAR_DRAM_SPLIT=3
endif

ifeq ($(TARGET_PRODUCT),ulcb)
PLATFORM_FLAGS += \
    RCAR_GEN3_ULCB=1 \
    PMIC_LEVEL_MODE=0
endif

ifeq ($(TARGET_PRODUCT),kingfisher)
PLATFORM_FLAGS += \
    RCAR_GEN3_ULCB=1 \
    PMIC_LEVEL_MODE=0
endif

ifeq ($(H3_OPTION),8GB)
PLATFORM_FLAGS += \
    RCAR_DRAM_CHANNEL=15 \
    RCAR_DRAM_LPDDR4_MEMCONF=1
else
ifeq ($(H3_OPTION),4GB)
PLATFORM_FLAGS += \
    RCAR_DRAM_LPDDR4_MEMCONF=0
else
ifeq ($(H3_OPTION),4GB2x2)
PLATFORM_FLAGS += \
    RCAR_DRAM_CHANNEL=5 \
    RCAR_DRAM_LPDDR4_MEMCONF=1
else
PLATFORM_FLAGS += \
    RCAR_DRAM_LPDDR4_MEMCONF=3
endif
endif
endif

ifeq ($(USE_MULTIMEDIA), 1)
export RCAR_LOSSY_ENABLE=1
endif

$(IPL_OUT):
	$(hide) mkdir -p $(IPL_OUT)

$(IPL_DUMMY_OUT):
	$(hide) mkdir -p $(IPL_DUMMY_OUT)

$(IPL_DUMMY_HF_OUT):
	$(hide) mkdir -p $(IPL_DUMMY_HF_OUT)

iplclean:
	CROSS_COMPILE=$(IPL_CROSS_COMPILE) make $(PLATFORM_FLAGS) -C $(IPL_SRC) O=$(IPL_OUT) distclean

dummy: $(IPL_OUT)
	@echo "Building dummy"
	$(hide) CROSS_COMPILE=$(IPL_CROSS_COMPILE) make $(PLATFORM_FLAGS) -C $(SA_SRC) O=$(IPL_OUT) clean
	$(hide) CROSS_COMPILE=$(IPL_CROSS_COMPILE) make $(PLATFORM_FLAGS) -C $(SA_SRC) O=$(IPL_OUT)
	$(hide) cp $(SA_SRC)/*.bin $(PRODUCT_OUT_ABS)/
	$(hide) cp $(SA_SRC)/*.srec $(PRODUCT_OUT_ABS)/

ipl: $(IPL_OUT) dummy
	@echo "Building ipl"
	$(hide) CROSS_COMPILE=$(IPL_CROSS_COMPILE) make $(PLATFORM_FLAGS) -C $(IPL_SRC) O=$(IPL_OUT) distclean
	$(hide) CROSS_COMPILE=$(IPL_CROSS_COMPILE) make -e MAKEFLAGS= $(PLATFORM_FLAGS) -C $(IPL_SRC) O=$(IPL_OUT) all
	$(hide) cp $(IPL_OUT)/rcar/release/*.bin $(PRODUCT_OUT_ABS)/
	$(hide) cp $(IPL_OUT)/rcar/release/*.srec $(PRODUCT_OUT_ABS)/

android_dummy: $(IPL_DUMMY_OUT)
	@echo "Building dummy"
	$(hide) cp -R $(IPL_SRC)/tools/ $(IPL_DUMMY_OUT)
	$(hide) cp -R $(IPL_SRC)/include/ $(IPL_DUMMY_OUT)
	$(hide) CROSS_COMPILE=$(IPL_CROSS_COMPILE) make $(PLATFORM_FLAGS) -C $(IPL_DUMMY_OUT)/tools/dummy_create clean
	$(hide) CROSS_COMPILE=$(IPL_CROSS_COMPILE) make CPPFLAGS="-D=AARCH64" $(PLATFORM_FLAGS) -C $(IPL_DUMMY_OUT)/tools/dummy_create

android_dummy_hf: $(IPL_DUMMY_HF_OUT)
	@echo "Building dummy for HyperFlash"
	$(hide) cp -R $(IPL_SRC)/tools/ $(IPL_DUMMY_HF_OUT)
	$(hide) cp -R $(IPL_SRC)/include/ $(IPL_DUMMY_HF_OUT)
	$(hide) CROSS_COMPILE=$(IPL_CROSS_COMPILE) make $(PLATFORM_FLAGS) -C $(IPL_DUMMY_HF_OUT)/tools/dummy_create clean
	$(hide) CROSS_COMPILE=$(IPL_CROSS_COMPILE) make CPPFLAGS="-D=AARCH64" $(PLATFORM_FLAGS) RCAR_SA6_TYPE=0 -C $(IPL_DUMMY_HF_OUT)/tools/dummy_create

android_ipl: $(IPL_OUT)
	@echo "Building ipl"
	$(hide) CROSS_COMPILE=$(IPL_CROSS_COMPILE) make IPL_OUT=$(IPL_OUT) RCAR_DRAM_SPLIT=$(RCAR_DRAM_SPLIT) RCAR_LOSSY_ENABLE=$(RCAR_LOSSY_ENABLE) $(PLATFORM_FLAGS) -C $(IPL_SRC) distclean
	$(hide) CROSS_COMPILE=$(IPL_CROSS_COMPILE) make IPL_OUT=$(IPL_OUT) RCAR_DRAM_SPLIT=$(RCAR_DRAM_SPLIT) RCAR_LOSSY_ENABLE=$(RCAR_LOSSY_ENABLE) -e MAKEFLAGS= $(PLATFORM_FLAGS) -C $(IPL_SRC) all

.PHONY: ipl iplclean dummy

LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

BOOTPARAM_SA0_BIN_PATH := $(IPL_DUMMY_OUT)/tools/dummy_create/bootparam_sa0.bin
$(BOOTPARAM_SA0_BIN_PATH): android_dummy

LOCAL_MODULE := bootparam_sa0.bin
LOCAL_PREBUILT_MODULE_FILE:= $(BOOTPARAM_SA0_BIN_PATH)
LOCAL_MODULE_PATH := $(PRODUCT_OUT_ABS)/

include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)

BOOTPARAM_SA0_HF_BIN_PATH := $(IPL_DUMMY_HF_OUT)/tools/dummy_create/bootparam_sa0.bin
$(BOOTPARAM_SA0_HF_BIN_PATH): android_dummy_hf

LOCAL_MODULE := bootparam_sa0_hf.bin
LOCAL_PREBUILT_MODULE_FILE:= $(BOOTPARAM_SA0_HF_BIN_PATH)
LOCAL_MODULE_PATH := $(PRODUCT_OUT_ABS)/

include $(BUILD_EXECUTABLE)


include $(CLEAR_VARS)

BOOTPARAM_SA0_SREC_PATH := $(IPL_DUMMY_HF_OUT)/tools/dummy_create/bootparam_sa0.srec
$(BOOTPARAM_SA0_SREC_PATH): android_dummy_hf

LOCAL_MODULE := bootparam_sa0_hf.srec
LOCAL_PREBUILT_MODULE_FILE:= $(BOOTPARAM_SA0_SREC_PATH)
LOCAL_MODULE_PATH := $(PRODUCT_OUT_ABS)/

include $(BUILD_EXECUTABLE)


include $(CLEAR_VARS)

CERT_HEADER_SA6_BIN_PATH := $(IPL_DUMMY_OUT)/tools/dummy_create/cert_header_sa6.bin
$(CERT_HEADER_SA6_BIN_PATH): android_dummy

LOCAL_MODULE := cert_header_sa6.bin
LOCAL_PREBUILT_MODULE_FILE:= $(CERT_HEADER_SA6_BIN_PATH)
LOCAL_MODULE_PATH := $(PRODUCT_OUT_ABS)/

include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)

CERT_HEADER_SA6_HF_BIN_PATH := $(IPL_DUMMY_HF_OUT)/tools/dummy_create/cert_header_sa6.bin
$(CERT_HEADER_SA6_HF_BIN_PATH): android_dummy_hf

LOCAL_MODULE := cert_header_sa6_hf.bin
LOCAL_PREBUILT_MODULE_FILE:= $(CERT_HEADER_SA6_HF_BIN_PATH)
LOCAL_MODULE_PATH := $(PRODUCT_OUT_ABS)/

include $(BUILD_EXECUTABLE)


include $(CLEAR_VARS)

CERT_HEADER_SA6_HF_SREC_PATH := $(IPL_DUMMY_HF_OUT)/tools/dummy_create/cert_header_sa6.srec
$(CERT_HEADER_SA6_HF_SREC_PATH): android_dummy_hf

LOCAL_MODULE := cert_header_sa6_hf.srec
LOCAL_PREBUILT_MODULE_FILE:= $(CERT_HEADER_SA6_HF_SREC_PATH)
LOCAL_MODULE_PATH := $(PRODUCT_OUT_ABS)/

include $(BUILD_EXECUTABLE)


include $(CLEAR_VARS)

BL2_BIN := $(IPL_OUT)/rcar/${BUILD}/bl2.bin
$(BL2_BIN): android_ipl

LOCAL_MODULE := bl2.bin
LOCAL_PREBUILT_MODULE_FILE:= $(BL2_BIN)
LOCAL_MODULE_PATH := $(PRODUCT_OUT_ABS)/

include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)

BL2_BIN := $(IPL_OUT)/rcar/${BUILD}/bl2.bin
$(BL2_BIN): android_ipl

LOCAL_MODULE := bl2_hf.bin
LOCAL_PREBUILT_MODULE_FILE:= $(BL2_BIN)
LOCAL_MODULE_PATH := $(PRODUCT_OUT_ABS)/

include $(BUILD_EXECUTABLE)



include $(CLEAR_VARS)

BL2_SREC := $(IPL_OUT)/rcar/${BUILD}/bl2.srec
$(BL2_SREC): android_ipl

LOCAL_MODULE := bl2_hf.srec
LOCAL_PREBUILT_MODULE_FILE:= $(BL2_SREC)
LOCAL_MODULE_PATH := $(PRODUCT_OUT_ABS)/

include $(BUILD_EXECUTABLE)


include $(CLEAR_VARS)

BL31_BIN := $(IPL_OUT)/rcar/${BUILD}/bl31.bin
$(BL31_BIN): android_ipl

LOCAL_MODULE := bl31.bin
LOCAL_PREBUILT_MODULE_FILE:= $(BL31_BIN)
LOCAL_MODULE_PATH := $(PRODUCT_OUT_ABS)/

include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)

BL31_BIN := $(IPL_OUT)/rcar/${BUILD}/bl31.bin
$(BL31_BIN): android_ipl

LOCAL_MODULE := bl31_hf.bin
LOCAL_PREBUILT_MODULE_FILE:= $(BL31_BIN)
LOCAL_MODULE_PATH := $(PRODUCT_OUT_ABS)/

include $(BUILD_EXECUTABLE)


include $(CLEAR_VARS)

BL31_SREC := $(IPL_OUT)/rcar/${BUILD}/bl31.srec
$(BL31_SREC): android_ipl

LOCAL_MODULE := bl31_hf.srec
LOCAL_PREBUILT_MODULE_FILE:= $(BL31_SREC)
LOCAL_MODULE_PATH := $(PRODUCT_OUT_ABS)/

include $(BUILD_EXECUTABLE)
