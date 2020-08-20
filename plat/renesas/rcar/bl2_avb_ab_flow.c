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

#include <string.h>
#include <bl_common.h>
#include <debug.h>
#include <io_driver.h>
#include <io_rcar.h>
#include <partition.h>
#include <gpt.h>
#include "emmc_hal.h"
#include "emmc_std.h"
#include "emmc_def.h"
#include "bl2_avb_ab_flow.h"
#include "ipl_emmc.h"
#include "avb_sha.h"

/* 2048 bytes offset on misc = 4 sectors */
#define AVB_BLOCK_DATA_OFFSET		(0x4)
/* 32768 bytes offset = 64 sectors = 0x40 */
#define VIRTUAL_AB_MSG_DATA_OFFSET	(0x40)

#define USER_PARTITION			(0x0)
#define USE_DMA				(0x1)
#define WITHOUT_DMA			(0x0)

#define addr_to_blk(blk_addr)		((blk_addr) >> (EMMC_SECTOR_SIZE_SHIFT))
#define blk_to_addr(addr)		((blk_addr) << (EMMC_SECTOR_SIZE_SHIFT))
#define get_offset_in_block(addr)	((addr) % (EMMC_SECTOR_SIZE))
#define GPT_HEADER_BLK_OFFSET		addr_to_blk(GPT_HEADER_OFFSET)
#define GPT_BLOCK_SIZE			addr_to_blk(PARTITION_BLOCK_SIZE)
#define GPT_BLOCK_ENTRY_OFFSET		addr_to_blk(GPT_ENTRY_OFFSET)

#define MMC_BOOT0 (1)
#define MMC_BOOT1 (2)

static bool is_hash_ok(uint8_t *buf,  uint32_t len, uint8_t *digest, uint32_t digest_type)
{
	unsigned char hash[AVB_SHA256_DIGEST_SIZE];

	switch (digest_type) {
		case SHA_256:
			sha256(buf, len, hash);
			if (!memcmp(hash, digest, AVB_SHA256_DIGEST_SIZE)) {
				return true;
			}
			break;
		default:
			ERROR("Unsupported digest type (%d)\n",
				digest_type);
			break;
	}
	return false;
}

#define IPL_BUFF_ADDR 0x50000000

/*We'll boot IPLs into DRAM*/
static uint8_t *ipl_image_buf = (uint8_t *) IPL_BUFF_ADDR;

static int check_emmc_hash(int partition)
{
	struct ipl_params *ipl_param = NULL;
	uint8_t *buf = NULL;
	uint32_t offset_in_block = 0;
	int total_ipls = 0, unpacked_ipls = 0;
	struct ipl_image img;
	int i, res;

	res = emmc_select_partition(partition);
	if (res != EMMC_SUCCESS) {
		ERROR("Error selecting partition %u\n", partition);
		return -1;
	}

	emmc_read_sector((uint32_t *)ipl_image_buf, 0, 1, WITHOUT_DMA);
	memcpy(&img, ipl_image_buf, sizeof(img));

	if(strncmp(img.hdr.ipl_magic, IPL_EMMC_BOOT_MAGIC, sizeof(img.hdr.ipl_magic))) {
		ERROR("Image magic is wrong!\n");
		return -1;
	}

	/*Read IPL parameters and data*/
	for (i = 0; i < MAX_IPLS; i++) {
			/*Check if we have the appropriate IPL*/
			if (img.hdr.ipl_offset[i] > 0) {
				total_ipls++;
				/*
				 * Addresses can be not aligned to @EMMC_SECTOR_SIZE
				 * so we need to save the offset in block from which
				 * data starts.
				 */
				emmc_read_sector((uint32_t *)ipl_image_buf, addr_to_blk(img.hdr.ipl_offset[i]),
					1, WITHOUT_DMA);
				offset_in_block = get_offset_in_block(img.hdr.ipl_offset[i]);
				ipl_param = (struct ipl_params *)(ipl_image_buf + offset_in_block);
				emmc_read_sector((uint32_t *)ipl_image_buf, addr_to_blk(img.hdr.ipl_offset[i]),
					addr_to_blk(ipl_param->fsize + EMMC_SECTOR_SIZE - 1) + 1, WITHOUT_DMA);
				buf = (uint8_t *)(ipl_image_buf + offset_in_block + sizeof(struct ipl_params));
				if (is_hash_ok(buf, ipl_param->fsize, ipl_param->digest, ipl_param->digest_type)) {
					unpacked_ipls++;
				} else {
					ERROR("SHA-256 mismatch for image %s\n",  ipl_param->fname);
				}
			}
	}

	if (total_ipls != unpacked_ipls) {
		ERROR("Error: only %d IPLs of %d checked\n",
			unpacked_ipls, total_ipls);
	}

	return -(total_ipls - unpacked_ipls);
}

