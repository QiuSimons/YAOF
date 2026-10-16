/*
 * sfe_compat.h
 *     Unified compatibility shim for Qualcomm Shortcut-FE v2
 *     Allows building SFE v2 on standard/vanilla Linux kernels (5.15 / 6.1 / 6.6 / 6.12)
 *     without any proprietary Qualcomm hardware or kernel patches.
 */

#ifndef _SFE_COMPAT_H_
#define _SFE_COMPAT_H_

#include <linux/udp.h>
#include <linux/tcp.h>
#include <linux/if_ether.h>
#include <linux/version.h>
#include <linux/types.h>
#include <linux/netdevice.h>
#include <linux/skbuff.h>
#include <linux/etherdevice.h>
#include <linux/if_vlan.h>
#include <linux/if_arp.h>
#include <net/rtnetlink.h>
#include <net/dst.h>
#include <net/route.h>
#include <linux/netfilter.h>
#include <linux/netfilter_ipv4.h>
#if defined(SFE_SUPPORT_IPV6)
#include <linux/netfilter_ipv6.h>
#endif
#include <net/sch_generic.h>
#include <net/pkt_sched.h>

#if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 11, 0))
#include <linux/unaligned.h>
#else
#include <asm/unaligned.h>
#endif

/* Debug memory tracing stub */
#define mem_debug_update_skb(skb) do {} while (0)

/*
 * Kernels carrying the QCA patch (CONFIG_SHORTCUT_FE) have a real fast_forwarded
 * bit in struct sk_buff, which keeps fast-forwarded packets away from the net
 * taps.  Without that bit the same flag is kept in the skb control buffer, which
 * the fast path owns end to end.
 */
#if !defined(CONFIG_SHORTCUT_FE)
#define fast_forwarded cb[47]
#endif

/* priv_flags_ext - QCA extension to struct net_device */
#define priv_flags_ext priv_flags
#define IFF_EXT_MAPT 0
#define IFF_EXT_ETH_L2TPV3 0

/* VLAN traversal */
#ifndef vlan_dev_next_dev
#define vlan_dev_next_dev(dev) (vlan_dev_priv(dev)->real_dev)
#endif

/* Tunnel type identification */
#ifndef netif_is_gre
static inline bool netif_is_gre(const struct net_device *dev)
{
	return dev->rtnl_link_ops &&
	       !strcmp(dev->rtnl_link_ops->kind, "gre");
}
#endif

#ifndef netif_is_ip6gre
static inline bool netif_is_ip6gre(const struct net_device *dev)
{
	return dev->rtnl_link_ops &&
	       !strcmp(dev->rtnl_link_ops->kind, "ip6gre");
}
#endif

/* IPPROTO_ETHERIP */
#ifndef IPPROTO_ETHERIP
#define IPPROTO_ETHERIP 97
#endif

/* dev_kfree_skb_list_fast */
static inline void dev_kfree_skb_list_fast(struct sk_buff_head *list)
{
	__skb_queue_purge(list);
}

/* Cisco TrustSec stubs */
#include "linux/if_trustsec.h"

/* QCA PPPoE manager stubs - supersede sfe_pppoe_mgr.h */
#ifndef _SFE_PPPOE_MGR_H_
#define _SFE_PPPOE_MGR_H_
struct sfe_pppoe_mgr_session_info {
	uint32_t session_id;
	uint8_t server_mac[ETH_ALEN];
};
struct sfe_pppoe_mgr_session_entry {
	struct sfe_pppoe_mgr_session_info info;
	struct net_device *dev;
	struct hlist_node hash_list;
};
/*
 * The QCA PPPoE session table is not part of this port.  Return true so the
 * upstream PPPoE bridge path is skipped instead of running without a session
 * check; the routed PPPoE acceleration does not go through this interface.
 */
static inline bool sfe_pppoe_mgr_find_session(uint16_t sid, uint8_t *mac) { return true; }
static inline int sfe_pppoe_mgr_init(void) { return 0; }
static inline void sfe_pppoe_mgr_exit(void) {}
#endif /* _SFE_PPPOE_MGR_H_ */

