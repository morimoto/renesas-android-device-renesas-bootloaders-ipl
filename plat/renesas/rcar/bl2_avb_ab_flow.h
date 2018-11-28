/*
 * Copyright (C) 2016 The Android Open Source Project
 * Copyright (C) 2018 GlobalLogic
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#ifndef BL2_AVB_AB_FLOW_H
#define BL2_AVB_AB_FLOW_H

/* Magic for the A/B struct when serialized. */
#define AVB_AB_MAGIC "\0AB0"
#define AVB_AB_MAGIC_LEN 4

/* Versioning for the on-disk A/B metadata - keep in sync with avbtool. */
#define AVB_AB_MAJOR_VERSION 1
#define AVB_AB_MINOR_VERSION 0

/* Size of AvbABData struct. */
#define AVB_AB_DATA_SIZE 32

/* Maximum values for slot data */
#define AVB_AB_MAX_PRIORITY 15
#define AVB_AB_MAX_TRIES_REMAINING 7

typedef struct AvbABSlotData {
	/* Slot priority. Valid values range from 0 to AVB_AB_MAX_PRIORITY,
	 * both inclusive with 1 being the lowest and AVB_AB_MAX_PRIORITY
	 * being the highest. The special value 0 is used to indicate the
	 * slot is unbootable.
	 */
	uint8_t priority;

	/* Number of times left attempting to boot this slot ranging from 0
	 * to AVB_AB_MAX_TRIES_REMAINING.
	 */
	uint8_t tries_remaining;

	/* Non-zero if this slot has booted successfully, 0 otherwise. */
	uint8_t successful_boot;

	/* Reserved for future use. */
	uint8_t reserved[1];
} __attribute__((packed)) AvbABSlotData;

/* Struct used for recording A/B metadata.
 *
 * When serialized, data is stored in network byte-order.
 */
typedef struct AvbABData {
	/* Magic number used for identification - see AVB_AB_MAGIC. */
	uint8_t magic[AVB_AB_MAGIC_LEN];

	/* Version of on-disk struct - see AVB_AB_{MAJOR,MINOR}_VERSION. */
	uint8_t version_major;
	uint8_t version_minor;

	/* Padding to ensure |slots| field start eight bytes in. */
	uint8_t reserved1[2];

	/* Per-slot metadata. */
	AvbABSlotData slots[2];

	/* Reserved for future use. */
	uint8_t reserved2[12];

	/* CRC32 of all 28 bytes preceding this field. */
	uint32_t crc32;
} __attribute__((packed)) AvbABData;

typedef enum {
	AVB_AB_FLOW_RESULT_OK,
	AVB_AB_FLOW_RESULT_ERROR_IO,
	AVB_AB_FLOW_RESULT_ERROR_NO_BOOTABLE_SLOTS,
	AVB_AB_FLOW_RESULT_ERROR_INVALID_ARGUMENT
} AvbABFlowResult;

AvbABFlowResult avb_ab_flow(void);

#endif /* BL2_AVB_AB_FLOW_H */