static int load_gpt_header(gpt_header_t *header, int partition)
{
	uint8_t buf[EMMC_SECTOR_SIZE];
	int result = 0;

	result = emmc_select_partition(partition);
	if (result != EMMC_SUCCESS)
		return -1;

	result = emmc_read_sector((uint32_t *)&buf[0], GPT_HEADER_BLK_OFFSET,
			GPT_BLOCK_SIZE, WITHOUT_DMA);
	if (result != EMMC_SUCCESS) {
		return -1;
	}

	if (memcmp(&buf[0], GPT_SIGNATURE, sizeof(GPT_SIGNATURE))) {
		ERROR("GPT signature is incorrect\n");
		return -1;
	}

	memcpy(header, &buf[0], sizeof(*header));

	return 0;
}

static int is_find(gpt_entry_t *gpt_entry, partition_entry_t *part_entry,
				const char *name) {
	int result = 0;
	result = parse_gpt_entry(gpt_entry, part_entry);
	if (result != 0)
		return 0;

	if (!strncmp(name, part_entry->name, strlen(name)))
		return 1;

	return 0;
}

static int get_part_info(const int partition, const gpt_header_t *header,
						partition_entry_t *entry, const char *name)
{
	const uint32_t entry_size = header->part_size;
	const int num_of_entries =
		(header->list_num > PLAT_PARTITION_MAX_ENTRIES) ?
		PLAT_PARTITION_MAX_ENTRIES : header->list_num;
	const uint32_t gpt_table_size = entry_size * num_of_entries;
	const uint32_t read_blocks = addr_to_blk(gpt_table_size + EMMC_SECTOR_SIZE - 1);

	gpt_entry_t gpt_entry_element;
	uint8_t gpt_block_buf[EMMC_SECTOR_SIZE];
	const uint8_t *buf_end = &gpt_block_buf[EMMC_SECTOR_SIZE];
	uint8_t *ptr_i = &gpt_block_buf[0];

	int i = 0;
	int result = 0;
	int offset = 0;

	result = emmc_select_partition(partition);
	if (result != EMMC_SUCCESS)
		goto error;

	for (i = 0; i < read_blocks; ++i) {
		result = emmc_read_sector((uint32_t *)&gpt_block_buf[0],
			GPT_BLOCK_ENTRY_OFFSET + i, /*Read blocks*/ 1, WITHOUT_DMA);
		if (result != EMMC_SUCCESS)
			goto error;

		if (offset) {
			memcpy(((uint8_t *)&gpt_entry_element) + entry_size - offset,
				&gpt_block_buf[0], offset);
			if (is_find(&gpt_entry_element, entry, name))
				return 0;
		}

		while ((ptr_i + entry_size) <= buf_end) {
			if (is_find((gpt_entry_t *)ptr_i, entry, name))
				return 0;

			ptr_i += entry_size;
		}

		if (buf_end != ptr_i) {
			offset = (ptr_i + entry_size - buf_end);
			memcpy(&gpt_entry_element, ptr_i, entry_size - offset);
		} else {
			offset = 0;
		}

		ptr_i = (uint8_t *)(&gpt_block_buf[0] + offset);
	}

error:
	memset(entry, 0, sizeof(*entry));
	return -1;
}