/* Linux 6.12 route scope compatibility */
#if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 12, 0))
#undef ip_route_output
static inline struct rtable *sfe_ip_route_output(struct net *net, __be32 daddr, __be32 saddr, u8 tos, int oif)
{
	struct flowi4 fl4 = {
		.flowi4_oif = oif,
		.flowi4_tos = tos,
		.flowi4_scope = RT_SCOPE_UNIVERSE,
		.daddr = daddr,
		.saddr = saddr,
	};
	return ip_route_output_key(net, &fl4);
}
#define ip_route_output(net, daddr, saddr, tos, oif) sfe_ip_route_output(net, daddr, saddr, tos, oif)
#endif

/*
 * Bypassable is the discipline's own call: TCQ_F_CAN_BYPASS, cleared by cake
 * and by any attached filter.  No enqueue: nothing to skip.
 */
static inline bool sfe_qdisc_is_bypassable(const struct Qdisc *q)
{
#ifdef TCQ_F_CAN_BYPASS
	if (!q || !q->enqueue)
		return true;

	return !!(q->flags & TCQ_F_CAN_BYPASS);
#else
	/* No such flag in this kernel: keep every queue. */
	return false;
#endif
}

/* The kernel's bypass precondition: declared bypassable and empty. */
static inline bool sfe_qdisc_allows_direct_xmit(const struct Qdisc *q)
{
	if (!q || !q->enqueue)
		return true;

	if (!sfe_qdisc_is_bypassable(q))
		return false;

	return !qdisc_qlen(q);
}

/*
 * Per direction cache: the verdict is a property of the queue, so it is resolved
 * on the first packet and later packets only re-validate the pointer.  A flag
 * cleared in place (a filter attached to this queue) is caught by the 1 s shaped
 * device scan, which drops the flow.
 */
struct sfe_xmit_qdisc_state {
	const struct Qdisc *q;
	bool bypassable;
	bool checked;
};

static inline bool sfe_qdisc_cached_allows(struct sfe_xmit_qdisc_state *st, const struct Qdisc *q)
{
	if (st) {
		if (likely(st->checked) && likely(st->q == q)) {
			if (unlikely(!st->bypassable))
				return false;

			return !qdisc_qlen(q);
		}

		st->q = q;
		st->bypassable = sfe_qdisc_is_bypassable(q);
		st->checked = true;
	}

	return sfe_qdisc_allows_direct_xmit(q);
}

/*
 * Conservative device level answer: a multiqueue container is not what packets
 * meet, so its per queue children are inspected instead.
 */
static inline bool sfe_dev_has_shaping_qdisc(struct net_device *dev)
{
	const struct Qdisc *q;
	unsigned int i;

	RCU_LOCKDEP_WARN(!rcu_read_lock_held() && !rcu_read_lock_bh_held(),
			 "sfe: qdisc probe outside of an RCU read side section");
	if (!dev)
		return false;

	q = rcu_dereference(dev->qdisc);
	if (!q || !q->ops)
		return false;

#ifdef TCQ_F_MQROOT
	if (q->flags & TCQ_F_MQROOT) {
		for (i = 0; i < dev->num_tx_queues; i++) {
			const struct netdev_queue *txq = netdev_get_tx_queue(dev, i);

			if (!sfe_qdisc_is_bypassable(rcu_dereference(txq->qdisc)))
				return true;
		}
		return false;
	}
#endif

	return !sfe_qdisc_is_bypassable(q);
}

static inline bool sfe_dev_has_tc_ingress(struct net_device *dev)
{
#ifdef CONFIG_NET_CLS_ACT
#if (LINUX_VERSION_CODE < KERNEL_VERSION(6, 6, 0))
	return rcu_access_pointer(dev->miniq_ingress) != NULL;
#else
	return rcu_access_pointer(dev->tcx_ingress) != NULL;
#endif
#else
	return false;
#endif
}

