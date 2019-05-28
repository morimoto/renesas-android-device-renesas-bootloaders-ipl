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

# Include only for Renesas ones.
ifneq (,$(filter $(TARGET_PRODUCT), salvator ulcb kingfisher))

IPL_BUILD           := release

IPL_SRC             := $(abspath ./device/renesas/bootloaders/ipl)
IPL_SA_SRC          := $(abspath ./device/renesas/bootloaders/ipl/tools/dummy_create)

# bl2 bl31 build output
IPL_OUT             := $(PRODUCT_OUT)/obj/IPL_OBJ
IPL_OUT_ABS         := $(abspath $(IPL_OUT))

# SA0 SA6 for bootloader.img build output
IPL_SA_OUT          := $(PRODUCT_OUT)/obj/IPL_SA_OBJ
IPL_SA_SRC_ABS      := $(abspath $(IPL_SA_OUT))/tools/dummy_create

# SA0 SA6 SREC (HyperFlash) build output
IPL_SA_HF_OUT       := $(PRODUCT_OUT)/obj/IPL_SA_HF_OBJ
IPL_SA_HF_SRC_ABS   := $(abspath $(IPL_SA_HF_OUT))/tools/dummy_create

ifeq ($(DEBUG),1)
    IPL_BUILD := debug
endif

IPL_SA0_BINARY      := $(IPL_SA_OUT)/tools/dummy_create/bootparam_sa0.bin
IPL_SA6_BINARY      := $(IPL_SA_OUT)/tools/dummy_create/cert_header_sa6.bin
IPL_BL2_BINARY      := $(IPL_OUT)/rcar/$(IPL_BUILD)/bl2.bin
IPL_BL31_BINARY     := $(IPL_OUT)/rcar/$(IPL_BUILD)/bl31.bin

IPL_SA0_SREC        := $(IPL_SA_HF_OUT)/tools/dummy_create/bootparam_sa0.srec
IPL_SA6_SREC        := $(IPL_SA_HF_OUT)/tools/dummy_create/cert_header_sa6.srec
IPL_BL2_SREC        := $(IPL_OUT)/rcar/$(IPL_BUILD)/bl2.srec
IPL_BL31_SREC       := $(IPL_OUT)/rcar/$(IPL_BUILD)/bl31.srec

PLATFORM_FLAGS := \
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

ifeq ($(TARGET_BOARD_PLATFORM),r8a7795)

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
ifeq ($(H3_OPTION),DYNAMIC)
PLATFORM_FLAGS += \
    RCAR_DRAM_LPDDR4_MEMCONF=3
else
PLATFORM_FLAGS += \
    RCAR_DRAM_LPDDR4_MEMCONF=0
endif # ($(H3_OPTION),DYNAMIC)
endif # ($(H3_OPTION),4GB2x2)
endif # ($(H3_OPTION),4GB)
endif # ($(H3_OPTION),8GB)

else
ifeq ($(TARGET_BOARD_PLATFORM),r8a7796)

else
ifeq ($(TARGET_BOARD_PLATFORM),r8a77965)
PLATFORM_FLAGS += \
    RCAR_DRAM_LPDDR4_MEMCONF=2

endif # ($(TARGET_BOARD_PLATFORM),r8a77965)
endif # ($(TARGET_BOARD_PLATFORM),r8a7796)
endif # ($(TARGET_BOARD_PLATFORM),r8a7795)

PLATFORM_FLAGS += \
    BUILD=$(IPL_BUILD) \
    CROSS_COMPILE=$(BSP_GCC_CROSS_COMPILE)

# Use multimedia
PLATFORM_FLAGS += \
    RCAR_LOSSY_ENABLE=1

$(IPL_OUT):
	$(MKDIR) -p $(IPL_OUT)

$(IPL_SA_OUT):
	$(MKDIR) -p $(IPL_SA_OUT)
	cp -R $(IPL_SRC)/tools $(IPL_SA_OUT)/
	cp -R $(IPL_SRC)/include $(IPL_SA_OUT)/

$(IPL_SA_HF_OUT):
	$(MKDIR) -p $(IPL_SA_HF_OUT)
	cp -R $(IPL_SRC)/tools $(IPL_SA_HF_OUT)/
	cp -R $(IPL_SRC)/include $(IPL_SA_HF_OUT)/

$(IPL_SA0_BINARY) : $(IPL_SA_OUT)
	export $(PLATFORM_FLAGS)
	$(ANDROID_MAKE) $(PLATFORM_FLAGS) -C $(IPL_SA_SRC_ABS) clean
	$(ANDROID_MAKE) $(PLATFORM_FLAGS) CPPFLAGS="-D=AARCH64" -C $(IPL_SA_SRC_ABS) all