enum avb_ab_slots {
	AVB_AB_SLOT_A = 0,
	AVB_AB_SLOT_B,
	AVB_AB_SLOT_NUM,
};

/* Converts a 32-bit unsigned integer from host to big-endian byte order. */
static uint32_t avb_htobe32(uint32_t in)
{
	union {
		uint32_t word;
		uint8_t bytes[4];
	} ret;
	ret.bytes[0] = (in >> 24) & 0xff;
	ret.bytes[1] = (in >> 16) & 0xff;
	ret.bytes[2] = (in >> 8) & 0xff;
	ret.bytes[3] = in & 0xff;
	return ret.word;
}

/* Code taken from FreeBSD 8 */

static uint32_t iavb_crc32_tab[] = {
	0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f,
	0xe963a535, 0x9e6495a3, 0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988,
	0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91, 0x1db71064, 0x6ab020f2,
	0xf3b97148, 0x84be41de, 0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
	0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec, 0x14015c4f, 0x63066cd9,
	0xfa0f3d63, 0x8d080df5, 0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172,
	0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b, 0x35b5a8fa, 0x42b2986c,
	0xdbbbc9d6, 0xacbcf940, 0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
	0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423,
	0xcfba9599, 0xb8bda50f, 0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
	0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d, 0x76dc4190, 0x01db7106,
	0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
	0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d,
	0x91646c97, 0xe6635c01, 0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e,
	0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457, 0x65b0d9c6, 0x12b7e950,
	0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
	0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7,
	0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0,
	0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9, 0x5005713c, 0x270241aa,
	0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
	0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81,
	0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a,
	0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683, 0xe3630b12, 0x94643b84,
	0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
	0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb,
	0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc,
	0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5, 0xd6d6a3e8, 0xa1d1937e,
	0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
	0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55,
	0x316e8eef, 0x4669be79, 0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
	0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f, 0xc5ba3bbe, 0xb2bd0b28,
	0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
	0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f,
	0x72076785, 0x05005713, 0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38,
	0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21, 0x86d3d2d4, 0xf1d4e242,
	0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
	0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69,
	0x616bffd3, 0x166ccf45, 0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2,
	0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db, 0xaed16a4a, 0xd9d65adc,
	0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
	0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693,
	0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94,
	0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d};

/*
 * A function that calculates the CRC-32 based on the table above is
 * given below for documentation purposes. An equivalent implementation
 * of this function that's actually used in the kernel can be found
 * in sys/libkern.h, where it can be inlined.
 */

static uint32_t iavb_crc32(uint32_t crc_in, const uint8_t* buf, int size)
{
	const uint8_t *p = buf;
	uint32_t crc;

	crc = crc_in ^ ~0U;
	while (size--)
		crc = iavb_crc32_tab[(crc ^ *p++) & 0xFF] ^ (crc >> 8);
	return crc ^ ~0U;
}

static uint32_t avb_crc32(const uint8_t* buf, size_t size)
{
	return iavb_crc32(0, buf, size);
}

static AvbABFlowResult avb_ab_check_data(const AvbABData *data)
{
	uint32_t crc32 = 0;

	if (memcmp(AVB_AB_MAGIC, data->magic, AVB_AB_MAGIC_LEN)) {
		ERROR("AVB a/b magic is incorrect\n");
		return AVB_AB_FLOW_RESULT_ERROR_INVALID_ARGUMENT;
	}

	if (data->version_major > AVB_AB_MAJOR_VERSION) {
		ERROR("No support for given major version.\n");
		return AVB_AB_FLOW_RESULT_ERROR_INVALID_ARGUMENT;
	}

	crc32 = avb_htobe32(avb_crc32((uint8_t *)data,
		sizeof(*data) - sizeof(data->crc32)));

	if (crc32 != data->crc32) {
		ERROR("CRC32 does not match.\n");
		return AVB_AB_FLOW_RESULT_ERROR_INVALID_ARGUMENT;
	}

	return AVB_AB_FLOW_RESULT_OK;
}

