/*
 * Copyright (c) 2018, GlobalLogic. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/* IPL addresses for eMMC */
#define RCAR_EMMC_CERT_HEADER	(0x00030000U)
/* 256K for BL31(0x80000 - 0x40000)*/
#define RCAR_ARM_TRUSTED_ADDR	(0x00040000U)
/* 1.5M space for TEE (0x200000 - 0x80000) */
#define RCAR_OPTEE_ADDR		(0x00080000U)
/* 2M min space for BL31(0x400000 - 0x200000) */
#define RCAR_UBOOT_ADDR		(0x00200000U)