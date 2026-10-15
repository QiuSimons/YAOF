/*
 * sfe_cm.h
 *	Shortcut Forwarding Engine v2 Connection Manager header.
 *
 * Copyright (c) 2013-2016 The Linux Foundation. All rights reserved.
 * Permission to use, copy, modify, and/or distribute this software for
 * any purpose with or without fee is hereby granted, provided that the
 * above copyright notice and this permission notice appear in all copies.
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
 * OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#ifndef __SFE_CM_H
#define __SFE_CM_H

#include <linux/version.h>
#include <linux/types.h>
#include <linux/netdevice.h>

#define SFE_CREATE_FLAG_NO_SEQ_CHECK BIT(0)
#define SFE_CREATE_FLAG_REMARK_PRIORITY BIT(1)
#define SFE_CREATE_FLAG_REMARK_DSCP BIT(2)

struct sfe_ipv6_addr {
	__be32 addr[4];
};

typedef union {
	__be32			ip;
	struct sfe_ipv6_addr	ip6[1];
} sfe_ip_addr_t;

struct sfe_connection_create {
	int protocol;
	struct net_device *src_dev;
	struct net_device *dest_dev;
	u32 flags;
	u32 src_mtu;
	u32 dest_mtu;
	sfe_ip_addr_t src_ip;
	sfe_ip_addr_t src_ip_xlate;
	sfe_ip_addr_t dest_ip;
	sfe_ip_addr_t dest_ip_xlate;
	__be16 src_port;
	__be16 src_port_xlate;
	__be16 dest_port;
	__be16 dest_port_xlate;
	/*
	 * src_mac: source MAC as seen from the router, used in the return
	 * direction.  dest_mac_xlate: destination MAC after translation, used in the
	 * flow direction (see sfe_cm_v2_ipv4_create_rule()).
	 */
	u8 src_mac[ETH_ALEN];
	u8 dest_mac_xlate[ETH_ALEN];
	u8 src_td_window_scale;
	u32 src_td_max_window;
	u32 src_td_end;
	u32 src_td_max_end;
	u8 dest_td_window_scale;
	u32 dest_td_max_window;
	u32 dest_td_end;
	u32 dest_td_max_end;
	/*
	 * Connection mark and DSCP at offload time, pushed into the rule so the fast
	 * path keeps what the stack would have applied.
	 */
	u32 mark;
	u8 dscp;
	u32 src_priority;
	u32 dest_priority;
	u32 src_dscp;
	u32 dest_dscp;

	/* PPPoE Acceleration Support */
	bool flow_is_pppoe;
	bool return_is_pppoe;
	/*
	 * Set when a stacked side stays on its top device (pppoe-wan): the kernel does
	 * the PPPoE encapsulation there, so the engine must not do L2 work for it.
	 */
	bool flow_top_xmit;
	bool return_top_xmit;
	u16 flow_pppoe_session_id;
	u16 return_pppoe_session_id;
	u8 flow_pppoe_remote_mac[ETH_ALEN];
	u8 return_pppoe_remote_mac[ETH_ALEN];
	struct net_device *flow_top_dev;
	struct net_device *return_top_dev;
};

struct sfe_connection_destroy {
	int protocol;
	sfe_ip_addr_t src_ip;
	sfe_ip_addr_t dest_ip;
	__be16 src_port;
	__be16 dest_port;
};

struct sfe_connection_sync {
	struct net_device *src_dev;
	struct net_device *dest_dev;
	int is_v6;
	int protocol;
	sfe_ip_addr_t src_ip;
	sfe_ip_addr_t src_ip_xlate;
	__be16 src_port;
	__be16 src_port_xlate;
	sfe_ip_addr_t dest_ip;
	sfe_ip_addr_t dest_ip_xlate;
	__be16 dest_port;
	__be16 dest_port_xlate;
	u32 src_new_packet_count;
	u32 src_new_byte_count;
	u32 dest_new_packet_count;
	u32 dest_new_byte_count;
	u32 reason;
	u64 delta_jiffies;
};

static inline int sfe_ipv6_addr_equal(struct sfe_ipv6_addr *a, struct sfe_ipv6_addr *b)
{
	return a->addr[0] == b->addr[0] &&
	       a->addr[1] == b->addr[1] &&
	       a->addr[2] == b->addr[2] &&
	       a->addr[3] == b->addr[3];
}

#define sfe_ipv4_addr_equal(a, b) ((u32)(a) == (u32)(b))

static inline int sfe_addr_equal(sfe_ip_addr_t *a, sfe_ip_addr_t *b, int is_v4)
{
	return is_v4 ? sfe_ipv4_addr_equal(a->ip, b->ip) : sfe_ipv6_addr_equal(a->ip6, b->ip6);
}

#endif /* __SFE_CM_H */