static int avb_ab_slot_is_bootable(const AvbABSlotData *slot_data)
{
	return (slot_data->priority > 0)
			&& (slot_data->successful_boot
				|| (slot_data->tries_remaining > 0));
}

static AvbABFlowResult get_misc_part_entry(partition_entry_t *pentry) {
	gpt_header_t header;

	if (load_gpt_header(&header, USER_PARTITION)) {
		ERROR("Failed to load GPT table\n");
		return AVB_AB_FLOW_RESULT_ERROR_IO;
	}

	if (get_part_info(USER_PARTITION, &header, pentry, "misc")) {
		ERROR("Failed to get information from misc partition\n");
		return AVB_AB_FLOW_RESULT_ERROR_IO;
	}

	return AVB_AB_FLOW_RESULT_OK;
}

static AvbABFlowResult read_sector_from_misc(uint32_t *buf, uint32_t blkaddr) {
	int result = 0;
	partition_entry_t entry;

	if (!buf) {
		ERROR("Invalid buffer passed to %s\n", __func__);
		return AVB_AB_FLOW_RESULT_ERROR_INVALID_ARGUMENT;
	}

	if (get_misc_part_entry(&entry) != AVB_AB_FLOW_RESULT_OK)
		return AVB_AB_FLOW_RESULT_ERROR_IO;

	result = emmc_select_partition(USER_PARTITION);
	if (result != EMMC_SUCCESS) {
		ERROR("Failed to select user partition err = (%d)\n", result);
		return AVB_AB_FLOW_RESULT_ERROR_IO;
	}

	/* Read single block */
	result = emmc_read_sector(buf, addr_to_blk(entry.start) + blkaddr,
				1, WITHOUT_DMA);
	if (result != EMMC_SUCCESS) {
		ERROR("Failed to read avb a/b block err = (%d)\n", result);
		return AVB_AB_FLOW_RESULT_ERROR_IO;
	}

	return AVB_AB_FLOW_RESULT_OK;
}

static AvbABFlowResult write_sector_to_misc(uint32_t *buf, uint32_t blkaddr) {
	int result = 0;
	partition_entry_t entry;

	if (!buf) {
		ERROR("Invalid buffer passed to %s\n", __func__);
		return AVB_AB_FLOW_RESULT_ERROR_INVALID_ARGUMENT;
	}

	if (get_misc_part_entry(&entry) != AVB_AB_FLOW_RESULT_OK)
		return AVB_AB_FLOW_RESULT_ERROR_IO;

	result = emmc_select_partition(USER_PARTITION);
	if (result != EMMC_SUCCESS) {
		ERROR("Failed to select user partition err = (%d)\n", result);
		return AVB_AB_FLOW_RESULT_ERROR_IO;
	}

	/* Write single block */
	result = emmc_write_sector(buf, addr_to_blk(entry.start) + blkaddr,
				1, WITHOUT_DMA);
	if (result != EMMC_SUCCESS) {
		ERROR("Failed to write avb a/b block err = (%d)\n", result);
		return AVB_AB_FLOW_RESULT_ERROR_IO;
	}

	return AVB_AB_FLOW_RESULT_OK;
}

static AvbABFlowResult avb_ab_write_data(const AvbABData *data)
{
	uint8_t buf[EMMC_SECTOR_SIZE];
	AvbABFlowResult result = 0;

	result = read_sector_from_misc((uint32_t *)&buf[0], AVB_BLOCK_DATA_OFFSET);
	if (result != AVB_AB_FLOW_RESULT_OK) {
		ERROR("Failed to read avb a/b block err = (%d)\n", result);
		return result;
	}

	memcpy(&buf[0], data, sizeof(*data));

	result = write_sector_to_misc((uint32_t *)&buf[0], AVB_BLOCK_DATA_OFFSET);
	if (result != AVB_AB_FLOW_RESULT_OK) {
		ERROR("Failed to read avb a/b block err = (%d)\n", result);
		return result;
	}

	return AVB_AB_FLOW_RESULT_OK;
}

