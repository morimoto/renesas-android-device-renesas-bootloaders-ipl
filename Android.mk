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


PRODUCT_OUT_ABS := $(abspath $(PRODUCT_OUT))

IPL_SRC       := $(abspath ./device/renesas/bootloaders/ipl/)
IPL_OUT       := $(PRODUCT_OUT_ABS)/obj/IPL_OBJ
IPL_DUMMY_OUT := $(PRODUCT_OUT_ABS)/obj/IPL_DUMMY_OBJ

IPL_CROSS_COMPILE := $(BSP_GCC_CROSS_COMPILE)

ifeq ($(DEBUG),1)
    BUILD=debug
else
    BUILD=release
endif

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

ifeq ($(USE_MULTIMEDIA), 1)
LOSSY_ENABLE=1
else
LOSSY_ENABLE=0
endif


.PHONY: ipl_out_dir
ipl_out_dir:
	$(MKDIR) -p $(IPL_OUT)

.PHONY: ipl_dummy_dir
ipl_dummy_dir:
	mkdir -p $(IPL_DUMMY_OUT)
	$(hide) cp -R $(IPL_SRC)/tools $(IPL_DUMMY_OUT)/tools
	$(hide) cp -R $(IPL_SRC)/include/ $(IPL_DUMMY_OUT)/include

.PHONY: iplclean
iplclean:
	CROSS_COMPILE=$(IPL_CROSS_COMPILE) make $(PLATFORM_FLAGS) \
	 -C $(IPL_SRC) O=$(IPL_OUT) distclean

.PHONY: android_dummy
android_dummy: ipl_dummy_dir
	@echo "Building android_dummy"

	CROSS_COMPILE=$(IPL_CROSS_COMPILE) make $(PLATFORM_FLAGS) \
	 -C $(IPL_DUMMY_OUT)/tools/dummy_create clean
	CROSS_COMPILE=$(IPL_CROSS_COMPILE) make CPPFLAGS="-D=AARCH64" \
	 $(PLATFORM_FLAGS) -C $(IPL_DUMMY_OUT)/tools/dummy_create

.PHONY: android_dummy_hf
android_dummy_hf: ipl_dummy_dir
	@echo "Building android_dummy_hf"

	CROSS_COMPILE=$(IPL_CROSS_COMPILE) make $(PLATFORM_FLAGS) \
	 -C $(IPL_DUMMY_OUT)/tools/dummy_create clean
	CROSS_COMPILE=$(IPL_CROSS_COMPILE) make CPPFLAGS="-D=AARCH64" \
	 $(PLATFORM_FLAGS) RCAR_SA6_TYPE=0 -C $(IPL_DUMMY_OUT)/tools/dummy_create



.PHONY: android_ipl
android_ipl: ipl_out_dir
	@echo "Building ipl"
	CROSS_COMPILE=$(IPL_CROSS_COMPILE) make IPL_OUT=$(IPL_OUT) \
	 RCAR_DRAM_SPLIT=$(RCAR_DRAM_SPLIT) RCAR_LOSSY_ENABLE=$(RCAR_LOSSY_ENABLE) \
	 $(PLATFORM_FLAGS) -C $(IPL_SRC) distclean

	CROSS_COMPILE=$(IPL_CROSS_COMPILE) make IPL_OUT=$(IPL_OUT) \
	 RCAR_DRAM_SPLIT=$(RCAR_DRAM_SPLIT) RCAR_LOSSY_ENABLE=$(RCAR_LOSSY_ENABLE) \
	  -e MAKEFLAGS= $(PLATFORM_FLAGS) -C $(IPL_SRC) all



.PHONY: bootparam_sa0.bin
bootparam_sa0.bin: android_dummy
	cp $(IPL_DUMMY_OUT)/tools/dummy_create/bootparam_sa0.bin $(PRODUCT_OUT_ABS)

.PHONY: bootparam_sa0.srec
bootparam_sa0.srec: android_dummy_hf
	cp $(IPL_DUMMY_OUT)/tools/dummy_create/bootparam_sa0.srec $(PRODUCT_OUT_ABS)

.PHONY: cert_header_sa6.bin
cert_header_sa6.bin: android_dummy
	cp $(IPL_DUMMY_OUT)/tools/dummy_create/cert_header_sa6.bin $(PRODUCT_OUT_ABS)

.PHONY: cert_header_sa6.srec
cert_header_sa6.srec: android_dummy_hf
	cp $(IPL_DUMMY_OUT)/tools/dummy_create/cert_header_sa6.srec $(PRODUCT_OUT_ABS)


.PHONY: bl2.bin
bl2.bin: android_ipl
	cp $(IPL_OUT)/rcar/${BUILD}/bl2.bin $(PRODUCT_OUT_ABS)/bl2.bin

.PHONY: bl31.bin
bl31.bin: android_ipl
	cp $(IPL_OUT)/rcar/${BUILD}/bl31.bin $(PRODUCT_OUT_ABS)/bl31.bin

.PHONY: bl2.srec
bl2.srec: android_ipl
	cp $(IPL_OUT)/rcar/${BUILD}/bl2.srec $(PRODUCT_OUT_ABS)/bl2.srec

.PHONY: bl31.srec
bl31.srec: android_ipl
	cp $(IPL_OUT)/rcar/${BUILD}/bl31.srec $(PRODUCT_OUT_ABS)/bl31.srec


endif # TARGET_PRODUCT salvator ulcb kingfisher
