/*
 * Copyright (C) 2016 The Android Open Source Project
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

#ifndef AVB_SHA_H_
#define AVB_SHA_H_

#ifdef __cplusplus
extern "C" {
#endif

#define AVB_ATTR_WARN_UNUSED_RESULT __attribute__((warn_unused_result))

/* Size in bytes of a SHA-256 digest. */
#define AVB_SHA256_DIGEST_SIZE 32

/* Block size in bytes of a SHA-256 digest. */
#define AVB_SHA256_BLOCK_SIZE 64


/* Block size in bytes of a SHA-512 digest. */
#define AVB_SHA512_BLOCK_SIZE 128

/* Data structure used for SHA-256. */
typedef struct {
  uint32_t h[8];
  uint32_t tot_len;
  uint32_t len;
  uint8_t block[2 * AVB_SHA256_BLOCK_SIZE];
  uint8_t buf[AVB_SHA256_DIGEST_SIZE]; /* Used for storing the final digest. */
} AvbSHA256Ctx;


/* Initializes the SHA-256 context. */
void avb_sha256_init(AvbSHA256Ctx* ctx);

/* Updates the SHA-256 context with |len| bytes from |data|. */
void avb_sha256_update(AvbSHA256Ctx* ctx, const uint8_t* data, uint32_t len);

/* Returns the SHA-256 digest. */
uint8_t* avb_sha256_final(AvbSHA256Ctx* ctx) AVB_ATTR_WARN_UNUSED_RESULT;

void sha256(const uint8_t* data,
			   uint32_t length,
			   uint8_t hash[AVB_SHA256_DIGEST_SIZE]);

#ifdef __cplusplus
}
#endif

#endif /* AVB_SHA_H_ */