AvbABFlowResult avb_ab_update_and_save(AvbABData *data)
{
	/*CRC32 must be stored in BE*/
	data->crc32 = avb_htobe32(avb_crc32((uint8_t *)data,
		sizeof(*data) - sizeof(data->crc32)));

	return avb_ab_write_data(data);
}

static void avb_ab_data_init(AvbABData *data)
{
	memset(data, 0, sizeof(*data));
	memcpy(data->magic, AVB_AB_MAGIC, AVB_AB_MAGIC_LEN);
	data->version_major = AVB_AB_MAJOR_VERSION;
	data->version_minor = AVB_AB_MINOR_VERSION;
	data->slots[AVB_AB_SLOT_A].priority = AVB_AB_MAX_PRIORITY;
	data->slots[AVB_AB_SLOT_A].tries_remaining = AVB_AB_MAX_TRIES_REMAINING;
	data->slots[AVB_AB_SLOT_A].successful_boot = 0;
	data->slots[AVB_AB_SLOT_B].priority = AVB_AB_MAX_PRIORITY - 1;
	data->slots[AVB_AB_SLOT_B].tries_remaining = AVB_AB_MAX_TRIES_REMAINING;
	data->slots[AVB_AB_SLOT_B].successful_boot = 0;
}

static AvbABFlowResult avb_ab_read_data(AvbABData *data)
{
	uint8_t buf[EMMC_SECTOR_SIZE];
	AvbABFlowResult result = 0;

	result = read_sector_from_misc((uint32_t *)&buf[0], AVB_BLOCK_DATA_OFFSET);
	if (result != AVB_AB_FLOW_RESULT_OK) {
		ERROR("Failed to read avb a/b block err = (%d)\n", result);
		return result;
	}

	memcpy(data, &buf[0], sizeof(*data));

	if (avb_ab_check_data(data) != AVB_AB_FLOW_RESULT_OK) {
		ERROR("Error validating A/B metadata from disk.\n"
			"Resetting and writing new A/B metadata to disk.\n");
		avb_ab_data_init(data);
		return avb_ab_update_and_save(data);
	}

	return AVB_AB_FLOW_RESULT_OK;
}

static void init_virtual_ab_msg(MiscVirtABMsg *ab_msg) {
	ab_msg->magic = MISC_VIRTUAL_AB_MAGIC_HEADER;
	ab_msg->version = MAX_VIRTUAL_AB_MESSAGE_VERSION;
	ab_msg->merge_status = VIRTUAL_AB_NONE;
	ab_msg->source_slot = 0;
}

static int validate_virtual_ab_msg(MiscVirtABMsg *ab_msg) {
	return ((ab_msg->magic == MISC_VIRTUAL_AB_MAGIC_HEADER) &&
		(ab_msg->version <= MAX_VIRTUAL_AB_MESSAGE_VERSION) &&
		(ab_msg->merge_status <= VIRTUAL_AB_CANCELLED) &&
		(ab_msg->source_slot < AVB_AB_MAX_SLOTS));
}

static AvbABFlowResult virtual_ab_msg_write(MiscVirtABMsg *ab_msg) {
	uint8_t buf[EMMC_SECTOR_SIZE];
	AvbABFlowResult result = 0;

	if (!validate_virtual_ab_msg(ab_msg)) {
		ERROR("Invalid Virtual A/B message passed to %s\n", __func__);
		return AVB_AB_FLOW_RESULT_ERROR_INVALID_ARGUMENT;
	}

	result = read_sector_from_misc((uint32_t *)&buf[0],
				VIRTUAL_AB_MSG_DATA_OFFSET);
	if (result != AVB_AB_FLOW_RESULT_OK) {
		ERROR("Failed to read Virtual A/B block err = (%d)\n", result);
		return result;
	}

	memcpy(&buf[0], ab_msg, sizeof(*ab_msg));

	result = write_sector_to_misc((uint32_t *)&buf[0],
				VIRTUAL_AB_MSG_DATA_OFFSET);
	if (result != AVB_AB_FLOW_RESULT_OK) {
		ERROR("Failed to read Virtual A/B block err = (%d)\n", result);
		return result;
	}

	return AVB_AB_FLOW_RESULT_OK;
}

