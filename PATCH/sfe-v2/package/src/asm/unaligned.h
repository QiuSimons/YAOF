/* SPDX-License-Identifier: ISC */
#ifndef _ASM_UNALIGNED_H_COMPAT
#define _ASM_UNALIGNED_H_COMPAT

#include <linux/version.h>
#if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 11, 0))
#include <linux/unaligned.h>
#else
#include_next <asm/unaligned.h>
#endif

#endif /* _ASM_UNALIGNED_H_COMPAT */