static inline bool sfe_dev_has_tc_egress(struct net_device *dev)
{
#ifdef CONFIG_NET_CLS_ACT
#if (LINUX_VERSION_CODE < KERNEL_VERSION(6, 6, 0))
	return rcu_access_pointer(dev->miniq_egress) != NULL;
#else
	return rcu_access_pointer(dev->tcx_egress) != NULL;
#endif
#else
	return false;
#endif
}

/* Optimistic device level answer for admission: is any queue bypassable? */
static inline bool sfe_dev_tx_may_bypass(struct net_device *dev)
{
	const struct Qdisc *q;
	unsigned int i;

	RCU_LOCKDEP_WARN(!rcu_read_lock_held() && !rcu_read_lock_bh_held(),
			 "sfe: qdisc probe outside of an RCU read side section");
	if (!dev)
		return false;

	/* Egress TC programs run inside dev_queue_xmit() and have to see the packet. */
	if (sfe_dev_has_tc_egress(dev))
		return false;

	q = rcu_dereference(dev->qdisc);
	if (!q || !q->ops)
		return false;

#ifdef TCQ_F_MQROOT
	if (q->flags & TCQ_F_MQROOT) {
		for (i = 0; i < dev->num_tx_queues; i++) {
			const struct netdev_queue *txq = netdev_get_tx_queue(dev, i);

			if (sfe_qdisc_is_bypassable(rcu_dereference(txq->qdisc)))
				return true;
		}
		return false;
	}
#endif

	return sfe_qdisc_is_bypassable(q);
}
/*
 * True when bypassing this device transmit path would skip egress traffic
 * control, i.e. when the qdisc or a TC egress program has to see the packets.
 */
static inline bool sfe_dev_tx_is_shaped(struct net_device *dev)
{
	if (!dev)
		return false;

	return sfe_dev_has_tc_egress(dev) || sfe_dev_has_shaping_qdisc(dev);
}

/*
 * True when bypassing this device would skip traffic control in either
 * direction.  Used for devices the engine never transmits on (the top device of a
 * stacked interface, e.g. pppoe-wan), whose ingress programs matter as well
 * because those packets are bypassed on the way in too.
 */
static inline bool sfe_dev_is_shaped(struct net_device *dev)
{
	if (!dev)
		return false;

	return sfe_dev_has_tc_ingress(dev) || sfe_dev_tx_is_shaped(dev);
}

/*
 * The engine marks forwarded packets CHECKSUM_PARTIAL and leaves csum_start and
 * csum_offset at zero, because the QCA NSS driver locates the L4 checksum from
 * the packet itself.  A mainline driver and the mainline stack need both
 * offsets, so fill them in when the engine left them unset: otherwise
 * validate_xmit_skb() -> skb_csum_hwoffload_help() -> skb_checksum_help() warns
 * and drops the packet.
 *  The engine may already have encapsulated the packet (PPPoE), so the L3 header
 *  is located through skb->network_header instead of skb->protocol.
 */
static inline void sfe_skb_complete_csum_offsets(struct sk_buff *skb)
{
	unsigned int l4_off;
	u8 proto, version;

	if (skb->ip_summed != CHECKSUM_PARTIAL || skb->csum_start)
		return;

	version = ip_hdr(skb)->version;
	if (version == 4) {
		const struct iphdr *iph = ip_hdr(skb);

		if (iph->ihl < 5 || (iph->frag_off & htons(IP_OFFSET)))
			return;

		l4_off = (unsigned int)skb->network_header + iph->ihl * 4;
		proto = iph->protocol;
	} else if (version == 6) {
		const struct ipv6hdr *ip6h = ipv6_hdr(skb);

		l4_off = (unsigned int)skb->network_header + sizeof(*ip6h);
		proto = ip6h->nexthdr;
	} else {
		return;
	}

	if (proto == IPPROTO_TCP)
		skb->csum_offset = offsetof(struct tcphdr, check);
	else if (proto == IPPROTO_UDP)
		skb->csum_offset = offsetof(struct udphdr, check);
	else
		return;

	skb->csum_start = l4_off;
}