static AvbABFlowResult virtual_ab_msg_read(MiscVirtABMsg *ab_msg) {
	uint8_t buf[EMMC_SECTOR_SIZE];
	AvbABFlowResult result = AVB_AB_FLOW_RESULT_OK;

	result = read_sector_from_misc((uint32_t *)&buf[0],
				VIRTUAL_AB_MSG_DATA_OFFSET);
	if (result != AVB_AB_FLOW_RESULT_OK) {
		ERROR("Failed to read Virtual A/B block err = (%d)\n", result);
		return result;
	}

	memcpy(ab_msg, &buf[0], sizeof(*ab_msg));

	if (!validate_virtual_ab_msg(ab_msg)) {
		ERROR("Error validating Virtual A/B message from disk.\n"
			"Re-init and writing new Virtual A/B message to disk.\n");
		init_virtual_ab_msg(ab_msg);
		return virtual_ab_msg_write(ab_msg);
	}

	return AVB_AB_FLOW_RESULT_OK;
}

/*
 * This function checks if no tries_remaining left for
 * previously updated slot via Virtual A/B. If so, we need
 * to cancel such update by writing specific code to
 * merge_status field on /misc.
 */
static void check_and_cancel_virtual_ab(int slot_idx) {
	AvbABFlowResult result = AVB_AB_FLOW_RESULT_OK;
	MiscVirtABMsg virtual_ab_msg;

	result = virtual_ab_msg_read(&virtual_ab_msg);
	if (result != AVB_AB_FLOW_RESULT_OK) {
		ERROR("Failed to load /misc from MMC\n");
		return;
	}

	/* Check if we previously applied update */
	if ((virtual_ab_msg.merge_status == VIRTUAL_AB_SNAPSHOTED)
		&& (virtual_ab_msg.source_slot != slot_idx)) {
		/*
		 * Okay, updated U-Boot on slot_idx failed, need to cancel
		 * update in misc_virtual_ab_message to inform Android.
		 */
		virtual_ab_msg.merge_status = VIRTUAL_AB_CANCELLED;

		result = virtual_ab_msg_write(&virtual_ab_msg);
		if (result == AVB_AB_FLOW_RESULT_OK) {
			NOTICE("Virtual update for slot %u cancelled\n", slot_idx);
		} else {
			ERROR("Failed to save Virtual A/B message to /misc\n");
		}
	}
}

static AvbABFlowResult avb_ab_get_curr_slot(const AvbABData *data, int *slot_idx)
{
	int slot_a_bootable = 0;
	int slot_b_bootable = 0;

	/*
	 * For Virtual A/B we need to check probable slot switching
	 * in case of unsuccessful U-boot boot-up from new slot after
	 * Virtual update. In such case we need to cancel virtual
	 * update and record this to misc. If slot has non-zero
	 * priority and zero tries_remaining it means that on
	 * previous boot it has spent all boot-up tries and,
	 * if Virtual A/B is in progress - it should be canceled.
	 */
	if (data->slots[AVB_AB_SLOT_A].priority &&
	!(data->slots[AVB_AB_SLOT_A].successful_boot) &&
	!data->slots[AVB_AB_SLOT_A].tries_remaining){
		check_and_cancel_virtual_ab(AVB_AB_SLOT_A);
	} else if (data->slots[AVB_AB_SLOT_B].priority &&
		!(data->slots[AVB_AB_SLOT_B].successful_boot) &&
		!(data->slots[AVB_AB_SLOT_B].tries_remaining)) {
		check_and_cancel_virtual_ab(AVB_AB_SLOT_B);
	}

	slot_a_bootable = avb_ab_slot_is_bootable(&data->slots[AVB_AB_SLOT_A]);
	slot_b_bootable = avb_ab_slot_is_bootable(&data->slots[AVB_AB_SLOT_B]);

	if (slot_a_bootable && slot_b_bootable) {
		if (data->slots[AVB_AB_SLOT_A].priority >
			data->slots[AVB_AB_SLOT_B].priority) {
			*slot_idx = AVB_AB_SLOT_A;
		} else {
			*slot_idx = AVB_AB_SLOT_B;
		}
	} else if (slot_a_bootable) {
		*slot_idx = AVB_AB_SLOT_A;
	} else if (slot_b_bootable) {
		*slot_idx = AVB_AB_SLOT_B;
	} else {
		/* Warning instead of error, because we can still try to restore BLs from HF */
		ERROR("No bootable slots in eMMC\n");
		return AVB_AB_FLOW_RESULT_ERROR_NO_BOOTABLE_SLOTS;
	}

	return AVB_AB_FLOW_RESULT_OK;
}

