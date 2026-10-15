/* SPDX-License-Identifier: ISC */
#ifndef _LINUX_IF_TRUSTSEC_H
#define _LINUX_IF_TRUSTSEC_H

#include <linux/types.h>
#include <linux/skbuff.h>

struct trustsec_hdr {
	u8 meta_hdr_ver;
	u8 meta_hdr_len;
	__be16 payload_len;
	u8 payload_opt_type;
	__be16 sgt;
};

#define TRUSTSEC_META_HDR_VERSION 0
#define TRUSTSEC_META_HDR_LEN 0
#define TRUSTSEC_PAYLOAD_LEN 0
#define TRUSTSEC_PAYLOAD_OPT_TYPE 0
#define ETH_P_TRSEC 0

static inline struct trustsec_hdr *trustsec_get_hdr(struct sk_buff *skb)
{
	return (struct trustsec_hdr *)skb->data;
}

static inline void trustsec_insert_hdr(struct sk_buff *skb, __be16 sgt)
{
}

#endif /* _LINUX_IF_TRUSTSEC_H */