/*
 * dev_fast_xmit - bypass the qdisc and call netdev_start_xmit() directly.
 * Returns false when the queue is full or stopped, or when the packet cannot be
 * handed to the driver as-is; the caller then uses dev_queue_xmit().
 */
#ifndef DEV_FAST_XMIT_SUPPORTED
static inline bool dev_fast_xmit_state(struct sk_buff *skb,
				 struct net_device *dev,
				 netdev_features_t features,
				 struct sfe_xmit_qdisc_state *st)
{
	struct netdev_queue *txq;
	u16 queue_index;
	int cpu;
	netdev_tx_t rc;

	if (unlikely(!(dev->flags & IFF_UP)))
		return false;

	/*
	 * validate_xmit_skb() is skipped here and sfe_fast_xmit_check() only saw the
	 * first packet of the direction, so its per packet cases are repeated here.
	 */
	if (unlikely(skb_vlan_tag_present(skb)))
		return false;

	if (unlikely(skb_sec_path(skb)))
		return false;

#ifdef CONFIG_SOCK_VALIDATE_XMIT
	if (unlikely(skb->sk && sk_fullsock(skb->sk) && skb->sk->sk_validate_xmit_skb))
		return false;
#endif

	if (unlikely(netif_needs_gso(skb, features)))
		return false;

	if (unlikely(skb_needs_linearize(skb, features)))
		return false;

	rcu_read_lock_bh();
	cpu = smp_processor_id();

	/* Egress TC runs inside dev_queue_xmit() and must see the packet. */
	if (unlikely(sfe_dev_has_tc_egress(dev)))
		goto fail;

	/*
	 * Mirror netdev_core_pick_tx(): drivers read skb_get_queue_mapping(), and the
	 * skb still carries the ingress device's receive queue.
	 */
	if (likely(dev->real_num_tx_queues == 1)) {
		/* One queue: nothing to select, but the mapping still needs a reset. */
		queue_index = 0;
		txq = netdev_get_tx_queue(dev, 0);
	} else {
		queue_index = netdev_cap_txqueue(dev, netdev_pick_tx(dev, skb, NULL));
		txq = netdev_get_tx_queue(dev, queue_index);
	}
	skb_set_queue_mapping(skb, queue_index);

	/*
	 * Only a declared bypassable, empty queue may be skipped.  Bail out before the
	 * dst is touched, so dev_queue_xmit() still finds the skb intact.
	 */
	if (unlikely(!sfe_qdisc_cached_allows(st, rcu_dereference(txq->qdisc))))
		goto fail;

	if (likely(dev->priv_flags & IFF_XMIT_DST_RELEASE)) {
		skb_dst_drop(skb);
	} else {
		if (unlikely(!skb_dst_force(skb)))
			goto fail;
	}

	if (likely(txq->xmit_lock_owner != cpu)) {
		HARD_TX_LOCK(dev, txq, cpu);
		if (likely(!netif_xmit_frozen_or_stopped(txq))) {
			skb->dev = dev;
			rc = netdev_start_xmit(skb, dev, txq, 0);
			if (unlikely(!dev_xmit_complete(rc))) {
				HARD_TX_UNLOCK(dev, txq);
				goto fail;
			}
			HARD_TX_UNLOCK(dev, txq);
			rcu_read_unlock_bh();
			return true;
		}
		HARD_TX_UNLOCK(dev, txq);
	}

fail:
	rcu_read_unlock_bh();
	return false;
}

static inline bool dev_fast_xmit_qdisc(struct sk_buff *skb, struct net_device *dev, struct net_device *qdisc_dev)
{
	return false;
}

/* Uncached entry point, for call sites without a per flow cache. */
static inline bool dev_fast_xmit(struct sk_buff *skb, struct net_device *dev, netdev_features_t features)
{
	return dev_fast_xmit_state(skb, dev, features, NULL);
}
#endif

#endif /* _SFE_COMPAT_H_ */