static int32_t boot_partition = 0;
static uint32_t avb_ab_flow_success = 0;

static void avb_ab_set_boot_partition(int slot_idx)
{
	if (slot_idx == AVB_AB_SLOT_A) {
		mmc_drv_obj.partition_access = PARTITION_ID_BOOT_1;
		mmc_drv_obj.boot_partition_en = PARTITION_ID_BOOT_1;
		boot_partition = PARTITION_ID_BOOT_1;
		emmc_select_partition(PARTITION_ID_BOOT_1);
	} else {
		mmc_drv_obj.partition_access = PARTITION_ID_BOOT_2;
		mmc_drv_obj.boot_partition_en = PARTITION_ID_BOOT_2;
		boot_partition = PARTITION_ID_BOOT_2;
		emmc_select_partition(PARTITION_ID_BOOT_2);
	}
}

AvbABFlowResult avb_ab_flow(void)
{
	AvbABData data;
	int slot_to_boot = 0;
	AvbABFlowResult result = AVB_AB_FLOW_RESULT_OK;

	result = avb_ab_read_data(&data);
	if (result != AVB_AB_FLOW_RESULT_OK)
		return result;

	/*
	 *This is preliminary check for boot magic. We should
	 *not continue with emmc boot if no emmc IPLs found
	 */
	if (check_emmc_hash(MMC_BOOT0)) {
		/*Set slot unbootable*/
		data.slots[AVB_AB_SLOT_A].priority = 0;
		data.slots[AVB_AB_SLOT_A].tries_remaining = 0;
		data.slots[AVB_AB_SLOT_A].successful_boot = 0;
		ERROR("Bootloader partition %d corrupted, setting unbootable\n", MMC_BOOT0);
	}
	if (check_emmc_hash(MMC_BOOT1)) {
		data.slots[AVB_AB_SLOT_B].priority = 0;
		data.slots[AVB_AB_SLOT_B].tries_remaining = 0;
		data.slots[AVB_AB_SLOT_B].successful_boot = 0;
		ERROR("Bootloader partition %d corrupted, setting unbootable\n", MMC_BOOT1);
	}

	result = avb_ab_get_curr_slot(&data, &slot_to_boot);
	if (result != AVB_AB_FLOW_RESULT_OK) {
		avb_ab_update_and_save(&data);
		return result;
	}

	if (data.slots[slot_to_boot].successful_boot)
		goto select_part;

	if (data.slots[slot_to_boot].tries_remaining > 0) {
		data.slots[slot_to_boot].tries_remaining -= 1;
	} else {
		data.slots[slot_to_boot].priority = 0;
		data.slots[slot_to_boot].tries_remaining = 0;
		data.slots[slot_to_boot].successful_boot = 0;

		result = avb_ab_get_curr_slot(&data, &slot_to_boot);
		/*
		 * It seems, that all slots are unbootable, so we just try
		 * to save data and return error code.
		 */
		avb_ab_update_and_save(&data);
		return result;
	}

	result = avb_ab_update_and_save(&data);
	if (result != AVB_AB_FLOW_RESULT_OK)
		return result;

select_part:
	avb_ab_set_boot_partition(slot_to_boot);
	avb_ab_flow_success = 1;

	return AVB_AB_FLOW_RESULT_OK;
}

int32_t avb_get_boot_partition_idx(void)
{
	return boot_partition;
}

uint32_t avb_ab_is_success(void)
{
	return avb_ab_flow_success;
}
