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

PRODUCT_OUT_ABS     := $(abspath $(PRODUCT_OUT))

IPL_BUILD           := release

IPL_SRC             := $(abspath ./device/renesas/bootloaders/ipl)
IPL_SA_SRC          := $(abspath ./device/renesas/bootloaders/ipl/tools/dummy_create)

# bl2 bl31 build output
IPL_OUT_ABS         := $(PRODUCT_OUT_ABS)/obj/IPL_OBJ

# SA0 SA6 for bootloader.img build output
IPL_SA_OUT_ABS      := $(PRODUCT_OUT_ABS)/obj/IPL_SA_OBJ
IPL_SA_SRC_ABS      := $(IPL_SA_OUT_ABS)/tools/dummy_create

# SA0 SA6 SREC (HyperFlash) build output
IPL_SA_HF_OUT_ABS   := $(PRODUCT_OUT_ABS)/obj/IPL_SA_HF_OBJ
IPL_SA_HF_SRC_ABS   := $(IPL_SA_HF_OUT_ABS)/tools/dummy_create

ifeq ($(DEBUG),1)
    IPL_BUILD := debug
endif

IPL_SA0_BINARY      := $(IPL_SA_OUT_ABS)/tools/dummy_create/bootparam_sa0.bin
IPL_SA6_BINARY      := $(IPL_SA_OUT_ABS)/tools/dummy_create/cert_header_sa6.bin
IPL_BL2_BINARY      := $(IPL_OUT_ABS)/rcar/$(IPL_BUILD)/bl2.bin
IPL_BL31_BINARY     := $(IPL_OUT_ABS)/rcar/$(IPL_BUILD)/bl31.bin

IPL_SA0_SREC        := $(IPL_SA_HF_OUT_ABS)/tools/dummy_create/bootparam_sa0.srec
IPL_SA6_SREC        := $(IPL_SA_HF_OUT_ABS)/tools/dummy_create/cert_header_sa6.srec
IPL_BL2_SREC        := $(IPL_OUT_ABS)/rcar/$(IPL_BUILD)/bl2.srec
IPL_BL31_SREC       := $(IPL_OUT_ABS)/rcar/$(IPL_BUILD)/bl31.srec

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

IPL_SCAN_BUILD_CMD := $(abspath $(LLVM_PREBUILTS_PATH)/scan-build) \
	-o $(OUT_DIR)/sb-reports/ipl --use-analyzer \
	$(abspath $(LLVM_PREBUILTS_PATH)/clang) \
	--use-cc $(BSP_GCC_CROSS_COMPILE)gcc \
	--analyzer-target=aarch64-linux-gnu \
	--force-analyze-debug-code -analyze-headers

IPL_BL_BUILD_CMD := SCAN_BUILD=1 $(ANDROID_MAKE) -C $(IPL_SRC) \
	IPL_OUT=$(IPL_OUT_ABS) $(PLATFORM_FLAGS) all

ipl_sa:
	$(MKDIR) -p $(IPL_SA_OUT_ABS)
	cp -R $(IPL_SRC)/tools $(IPL_SA_OUT_ABS)/
	cp -R $(IPL_SRC)/include $(IPL_SA_OUT_ABS)/
	export $(PLATFORM_FLAGS)
	$(ANDROID_MAKE) $(PLATFORM_FLAGS) -C $(IPL_SA_SRC_ABS) clean
	$(ANDROID_MAKE) $(PLATFORM_FLAGS) CPPFLAGS="-D=AARCH64" -C $(IPL_SA_SRC_ABS) all
	cp -vF $(IPL_SA0_BINARY) $(IPL_SA6_BINARY) $(PRODUCT_OUT_ABS)/

ipl_sa_hf:
	$(MKDIR) -p $(IPL_SA_HF_OUT_ABS)
	cp -R $(IPL_SRC)/tools $(IPL_SA_HF_OUT_ABS)/
	cp -R $(IPL_SRC)/include $(IPL_SA_HF_OUT_ABS)/
	export $(PLATFORM_FLAGS)
	$(ANDROID_MAKE) $(PLATFORM_FLAGS) -C $(IPL_SA_HF_SRC_ABS) clean
	$(ANDROID_MAKE) $(PLATFORM_FLAGS) CPPFLAGS="-D=AARCH64" RCAR_SA6_TYPE=0 -C $(IPL_SA_HF_SRC_ABS) all
	cp -vF $(IPL_SA0_SREC) $(IPL_SA6_SREC) $(PRODUCT_OUT_ABS)/

ipl_bl:
	$(MKDIR) -p $(IPL_OUT_ABS)
	export $(PLATFORM_FLAGS)
	$(ANDROID_MAKE) IPL_OUT=$(IPL_OUT_ABS) $(PLATFORM_FLAGS) -C $(IPL_SRC) clean
	$(ANDROID_MAKE) IPL_OUT=$(IPL_OUT_ABS) $(PLATFORM_FLAGS) -C $(IPL_SRC) all
	cp -vF $(IPL_BL2_BINARY) $(IPL_BL31_BINARY) $(IPL_BL2_SREC) $(IPL_BL31_SREC) $(PRODUCT_OUT_ABS)/

scan-build-ipl_bl:
	@echo "Starting scan-build for IPLs"
	$(MKDIR) -p $(IPL_OUT_ABS)
	export $(PLATFORM_FLAGS)
	$(ANDROID_MAKE) IPL_OUT=$(IPL_OUT_ABS) $(PLATFORM_FLAGS) -C $(IPL_SRC) clean
	$(IPL_SCAN_BUILD_CMD) /bin/bash -c "$(IPL_BL_BUILD_CMD)"

# ----------------------------------------------------------------------

include $(CLEAR_VARS)
LOCAL_MODULE                := ipl_sa
LOCAL_MODULE_TAGS           := optional
include $(BUILD_PHONY_PACKAGE)

include $(CLEAR_VARS)
LOCAL_MODULE                := ipl_sa_hf
LOCAL_MODULE_TAGS           := optional
include $(BUILD_PHONY_PACKAGE)

include $(CLEAR_VARS)
LOCAL_MODULE                := ipl_bl
LOCAL_MODULE_TAGS           := optional
include $(BUILD_PHONY_PACKAGE)

include $(CLEAR_VARS)
LOCAL_MODULE                := scan-build-ipl_bl
LOCAL_MODULE_TAGS           := optional
include $(BUILD_PHONY_PACKAGE)

endif # TARGET_PRODUCT salvator ulcb kingfisher