$(IPL_SA6_BINARY) : $(IPL_SA0_BINARY)

$(IPL_SA0_SREC) : $(IPL_SA_HF_OUT)
	export $(PLATFORM_FLAGS)
	$(ANDROID_MAKE) $(PLATFORM_FLAGS) -C $(IPL_SA_HF_SRC_ABS) clean
	$(ANDROID_MAKE) $(PLATFORM_FLAGS) CPPFLAGS="-D=AARCH64" RCAR_SA6_TYPE=0 -C $(IPL_SA_HF_SRC_ABS) all

$(IPL_SA6_SREC) : $(IPL_SA0_SREC)

$(IPL_BL2_BINARY) : $(IPL_OUT)
	export $(PLATFORM_FLAGS)
	$(ANDROID_MAKE) IPL_OUT=$(IPL_OUT_ABS) $(PLATFORM_FLAGS) -C $(IPL_SRC) clean
	$(ANDROID_MAKE) IPL_OUT=$(IPL_OUT_ABS) $(PLATFORM_FLAGS) -C $(IPL_SRC) all

$(IPL_BL31_BINARY) : $(IPL_BL2_BINARY)
$(IPL_BL2_SREC) : $(IPL_BL2_BINARY)
$(IPL_BL31_SREC) : $(IPL_BL31_BINARY)

# ----------------------------------------------------------------------

include $(CLEAR_VARS)
LOCAL_MODULE                := bootparam_sa0.bin
LOCAL_PREBUILT_MODULE_FILE  := $(IPL_SA0_BINARY)
LOCAL_MODULE_PATH           := $(PRODUCT_OUT)
LOCAL_MODULE_CLASS          := EXECUTABLES
include $(BUILD_PREBUILT)
$(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE)

include $(CLEAR_VARS)
LOCAL_MODULE                := bootparam_sa0.srec
LOCAL_PREBUILT_MODULE_FILE  := $(IPL_SA0_SREC)
LOCAL_MODULE_PATH           := $(PRODUCT_OUT)
LOCAL_MODULE_CLASS          := EXECUTABLES
include $(BUILD_PREBUILT)
$(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE)

include $(CLEAR_VARS)
LOCAL_MODULE                := cert_header_sa6.bin
LOCAL_PREBUILT_MODULE_FILE  := $(IPL_SA6_BINARY)
LOCAL_MODULE_PATH           := $(PRODUCT_OUT)
LOCAL_MODULE_CLASS          := EXECUTABLES
include $(BUILD_PREBUILT)
$(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE)

include $(CLEAR_VARS)
LOCAL_MODULE                := cert_header_sa6.srec
LOCAL_PREBUILT_MODULE_FILE  := $(IPL_SA6_SREC)
LOCAL_MODULE_PATH           := $(PRODUCT_OUT)
LOCAL_MODULE_CLASS          := EXECUTABLES
include $(BUILD_PREBUILT)
$(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE)

include $(CLEAR_VARS)
LOCAL_MODULE                := bl2.bin
LOCAL_PREBUILT_MODULE_FILE  := $(IPL_BL2_BINARY)
LOCAL_MODULE_PATH           := $(PRODUCT_OUT)
LOCAL_MODULE_CLASS          := EXECUTABLES
include $(BUILD_PREBUILT)
$(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE)

include $(CLEAR_VARS)
LOCAL_MODULE                := bl2.srec
LOCAL_PREBUILT_MODULE_FILE  := $(IPL_BL2_SREC)
LOCAL_MODULE_PATH           := $(PRODUCT_OUT)
LOCAL_MODULE_CLASS          := EXECUTABLES
include $(BUILD_PREBUILT)
$(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE)

include $(CLEAR_VARS)
LOCAL_MODULE                := bl31.bin
LOCAL_PREBUILT_MODULE_FILE  := $(IPL_BL31_BINARY)
LOCAL_MODULE_PATH           := $(PRODUCT_OUT)
LOCAL_MODULE_CLASS          := EXECUTABLES
include $(BUILD_PREBUILT)
$(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE)

include $(CLEAR_VARS)
LOCAL_MODULE                := bl31.srec
LOCAL_PREBUILT_MODULE_FILE  := $(IPL_BL31_SREC)
LOCAL_MODULE_PATH           := $(PRODUCT_OUT)
LOCAL_MODULE_CLASS          := EXECUTABLES
include $(BUILD_PREBUILT)
$(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE)

endif # TARGET_PRODUCT salvator ulcb kingfisher
