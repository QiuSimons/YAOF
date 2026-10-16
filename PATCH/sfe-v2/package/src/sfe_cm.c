/*
 * sfe_cm.c
 *	Shortcut Forwarding Engine v2 Connection Manager.
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

#include <linux/version.h>
#include <linux/module.h>
#include <linux/jiffies.h>
#include <linux/skbuff.h>
#include <linux/workqueue.h>
#include <net/ip.h>
#include <net/tcp.h>
#include <net/udp.h>
#include <net/route.h>
#include <net/dst.h>
#include <net/neighbour.h>
#include <net/netfilter/nf_conntrack.h>
#include <net/netfilter/nf_conntrack_acct.h>
#include <net/netfilter/nf_conntrack_helper.h>
#include <net/netfilter/nf_conntrack_zones.h>
#include <net/netfilter/nf_conntrack_core.h>
#include <linux/netfilter.h>
#include <linux/netfilter_ipv4.h>
#include <linux/netfilter_ipv6.h>
#include <linux/inetdevice.h>
#include <net/addrconf.h>
#include <net/sch_generic.h>
#include <net/pkt_sched.h>
#include <linux/percpu.h>
#include <linux/cpumask.h>

#include "sfe_cm.h"
#include "exports/sfe_api.h"

/*
 * Exported by the SFE v2 engine through the generic compatibility patch; they
 * are internal to the engine otherwise.
 */
extern void sfe_ipv4_destroy_all_rules_for_dev(struct net_device *dev);
extern void sfe_ipv6_destroy_all_rules_for_dev(struct net_device *dev);

/*
 * Kernel compatibility shims
 */
#if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 12, 0))
static inline struct rtable *sfe_cm_ip_route_output(struct net *net, __be32 daddr, __be32 saddr, u8 tos, int oif)
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
#else
#define sfe_cm_ip_route_output(net, daddr, saddr, tos, oif) ip_route_output(net, daddr, saddr, tos, oif)
#endif

#if (LINUX_VERSION_CODE >= KERNEL_VERSION(4, 3, 0))
#define SFE_NF_CT_DEFAULT_ZONE (&nf_ct_zone_dflt)
#else
#define SFE_NF_CT_DEFAULT_ZONE NF_CT_DEFAULT_ZONE
#endif

#if (LINUX_VERSION_CODE >= KERNEL_VERSION(3, 11, 0))
#define SFE_DEV_EVENT_PTR(ptr) netdev_notifier_info_to_dev(ptr)
#else
#define SFE_DEV_EVENT_PTR(ptr) ((struct net_device *)(ptr))
#endif

static inline struct net_device *sfe_dev_get_master(struct net_device *dev)
{
	struct net_device *master;
	rcu_read_lock();
	master = netdev_master_upper_dev_get_rcu(dev);
	if (master)
		dev_hold(master);
	rcu_read_unlock();
	return master;
}

static inline void sfe_cm_add_acct(struct nf_conn *ct, int dir, u64 pkts, u64 bytes)
{
#if (LINUX_VERSION_CODE >= KERNEL_VERSION(3, 13, 0))
	struct nf_conn_acct *acct = nf_conn_acct_find(ct);
	if (acct) {
		struct nf_conn_counter *counter = acct->counter;
		atomic64_add(pkts, &counter[dir].packets);
		atomic64_add(bytes, &counter[dir].bytes);
	}
#else
	struct nf_conn_counter *counter = nf_conn_acct_find(ct);
	if (counter) {
		atomic64_add(pkts, &counter[dir].packets);
		atomic64_add(bytes, &counter[dir].bytes);
	}
#endif
}

static inline u64 sfe_cm_get_pkt_count(struct nf_conn *ct)
{
#if (LINUX_VERSION_CODE >= KERNEL_VERSION(3, 13, 0))
	struct nf_conn_acct *acct = nf_conn_acct_find(ct);
	if (acct) {
		struct nf_conn_counter *counter = acct->counter;
		return atomic64_read(&counter[IP_CT_DIR_ORIGINAL].packets) +
		       atomic64_read(&counter[IP_CT_DIR_REPLY].packets);
	}
#else
	struct nf_conn_counter *counter = nf_conn_acct_find(ct);
	if (counter) {
		return atomic64_read(&counter[IP_CT_DIR_ORIGINAL].packets) +
		       atomic64_read(&counter[IP_CT_DIR_REPLY].packets);
	}
#endif
	return U64_MAX; /* Accounting disabled; do not delay offload */
}

/*
 * The fast path never touches conntrack, so an accelerated flow would time out of
 * the conntrack table and its counters would stop moving.  Drive the engine batch
 * synchronisation from here to keep both alive: the engine never walks its own
 * table, it answers the batches the connection manager asks for.
 */
#define SFE_CM_SYNC_INTERVAL_MS	1000
#define SFE_CM_STATUS_DEV_MAX	8
#define SFE_CM_SYNC_CHAIN_DELAY	1

#ifdef SFE_SUPPORT_IPV6
#define SFE_CM_SYNC_FAMILIES	2
#else
#define SFE_CM_SYNC_FAMILIES	1
#endif

/*
 * One round driver per address family: a busy IPv4 table must not drag IPv6
 * (or the other way round) through the same chain of wake-ups.
 */
struct sfe_cm_sync {
	struct delayed_work dwork;
	bool is_v4;
};

struct sfe_cm {
	struct notifier_block dev_notifier;
	struct notifier_block inet_notifier;
	struct notifier_block inet6_notifier;
};

static struct sfe_cm __sc;
static struct sfe_cm_sync sfe_cm_sync[SFE_CM_SYNC_FAMILIES];
static struct sfe_ctx_instance *sfe_v4_ctx;
#ifdef SFE_SUPPORT_IPV6
static struct sfe_ctx_instance *sfe_v6_ctx;
#endif

/*
 * Module parameters:
 * - delay_pkts: packets to leave in the stack before a flow is offloaded, so that
 *   proxies and DPI can inspect and claim it and short lived flows never enter
 *   the connection table.  Needs conntrack accounting, see sfe_cm_init().
 * - fast_xmit: hand frames straight to the driver.  A device whose egress path
 *   carries a qdisc or TC programs keeps its packets on dev_queue_xmit() instead
 *   (see sfe_compat.h).
 * - udp_require_reply: only offload a UDP flow that has already seen a reply, so
 *   one-way UDP (syslog, SNMP traps, RTP/IPTV) is not taken over prematurely.
 * - pppoe_top_xmit: keep a PPPoE side on the top device when it has traffic
 *   control, so pppoe-wan queue and TC programs stay in the path; 0 refuses such
 *   flows instead of moving them.
 * - dscp_remark, src_iface_check, tcp_no_seq_check: optional rule inputs.
 * - refuse_all_shaped: 1 refuses every flow meeting traffic control on the devices
 *   the engine uses; 0 (default) refuses only flows the stack steers elsewhere.
 */
static unsigned int sfe_cm_delay_pkts = 8;
module_param_named(delay_pkts, sfe_cm_delay_pkts, uint, 0644);
MODULE_PARM_DESC(delay_pkts, "Initial packets to leave in Linux stack before offloading (default 8)");

static bool sfe_cm_fast_xmit = true;
module_param_named(fast_xmit, sfe_cm_fast_xmit, bool, 0644);
MODULE_PARM_DESC(fast_xmit, "Enable direct hardware transmission where no SQM/TC-egress is active (default 1)");

static bool sfe_cm_udp_require_reply = true;
module_param_named(udp_require_reply, sfe_cm_udp_require_reply, bool, 0644);
MODULE_PARM_DESC(udp_require_reply, "Require a confirmed reply before offloading a UDP flow (default 1)");

static bool sfe_cm_pppoe_top_xmit = true;
module_param_named(pppoe_top_xmit, sfe_cm_pppoe_top_xmit, bool, 0644);
MODULE_PARM_DESC(pppoe_top_xmit, "Keep PPPoE flows accelerated through the top device when it has traffic control (default 1), 0 = refuse them");

/*
 * Optional rule features.  All three are off by default: they change what the
 * engine does to the packets of an accelerated flow and none of them is needed
 * for plain forwarding.
 */
static bool sfe_cm_dscp_remark;
module_param_named(dscp_remark, sfe_cm_dscp_remark, bool, 0644);
MODULE_PARM_DESC(dscp_remark, "Carry the DSCP a flow was offloaded with into both directions (default 0: every packet keeps its own DSCP)");

static bool sfe_cm_src_iface_check;
module_param_named(src_iface_check, sfe_cm_src_iface_check, bool, 0644);
MODULE_PARM_DESC(src_iface_check, "Only accelerate packets arriving on the device a flow was built for; others go to the stack (default 0)");

static bool sfe_cm_tcp_no_seq_check;
module_param_named(tcp_no_seq_check, sfe_cm_tcp_no_seq_check, bool, 0644);
MODULE_PARM_DESC(tcp_no_seq_check, "Skip the engine's TCP sequence and window validation (default 0)");

static bool sfe_cm_refuse_all_shaped;
module_param_named(refuse_all_shaped, sfe_cm_refuse_all_shaped, bool, 0644);
MODULE_PARM_DESC(refuse_all_shaped, "Refuse every flow meeting traffic control on its devices (default 0: refuse only flows the stack steers elsewhere)");

/*
 * delay_pkts counts packets through the conntrack accounting extension, so the
 * window cannot work without it.  Turn it on for as long as the module is loaded
 * and put the previous setting back on unload.  -1: not changed by this module.
 */
static int sfe_cm_acct_prev = -1;

/*
 * Counters for the status attribute.  They are only touched when a rule is
 * created, refused, flushed or destroyed, never per packet.
 */
static atomic64_t sfe_cm_stat_created = ATOMIC64_INIT(0);
static atomic64_t sfe_cm_stat_refused = ATOMIC64_INIT(0);
static atomic64_t sfe_cm_stat_flushed = ATOMIC64_INIT(0);
static atomic64_t sfe_cm_stat_engine_flushed = ATOMIC64_INIT(0);
static atomic64_t sfe_cm_stat_destroyed = ATOMIC64_INIT(0);
static atomic64_t sfe_cm_stat_mark_pushed = ATOMIC64_INIT(0);
static atomic64_t sfe_cm_stat_memo_added = ATOMIC64_INIT(0);

/* Admission only; the per packet check in dev_fast_xmit() decides. */
static inline bool sfe_cm_dev_can_fast_xmit(struct net_device *dev)
{
	if (!sfe_cm_fast_xmit || !dev)
		return false;

	return sfe_dev_tx_may_bypass(dev);
}

/*
 * PPPoE: the engine can write and strip the PPPoE header itself and send on the
 * bottom device, which skips the ppp queue.  It cannot honour traffic control
 * attached to the top device (pppoe-wan) in that mode, because neither its queue
 * nor its TC programs are on the path, so such a side is kept on the top device.
 */
static inline bool sfe_cm_pppoe_use_top(struct net_device *top_dev)
{
	return sfe_cm_pppoe_top_xmit && sfe_dev_is_shaped(top_dev);
}

/*
 * Fallback for pppoe_top_xmit=0: instead of moving the side to the top device,
 * refuse a side whose bypassed top device has traffic control, so its packets
 * take the ordinary kernel path with qdisc and TC included.
 */
static struct net_device *sfe_cm_bypass_refused(struct sfe_connection_create *sic,
						struct sk_buff *skb,
						enum ip_conntrack_info ctinfo)
{
	if (!sic->flow_top_xmit && sfe_dev_is_shaped(sic->flow_top_dev))
		return sic->flow_top_dev;

	if (!sic->return_top_xmit && sfe_dev_is_shaped(sic->return_top_dev))
		return sic->return_top_dev;

	if (unlikely(sfe_cm_refuse_all_shaped)) {
		/*
		 * Strict mode: refuse every flow meeting traffic control on the
		 * devices the engine uses; sfe_cm_shaped_dev_scan() destroys rules
		 * for exactly those.
		 */
		if (!sic->flow_top_xmit && sfe_dev_is_shaped(sic->dest_dev))
			return sic->dest_dev;

		if (!sic->return_top_xmit && sfe_dev_is_shaped(sic->src_dev))
			return sic->src_dev;
	} else if (!sic->flow_top_xmit && !sic->return_top_xmit) {
		struct net_device *want;

		/* The stack sends it somewhere else than the engine would. */
		want = (ctinfo >= IP_CT_IS_REPLY) ? sic->src_dev : sic->dest_dev;
		if (want && skb->dev != want)
			return skb->dev;
	}

	return NULL;
}

/*
 * status - read only summary for
 * /sys/module/shortcut_fe_cm/parameters/status
 */
static int sfe_cm_status_get(char *buffer, const struct kernel_param *kp)
{
	char *p = buffer;

	p += scnprintf(p, PAGE_SIZE - (p - buffer),
		       "delay_pkts=%u fast_xmit=%d udp_require_reply=%d pppoe_top_xmit=%d\n"
		       "dscp_remark=%d src_iface_check=%d tcp_no_seq_check=%d\n"
		       "rules_created=%llu rules_refused=%llu rule_sync=%llu engine_flushed=%llu "
		       "flows_destroyed=%llu marks_pushed=%llu refused_memos=%llu refuse_all_shaped=%d\n",
		       sfe_cm_delay_pkts, sfe_cm_fast_xmit, sfe_cm_udp_require_reply, sfe_cm_pppoe_top_xmit,
		       sfe_cm_dscp_remark, sfe_cm_src_iface_check, sfe_cm_tcp_no_seq_check,
		       (unsigned long long)atomic64_read(&sfe_cm_stat_created),
		       (unsigned long long)atomic64_read(&sfe_cm_stat_refused),
		       (unsigned long long)atomic64_read(&sfe_cm_stat_flushed),
		       (unsigned long long)atomic64_read(&sfe_cm_stat_engine_flushed),
		       (unsigned long long)atomic64_read(&sfe_cm_stat_destroyed),
		       (unsigned long long)atomic64_read(&sfe_cm_stat_mark_pushed),
		       (unsigned long long)atomic64_read(&sfe_cm_stat_memo_added),
		       sfe_cm_refuse_all_shaped);

	p += scnprintf(p, PAGE_SIZE - (p - buffer), "conntrack_acct=%d acct_enabled_by_us=%d\n",
		       nf_ct_acct_enabled(&init_net) ? 1 : 0, sfe_cm_acct_prev >= 0);
	p += scnprintf(p, PAGE_SIZE - (p - buffer), "qdisc=TCQ_F_CAN_BYPASS+Mqlen\n");

	/* Which devices bypass their queue and which stay in the kernel path. */
	{
		struct net_device *dev;
		int shown = 0;

		rcu_read_lock();
		for_each_netdev_rcu(&init_net, dev) {
			if (shown == SFE_CM_STATUS_DEV_MAX)
				break;
			if (!(dev->flags & IFF_UP) || !rcu_access_pointer(dev->qdisc))
				continue;

			p += scnprintf(p, PAGE_SIZE - (p - buffer), "  %s: %s%s%s\n",
				       dev->name,
				       sfe_dev_tx_may_bypass(dev) ? "direct" : "queue",
				       sfe_dev_has_tc_egress(dev) ? " tc-egress" : "",
				       sfe_dev_has_tc_ingress(dev) ? " tc-ingress" : "");
			shown++;
		}
		rcu_read_unlock();
	}

#if defined(SFE_SUPPORT_IPV6)
	p += scnprintf(p, PAGE_SIZE - (p - buffer), "max_connections ipv4=%d ipv6=%d\n",
		       sfe_ipv4_max_conn_count(), sfe_ipv6_max_conn_count());
#else
	p += scnprintf(p, PAGE_SIZE - (p - buffer), "max_connections ipv4=%d\n",
		       sfe_ipv4_max_conn_count());
#endif

	return p - buffer;
}

static const struct kernel_param_ops sfe_cm_status_ops = {
	.get = sfe_cm_status_get,
};

module_param_cb(status, &sfe_cm_status_ops, NULL, 0444);
MODULE_PARM_DESC(status, "Read only summary of the connection manager parameters and counters");

/*
 * DSCP (the six bit traffic class) of a packet that is about to be forwarded,
 * taken at rule creation, i.e. after the netfilter mangle chains ran.
 */
static inline u8 sfe_cm_skb_dscp(struct sk_buff *skb, bool is_v4)
{
	if (is_v4) {
		return (ip_hdr(skb)->tos & 0xfc) >> 2;
	}

	{
		const u8 *p = (const u8 *)ipv6_hdr(skb);
		return (u8)(((p[0] & 0x0f) << 2) | ((p[1] & 0xc0) >> 6));
	}
}

/*
 * A flow that was refused acceleration keeps walking through post-routing, so its
 * route and neighbour lookups would be repeated for every packet.  Remember the
 * conntrack entry in a per-CPU hash set to skip that work; an entry is dropped
 * when the conntrack entry dies.  A set instead of a ring, so the lookup cost
 * does not grow with the number of remembered flows.
 */
#define SFE_CM_NO_ACCEL_BUCKETS	1024	/* power of two, 8 KiB per CPU */
#define SFE_CM_NO_ACCEL_PROBE	4

struct sfe_cm_no_accel_set {
	struct nf_conn *ct[SFE_CM_NO_ACCEL_BUCKETS];
};

/*
 * Runtime allocated on purpose: a static table this size does not fit in
 * PERCPU_MODULE_RESERVE (8192 bytes per CPU on x86), so the module would never
 * load.  alloc_percpu() takes the dynamic pool instead.
 */
static struct sfe_cm_no_accel_set __percpu *sfe_cm_no_accel;

static inline unsigned int sfe_cm_no_accel_hash(const struct nf_conn *ct)
{
	unsigned long v = (unsigned long)ct;

	/* Mix: a bare shift maps whole slab pages onto a couple of buckets. */
	v ^= v >> 16;
	v *= 0x7feb352dUL;
	v ^= v >> 15;

	return (unsigned int)v & (SFE_CM_NO_ACCEL_BUCKETS - 1);
}

static bool sfe_cm_no_accel_test(struct nf_conn *ct)
{
	struct sfe_cm_no_accel_set *set;
	unsigned int h, i;
	bool found = false;

	if (unlikely(!sfe_cm_no_accel))
		return false;

	set = get_cpu_ptr(sfe_cm_no_accel);
	h = sfe_cm_no_accel_hash(ct);

	/*
	 * The whole window is walked: a slot vacated by a destroyed connection in
	 * front of this one must not hide it.  Four pointers, one cache line.
	 */
	for (i = 0; i < SFE_CM_NO_ACCEL_PROBE; i++) {
		if (READ_ONCE(set->ct[(h + i) & (SFE_CM_NO_ACCEL_BUCKETS - 1)]) == ct) {
			found = true;
			break;
		}
	}

	put_cpu_ptr(sfe_cm_no_accel);

	return found;
}

static void sfe_cm_no_accel_add(struct nf_conn *ct)
{
	struct sfe_cm_no_accel_set *set;
	unsigned int h, i;

	if (unlikely(!sfe_cm_no_accel))
		return;

	atomic64_inc(&sfe_cm_stat_memo_added);

	set = get_cpu_ptr(sfe_cm_no_accel);
	h = sfe_cm_no_accel_hash(ct);

	for (i = 0; i < SFE_CM_NO_ACCEL_PROBE; i++) {
		struct nf_conn **slot = &set->ct[(h + i) & (SFE_CM_NO_ACCEL_BUCKETS - 1)];

		if (!READ_ONCE(*slot) || READ_ONCE(*slot) == ct) {
			WRITE_ONCE(*slot, ct);
			break;
		}
	}

	/* Probe window full: displace the entry this one hashes to. */
	if (i == SFE_CM_NO_ACCEL_PROBE)
		WRITE_ONCE(set->ct[h], ct);

	put_cpu_ptr(sfe_cm_no_accel);
}

/*
 * Called from the conntrack destroy callback, which can run in atomic context:
 * only pointer comparisons happen here, never a dereference, so a forgotten
 * entry can at worst keep a recycled conntrack address out of the fast path.
 */
static void sfe_cm_no_accel_del(struct nf_conn *ct)
{
	int cpu;

	if (unlikely(!sfe_cm_no_accel))
		return;

	for_each_online_cpu(cpu) {
		struct sfe_cm_no_accel_set *set = per_cpu_ptr(sfe_cm_no_accel, cpu);
		unsigned int h = sfe_cm_no_accel_hash(ct), i;

		for (i = 0; i < SFE_CM_NO_ACCEL_PROBE; i++) {
			struct nf_conn **slot = &set->ct[(h + i) & (SFE_CM_NO_ACCEL_BUCKETS - 1)];

			if (READ_ONCE(*slot) == ct)
				WRITE_ONCE(*slot, NULL);
		}
	}
}

static void sfe_cm_sync_work(struct work_struct *work);
static void sfe_cm_shaped_dev_scan(void);

/*
 * Vanilla kernels have a single conntrack event notifier slot; it is taken over
 * here and re-claimed from the periodic work, in case somebody registers later.
 */
static void sfe_cm_conntrack_notifier_reclaim(void);

/*
 * SFE v2 API bridges
 */
static int sfe_cm_v2_ipv4_create_rule(struct sfe_connection_create *sic,
				      struct sk_buff *skb,
				      enum ip_conntrack_info ctinfo)
{
	struct sfe_ipv4_msg msg;
	struct net_device *shaped;

	if (unlikely(!sfe_v4_ctx))
		return -EINVAL;

	shaped = sfe_cm_bypass_refused(sic, skb, ctinfo);
	if (unlikely(shaped)) {
		pr_info_ratelimited("sfe_cm: leaving this flow to the kernel (%s)\n",
				    shaped->name);
		return -EOPNOTSUPP;
	}

	memset(&msg, 0, sizeof(msg));
	sfe_ipv4_msg_init(&msg, 0, SFE_TX_CREATE_RULE_MSG,
			  sizeof(struct sfe_ipv4_rule_create_msg), NULL, NULL);

	msg.msg.rule_create.valid_flags = SFE_RULE_CREATE_CONN_VALID;
	/*
	 * Fast transmit is decided per egress direction (dest_dev is the flow egress,
	 * src_dev the return egress), so a shaped side does not disable the other one.
	 */
	msg.msg.rule_create.rule_flags = SFE_RULE_CREATE_FLAG_ROUTED;
	if (sfe_cm_dev_can_fast_xmit(sic->dest_dev))
		msg.msg.rule_create.rule_flags |= SFE_RULE_CREATE_FLAG_FLOW_TRANSMIT_FAST;
	if (sfe_cm_dev_can_fast_xmit(sic->src_dev))
		msg.msg.rule_create.rule_flags |= SFE_RULE_CREATE_FLAG_RETURN_TRANSMIT_FAST;

	/*
	 * Optional: let the engine check that packets arrive on the device the rule
	 * was built for.  The no-flush variant is used so a mismatch only hands the
	 * packet to the stack; that keeps bridged LAN traffic working, where the L2
	 * hook sees the bridge port while the rule was built for the bridge device.
	 */
	if (sfe_cm_src_iface_check)
		msg.msg.rule_create.rule_flags |= SFE_RULE_CREATE_FLAG_FLOW_SRC_INTERFACE_CHECK_NO_FLUSH |
						  SFE_RULE_CREATE_FLAG_RETURN_SRC_INTERFACE_CHECK_NO_FLUSH;

	/*
	 * A PPPoE side consists of two devices: the bottom one the engine
	 * decapsulates from and encapsulates into, and the top one (pppoe-wan) the
	 * stack routes through.  Tell the engine which sides use the bottom device.
	 */
	if (sic->flow_is_pppoe)
		msg.msg.rule_create.rule_flags |= SFE_RULE_CREATE_FLAG_USE_FLOW_BOTTOM_INTERFACE;

	if (sic->return_is_pppoe)
		msg.msg.rule_create.rule_flags |= SFE_RULE_CREATE_FLAG_USE_RETURN_BOTTOM_INTERFACE;

	msg.msg.rule_create.tuple.protocol = sic->protocol;
	msg.msg.rule_create.tuple.flow_ip = sic->src_ip.ip;
	msg.msg.rule_create.tuple.return_ip = sic->dest_ip.ip;
	msg.msg.rule_create.tuple.flow_ident = sic->src_port;
	msg.msg.rule_create.tuple.return_ident = sic->dest_port;

	msg.msg.rule_create.conn_rule.flow_ip_xlate = sic->src_ip_xlate.ip;
	msg.msg.rule_create.conn_rule.return_ip_xlate = sic->dest_ip_xlate.ip;
	msg.msg.rule_create.conn_rule.flow_ident_xlate = sic->src_port_xlate;
	msg.msg.rule_create.conn_rule.return_ident_xlate = sic->dest_port_xlate;

	msg.msg.rule_create.conn_rule.flow_top_interface_num = sic->flow_top_dev ? sic->flow_top_dev->ifindex : sic->src_dev->ifindex;
	msg.msg.rule_create.conn_rule.return_top_interface_num = sic->return_top_dev ? sic->return_top_dev->ifindex : sic->dest_dev->ifindex;
	msg.msg.rule_create.conn_rule.flow_interface_num = sic->src_dev->ifindex;
	msg.msg.rule_create.conn_rule.return_interface_num = sic->dest_dev->ifindex;

	msg.msg.rule_create.conn_rule.flow_mtu = sic->src_mtu;
	msg.msg.rule_create.conn_rule.return_mtu = sic->dest_mtu;

	memcpy(msg.msg.rule_create.conn_rule.flow_mac, sic->src_mac, ETH_ALEN);
	/*
	 * return_mac is written when sending in the flow direction, i.e. towards the
	 * destination after translation, so it has to come from dest_ip_xlate.  Using
	 * the pre-NAT destination breaks DNAT flows: for a forwarded port that is the
	 * router's own WAN address, whose neighbour entry resolves to the loopback
	 * device and an all-zero MAC.
	 */
	memcpy(msg.msg.rule_create.conn_rule.return_mac, sic->dest_mac_xlate, ETH_ALEN);

	if (sic->flow_is_pppoe) {
		msg.msg.rule_create.valid_flags |= SFE_RULE_CREATE_PPPOE_DECAP_VALID;
		msg.msg.rule_create.pppoe_rule.flow_pppoe_session_id = sic->flow_pppoe_session_id;
		memcpy(msg.msg.rule_create.pppoe_rule.flow_pppoe_remote_mac, sic->flow_pppoe_remote_mac, ETH_ALEN);
	}

	if (sic->return_is_pppoe) {
		msg.msg.rule_create.valid_flags |= SFE_RULE_CREATE_PPPOE_ENCAP_VALID;
		msg.msg.rule_create.pppoe_rule.return_pppoe_session_id = sic->return_pppoe_session_id;
		memcpy(msg.msg.rule_create.pppoe_rule.return_pppoe_remote_mac, sic->return_pppoe_remote_mac, ETH_ALEN);
	}

	if (sic->protocol == IPPROTO_TCP) {
		msg.msg.rule_create.valid_flags |= SFE_RULE_CREATE_TCP_VALID;
		msg.msg.rule_create.tcp_rule.flow_max_window = sic->src_td_max_window;
		msg.msg.rule_create.tcp_rule.return_max_window = sic->dest_td_max_window;
		msg.msg.rule_create.tcp_rule.flow_end = sic->src_td_end;
		msg.msg.rule_create.tcp_rule.return_end = sic->dest_td_end;
		msg.msg.rule_create.tcp_rule.flow_max_end = sic->src_td_max_end;
		msg.msg.rule_create.tcp_rule.return_max_end = sic->dest_td_max_end;
		msg.msg.rule_create.tcp_rule.flow_window_scale = sic->src_td_window_scale;
		msg.msg.rule_create.tcp_rule.return_window_scale = sic->dest_td_window_scale;

		if (sic->flags & SFE_CREATE_FLAG_NO_SEQ_CHECK) {
			msg.msg.rule_create.rule_flags |= SFE_RULE_CREATE_FLAG_NO_SEQ_CHECK;
		}
	}

	if (sic->flags & SFE_CREATE_FLAG_REMARK_PRIORITY) {
		msg.msg.rule_create.valid_flags |= SFE_RULE_CREATE_QOS_VALID;
		msg.msg.rule_create.qos_rule.flow_qos_tag = sic->src_priority;
		msg.msg.rule_create.qos_rule.return_qos_tag = sic->dest_priority;
	}

	/*
	 * Carry the connection mark into the fast path so the qdisc (tc fw filters,
	 * cake tins) and later consumers still see it; without this, mark based policy
	 * is lost for every accelerated flow.
	 */
	if (sic->mark) {
		msg.msg.rule_create.valid_flags |= SFE_RULE_CREATE_MARK_VALID;
		msg.msg.rule_create.mark_rule.flow_mark = sic->mark;
		msg.msg.rule_create.mark_rule.return_mark = sic->mark;
	}

	if (sfe_cm_dscp_remark && sic->dscp) {
		msg.msg.rule_create.valid_flags |= SFE_RULE_CREATE_DSCP_MARKING_VALID;
		msg.msg.rule_create.dscp_rule.flow_dscp = sic->dscp;
		msg.msg.rule_create.dscp_rule.return_dscp = sic->dscp;
	}


	if (sfe_ipv4_tx_with_resp(sfe_v4_ctx, &msg) != SFE_CMN_RESPONSE_ACK) {
		return -EINVAL;
	}

	return 0;
}

static void sfe_cm_v2_ipv4_destroy_rule(struct sfe_connection_destroy *sid)
{
	struct sfe_ipv4_msg msg;

	if (unlikely(!sfe_v4_ctx))
		return;

	memset(&msg, 0, sizeof(msg));
	sfe_ipv4_msg_init(&msg, 0, SFE_TX_DESTROY_RULE_MSG,
			  sizeof(struct sfe_ipv4_rule_destroy_msg), NULL, NULL);

	msg.msg.rule_destroy.tuple.protocol = sid->protocol;
	msg.msg.rule_destroy.tuple.flow_ip = sid->src_ip.ip;
	msg.msg.rule_destroy.tuple.return_ip = sid->dest_ip.ip;
	msg.msg.rule_destroy.tuple.flow_ident = sid->src_port;
	msg.msg.rule_destroy.tuple.return_ident = sid->dest_port;

	sfe_ipv4_tx_with_resp(sfe_v4_ctx, &msg);
}

#ifdef SFE_SUPPORT_IPV6
static int sfe_cm_v2_ipv6_create_rule(struct sfe_connection_create *sic,
				      struct sk_buff *skb,
				      enum ip_conntrack_info ctinfo)
{
	struct sfe_ipv6_msg msg;
	struct net_device *shaped;

	if (unlikely(!sfe_v6_ctx))
		return -EINVAL;

	shaped = sfe_cm_bypass_refused(sic, skb, ctinfo);
	if (unlikely(shaped)) {
		pr_info_ratelimited("sfe_cm: leaving this flow to the kernel (%s)\n",
				    shaped->name);
		return -EOPNOTSUPP;
	}

	memset(&msg, 0, sizeof(msg));
	sfe_ipv6_msg_init(&msg, 0, SFE_TX_CREATE_RULE_MSG,
			  sizeof(struct sfe_ipv6_rule_create_msg), NULL, NULL);

	msg.msg.rule_create.valid_flags = SFE_RULE_CREATE_CONN_VALID;
	/* See sfe_cm_v2_ipv4_create_rule() for the per-device fast transmit logic. */
	msg.msg.rule_create.rule_flags = SFE_RULE_CREATE_FLAG_ROUTED;
	if (sfe_cm_dev_can_fast_xmit(sic->dest_dev))
		msg.msg.rule_create.rule_flags |= SFE_RULE_CREATE_FLAG_FLOW_TRANSMIT_FAST;
	if (sfe_cm_dev_can_fast_xmit(sic->src_dev))
		msg.msg.rule_create.rule_flags |= SFE_RULE_CREATE_FLAG_RETURN_TRANSMIT_FAST;

	/*
	 * Optional: let the engine check that packets arrive on the device the rule
	 * was built for.  The no-flush variant is used so a mismatch only hands the
	 * packet to the stack; that keeps bridged LAN traffic working, where the L2
	 * hook sees the bridge port while the rule was built for the bridge device.
	 */
	if (sfe_cm_src_iface_check)
		msg.msg.rule_create.rule_flags |= SFE_RULE_CREATE_FLAG_FLOW_SRC_INTERFACE_CHECK_NO_FLUSH |
						  SFE_RULE_CREATE_FLAG_RETURN_SRC_INTERFACE_CHECK_NO_FLUSH;

	/* See sfe_cm_v2_ipv4_create_rule() for the bottom interface rule. */
	if (sic->flow_is_pppoe)
		msg.msg.rule_create.rule_flags |= SFE_RULE_CREATE_FLAG_USE_FLOW_BOTTOM_INTERFACE;

	if (sic->return_is_pppoe)
		msg.msg.rule_create.rule_flags |= SFE_RULE_CREATE_FLAG_USE_RETURN_BOTTOM_INTERFACE;

	msg.msg.rule_create.tuple.protocol = sic->protocol;
	memcpy(msg.msg.rule_create.tuple.flow_ip, sic->src_ip.ip6[0].addr, sizeof(struct sfe_ipv6_addr));
	memcpy(msg.msg.rule_create.tuple.return_ip, sic->dest_ip.ip6[0].addr, sizeof(struct sfe_ipv6_addr));
	msg.msg.rule_create.tuple.flow_ident = sic->src_port;
	msg.msg.rule_create.tuple.return_ident = sic->dest_port;

	memcpy(msg.msg.rule_create.conn_rule.flow_ip_xlate, sic->src_ip_xlate.ip6[0].addr, sizeof(struct sfe_ipv6_addr));
	memcpy(msg.msg.rule_create.conn_rule.return_ip_xlate, sic->dest_ip_xlate.ip6[0].addr, sizeof(struct sfe_ipv6_addr));
	msg.msg.rule_create.conn_rule.flow_ident_xlate = sic->src_port_xlate;
	msg.msg.rule_create.conn_rule.return_ident_xlate = sic->dest_port_xlate;

	msg.msg.rule_create.conn_rule.flow_top_interface_num = sic->flow_top_dev ? sic->flow_top_dev->ifindex : sic->src_dev->ifindex;
	msg.msg.rule_create.conn_rule.return_top_interface_num = sic->return_top_dev ? sic->return_top_dev->ifindex : sic->dest_dev->ifindex;
	msg.msg.rule_create.conn_rule.flow_interface_num = sic->src_dev->ifindex;
	msg.msg.rule_create.conn_rule.return_interface_num = sic->dest_dev->ifindex;

	msg.msg.rule_create.conn_rule.flow_mtu = sic->src_mtu;
	msg.msg.rule_create.conn_rule.return_mtu = sic->dest_mtu;

	memcpy(msg.msg.rule_create.conn_rule.flow_mac, sic->src_mac, ETH_ALEN);
	/*
	 * return_mac is written when sending in the flow direction, i.e. towards the
	 * destination after translation, so it has to come from dest_ip_xlate.  Using
	 * the pre-NAT destination breaks DNAT flows: for a forwarded port that is the
	 * router's own WAN address, whose neighbour entry resolves to the loopback
	 * device and an all-zero MAC.
	 */
	memcpy(msg.msg.rule_create.conn_rule.return_mac, sic->dest_mac_xlate, ETH_ALEN);

	if (sic->flow_is_pppoe) {
		msg.msg.rule_create.valid_flags |= SFE_RULE_CREATE_PPPOE_DECAP_VALID;
		msg.msg.rule_create.pppoe_rule.flow_pppoe_session_id = sic->flow_pppoe_session_id;
		memcpy(msg.msg.rule_create.pppoe_rule.flow_pppoe_remote_mac, sic->flow_pppoe_remote_mac, ETH_ALEN);
	}

	if (sic->return_is_pppoe) {
		msg.msg.rule_create.valid_flags |= SFE_RULE_CREATE_PPPOE_ENCAP_VALID;
		msg.msg.rule_create.pppoe_rule.return_pppoe_session_id = sic->return_pppoe_session_id;
		memcpy(msg.msg.rule_create.pppoe_rule.return_pppoe_remote_mac, sic->return_pppoe_remote_mac, ETH_ALEN);
	}

	if (sic->protocol == IPPROTO_TCP) {
		msg.msg.rule_create.valid_flags |= SFE_RULE_CREATE_TCP_VALID;
		msg.msg.rule_create.tcp_rule.flow_max_window = sic->src_td_max_window;
		msg.msg.rule_create.tcp_rule.return_max_window = sic->dest_td_max_window;
		msg.msg.rule_create.tcp_rule.flow_end = sic->src_td_end;
		msg.msg.rule_create.tcp_rule.return_end = sic->dest_td_end;
		msg.msg.rule_create.tcp_rule.flow_max_end = sic->src_td_max_end;
		msg.msg.rule_create.tcp_rule.return_max_end = sic->dest_td_max_end;
		msg.msg.rule_create.tcp_rule.flow_window_scale = sic->src_td_window_scale;
		msg.msg.rule_create.tcp_rule.return_window_scale = sic->dest_td_window_scale;

		if (sic->flags & SFE_CREATE_FLAG_NO_SEQ_CHECK) {
			msg.msg.rule_create.rule_flags |= SFE_RULE_CREATE_FLAG_NO_SEQ_CHECK;
		}
	}

	/* Same rule features as the IPv4 side (this block was missing here). */
	if (sic->flags & SFE_CREATE_FLAG_REMARK_PRIORITY) {
		msg.msg.rule_create.valid_flags |= SFE_RULE_CREATE_QOS_VALID;
		msg.msg.rule_create.qos_rule.flow_qos_tag = sic->src_priority;
		msg.msg.rule_create.qos_rule.return_qos_tag = sic->dest_priority;
	}

	/*
	 * Carry the connection mark into the fast path so the qdisc (tc fw filters,
	 * cake tins) and later consumers still see it; without this, mark based policy
	 * is lost for every accelerated flow.
	 */
	if (sic->mark) {
		msg.msg.rule_create.valid_flags |= SFE_RULE_CREATE_MARK_VALID;
		msg.msg.rule_create.mark_rule.flow_mark = sic->mark;
		msg.msg.rule_create.mark_rule.return_mark = sic->mark;
	}

	if (sfe_cm_dscp_remark && sic->dscp) {
		msg.msg.rule_create.valid_flags |= SFE_RULE_CREATE_DSCP_MARKING_VALID;
		msg.msg.rule_create.dscp_rule.flow_dscp = sic->dscp;
		msg.msg.rule_create.dscp_rule.return_dscp = sic->dscp;
	}

	if (sfe_ipv6_tx_with_resp(sfe_v6_ctx, &msg) != SFE_CMN_RESPONSE_ACK) {
		return -EINVAL;
	}

	return 0;
}

static void sfe_cm_v2_ipv6_destroy_rule(struct sfe_connection_destroy *sid)
{
	struct sfe_ipv6_msg msg;

	if (unlikely(!sfe_v6_ctx))
		return;

	memset(&msg, 0, sizeof(msg));
	sfe_ipv6_msg_init(&msg, 0, SFE_TX_DESTROY_RULE_MSG,
			  sizeof(struct sfe_ipv6_rule_destroy_msg), NULL, NULL);

	msg.msg.rule_destroy.tuple.protocol = sid->protocol;
	memcpy(msg.msg.rule_destroy.tuple.flow_ip, sid->src_ip.ip6[0].addr, sizeof(struct sfe_ipv6_addr));
	memcpy(msg.msg.rule_destroy.tuple.return_ip, sid->dest_ip.ip6[0].addr, sizeof(struct sfe_ipv6_addr));
	msg.msg.rule_destroy.tuple.flow_ident = sid->src_port;
	msg.msg.rule_destroy.tuple.return_ident = sid->dest_port;

	sfe_ipv6_tx_with_resp(sfe_v6_ctx, &msg);
}
#endif

/*
 * Device and MAC lookup
 */
static bool sfe_cm_find_dev_and_mac_addr(sfe_ip_addr_t *addr, struct net_device **dev, u8 *mac_addr, int is_v4,
					 bool *is_pppoe, u16 *pppoe_sid, u8 *pppoe_mac, struct net_device **top_dev)
{
	struct neighbour *neigh;
	struct dst_entry *dst;
	struct net_device *mac_dev;

	if (is_pppoe)
		*is_pppoe = false;
	if (top_dev)
		*top_dev = NULL;

	if (likely(is_v4)) {
		struct rtable *rt = sfe_cm_ip_route_output(&init_net, addr->ip, 0, 0, 0);
		if (unlikely(IS_ERR(rt)))
			return false;
		dst = (struct dst_entry *)rt;
		rcu_read_lock();
		neigh = dst_neigh_lookup(dst, &addr->ip);
	} else {
#ifdef SFE_SUPPORT_IPV6
#if (LINUX_VERSION_CODE < KERNEL_VERSION(4, 17, 0))
		struct rt6_info *rt6 = rt6_lookup(&init_net, (struct in6_addr *)addr->ip6, 0, 0, 0);
#else
		struct rt6_info *rt6 = rt6_lookup(&init_net, (struct in6_addr *)addr->ip6, 0, 0, NULL, 0);
#endif
		if (!rt6)
			return false;
		dst = (struct dst_entry *)rt6;
		rcu_read_lock();
		neigh = dst_neigh_lookup(dst, (struct in6_addr *)addr->ip6);
#else
		return false;
#endif
	}

	if (unlikely(!neigh)) {
#if (LINUX_VERSION_CODE >= KERNEL_VERSION(5, 13, 0))
		if (dst->dev && (dst->dev->type == ARPHRD_PPP || (dst->dev->flags & IFF_POINTOPOINT))) {
			struct net_device_path_stack stack;
			if (dev_fill_forward_path(dst->dev, NULL, &stack) >= 0) {
				int i;
				for (i = 0; i < stack.num_paths; i++) {
					struct net_device_path *path = &stack.path[i];
					if (path->type == DEV_PATH_PPPOE && path->dev) {
						struct net_device *pppoe_dev = (struct net_device *)path->dev;

						/*
						 * dev_fill_forward_path() lists the PPPoE netdev (pppoe-wan)
						 * the stack routes through first and the device the frame
						 * leaves through last (eth0/eth0.x).  SFE writes the L2 and
						 * PPPoE headers itself, so the bottom device has to be its
						 * interface - handing the frame to the PPPoE netdev would
						 * encapsulate it a second time.  The PPPoE netdev is passed
						 * along as the top interface.
						 */
						mac_dev = (struct net_device *)stack.path[stack.num_paths - 1].dev;
						if (unlikely(!mac_dev))
							mac_dev = pppoe_dev;

						if (is_pppoe) {
							*is_pppoe = true;
							if (pppoe_sid)
								*pppoe_sid = path->encap.id;
							if (pppoe_mac)
								memcpy(pppoe_mac, path->encap.h_dest, ETH_ALEN);
							if (top_dev) {
								dev_hold(pppoe_dev);
								*top_dev = pppoe_dev;
							}
						}
						memcpy(mac_addr, path->encap.h_dest, ETH_ALEN);
						dev_hold(mac_dev);
						*dev = mac_dev;
						rcu_read_unlock();
						dst_release(dst);
						return true;
					}
				}
			}
		}
#endif
		rcu_read_unlock();
		dst_release(dst);
		return false;
	}

	if (unlikely(!(neigh->nud_state & NUD_VALID))) {
		rcu_read_unlock();
		neigh_release(neigh);
		dst_release(dst);
		return false;
	}

	mac_dev = neigh->dev;
	if (!mac_dev) {
		rcu_read_unlock();
		neigh_release(neigh);
		dst_release(dst);
		return false;
	}

	/*
	 * A point to point device has no usable L2 address: its PPPoE encapsulation is
	 * handled through dev_fill_forward_path() above, and accelerating it with what
	 * the neighbour holds (a zero MAC) sends every packet nowhere.
	 */
	if (unlikely(!mac_dev->addr_len || (mac_dev->flags & IFF_POINTOPOINT))) {
		rcu_read_unlock();
		neigh_release(neigh);
		dst_release(dst);
		return false;
	}

	memcpy(mac_addr, neigh->ha, ETH_ALEN);
	dev_hold(mac_dev);
	*dev = mac_dev;

	rcu_read_unlock();
	neigh_release(neigh);
	dst_release(dst);
	return true;
}

/*
 * Stats synchronization
 */
static void sfe_cm_sync_rule(struct sfe_connection_sync *sis)
{
	struct nf_conntrack_tuple_hash *h;
	struct nf_conntrack_tuple tuple;
	struct nf_conn *ct;

	memset(&tuple, 0, sizeof(tuple));
	tuple.src.u.all = (__be16)sis->src_port;
	tuple.dst.dir = IP_CT_DIR_ORIGINAL;
	tuple.dst.protonum = (u8)sis->protocol;
	tuple.dst.u.all = (__be16)sis->dest_port;

	if (sis->is_v6) {
		tuple.src.u3.in6 = *((struct in6_addr *)sis->src_ip.ip6);
		tuple.dst.u3.in6 = *((struct in6_addr *)sis->dest_ip.ip6);
		tuple.src.l3num = AF_INET6;
	} else {
		tuple.src.u3.ip = sis->src_ip.ip;
		tuple.dst.u3.ip = sis->dest_ip.ip;
		tuple.src.l3num = AF_INET;
	}

	h = nf_conntrack_find_get(&init_net, SFE_NF_CT_DEFAULT_ZONE, &tuple);
	if (unlikely(!h))
		return;

	ct = nf_ct_tuplehash_to_ctrack(h);

	if (!test_bit(IPS_FIXED_TIMEOUT_BIT, &ct->status)) {
		spin_lock_bh(&ct->lock);
#if (LINUX_VERSION_CODE < KERNEL_VERSION(4, 9, 0))
		ct->timeout.expires += sis->delta_jiffies;
#else
		ct->timeout += sis->delta_jiffies;
#endif
		spin_unlock_bh(&ct->lock);
	}

	sfe_cm_add_acct(ct, IP_CT_DIR_ORIGINAL, sis->src_new_packet_count, sis->src_new_byte_count);
	sfe_cm_add_acct(ct, IP_CT_DIR_REPLY, sis->dest_new_packet_count, sis->dest_new_byte_count);

	/*
	 * Keep the engine's copy of the connection mark in step with conntrack
	 * (policy routing and QoS marks can change while a flow is running).  Only
	 * marked flows pay for this, and only once per sync round.
	 */
	if (ct->mark) {
		struct sfe_connection_mark cmark;

		memset(&cmark, 0, sizeof(cmark));
		cmark.protocol = sis->protocol;
		cmark.src_port = sis->src_port;
		cmark.dest_port = sis->dest_port;
		cmark.flow_mark = ct->mark;
		cmark.return_mark = ct->mark;
		cmark.type = SFE_CONNECTION_MARK_TYPE_CONNMARK;

		if (sis->is_v6) {
#ifdef SFE_SUPPORT_IPV6
			memcpy(cmark.src_ip, sis->src_ip.ip6[0].addr, sizeof(cmark.src_ip));
			memcpy(cmark.dest_ip, sis->dest_ip.ip6[0].addr, sizeof(cmark.dest_ip));
			sfe_ipv6_mark_rule_update(&cmark);
#endif
		} else {
			cmark.src_ip[0] = sis->src_ip.ip;
			cmark.dest_ip[0] = sis->dest_ip.ip;
			sfe_ipv4_mark_rule_update(&cmark);
		}

		atomic64_inc(&sfe_cm_stat_mark_pushed);
	}

	nf_ct_put(ct);
}

static void sfe_cm_v2_ipv4_sync_many_callback(void *app_data, struct sfe_ipv4_msg *msg)
{
	struct sfe_ipv4_conn_sync_many_msg *many;
	int i;

	if (unlikely(!msg || msg->cm.type != SFE_TX_CONN_STATS_SYNC_MANY_MSG))
		return;

	many = &msg->msg.conn_stats_many;
	for (i = 0; i < many->count; i++) {
		struct sfe_ipv4_conn_sync *s = &many->conn_sync[i];
		struct sfe_connection_sync sis;

		memset(&sis, 0, sizeof(sis));
		sis.is_v6 = 0;
		sis.protocol = s->protocol;
		sis.src_ip.ip = s->flow_ip;
		sis.dest_ip.ip = s->return_ip;
		sis.src_port = s->flow_ident;
		sis.dest_port = s->return_ident;
		sis.src_new_packet_count = s->flow_rx_packet_count;
		sis.src_new_byte_count = s->flow_rx_byte_count;
		sis.dest_new_packet_count = s->return_rx_packet_count;
		sis.dest_new_byte_count = s->return_rx_byte_count;
		sis.reason = s->reason;
		/*
		 * The engine reports the elapsed time in milliseconds; conntrack
		 * timeouts are in jiffies.
		 */
		sis.delta_jiffies = msecs_to_jiffies(s->inc_ticks);

		sfe_cm_sync_rule(&sis);
	}

	/*
	 * Connections are left: keep the walk of this family going instead of
	 * waiting for the next round.
	 */
	if (many->next)
		mod_delayed_work(system_wq, &sfe_cm_sync[0].dwork, SFE_CM_SYNC_CHAIN_DELAY);
}

/*
 * The engine reports a rule it dropped on its own here (a packet it could not
 * handle, an eviction under pressure, a failed check).  Without this the flow
 * would vanish from the fast path while the connection manager still
 * treated it as accelerated.
 */
static void sfe_cm_v2_ipv4_one_sync_callback(void *app_data, struct sfe_ipv4_msg *msg)
{
	struct sfe_ipv4_conn_sync *s;

	if (unlikely(!msg || msg->cm.type != SFE_RX_CONN_STATS_SYNC_MSG))
		return;

	s = &msg->msg.conn_stats;
	atomic64_inc(&sfe_cm_stat_flushed);
	if (s->reason == SFE_RULE_SYNC_REASON_FLUSH ||
	    s->reason == SFE_RULE_SYNC_REASON_EVICT ||
	    s->reason == SFE_RULE_SYNC_REASON_FLUSH_SWITCH_AE)
		atomic64_inc(&sfe_cm_stat_engine_flushed);
	pr_debug_ratelimited("sfe_cm: engine dropped %pI4:%u -> %pI4:%u (proto %u reason %u cause %u, %u/%u pkts)\n",
			    &s->flow_ip, ntohs(s->flow_ident), &s->return_ip, ntohs(s->return_ident),
			    s->protocol, s->reason, s->cause,
			    s->flow_rx_packet_count, s->return_rx_packet_count);
}

#ifdef SFE_SUPPORT_IPV6
static void sfe_cm_v2_ipv6_sync_many_callback(void *app_data, struct sfe_ipv6_msg *msg)
{
	struct sfe_ipv6_conn_sync_many_msg *many;
	int i;

	if (unlikely(!msg || msg->cm.type != SFE_TX_CONN_STATS_SYNC_MANY_MSG))
		return;

	many = &msg->msg.conn_stats_many;
	for (i = 0; i < many->count; i++) {
		struct sfe_ipv6_conn_sync *s = &many->conn_sync[i];
		struct sfe_connection_sync sis;

		memset(&sis, 0, sizeof(sis));
		sis.is_v6 = 1;
		sis.protocol = s->protocol;
		memcpy(sis.src_ip.ip6[0].addr, s->flow_ip, sizeof(struct sfe_ipv6_addr));
		memcpy(sis.dest_ip.ip6[0].addr, s->return_ip, sizeof(struct sfe_ipv6_addr));
		sis.src_port = s->flow_ident;
		sis.dest_port = s->return_ident;
		sis.src_new_packet_count = s->flow_rx_packet_count;
		sis.src_new_byte_count = s->flow_rx_byte_count;
		sis.dest_new_packet_count = s->return_rx_packet_count;
		sis.dest_new_byte_count = s->return_rx_byte_count;
		sis.reason = s->reason;
		/* The engine reports the elapsed time in milliseconds. */
		sis.delta_jiffies = msecs_to_jiffies(s->inc_ticks);

		sfe_cm_sync_rule(&sis);
	}

	if (many->next)
		mod_delayed_work(system_wq, &sfe_cm_sync[1].dwork, SFE_CM_SYNC_CHAIN_DELAY);
}

/* See sfe_cm_v2_ipv4_one_sync_callback(). */
static void sfe_cm_v2_ipv6_one_sync_callback(void *app_data, struct sfe_ipv6_msg *msg)
{
	struct sfe_ipv6_conn_sync *s;

	if (unlikely(!msg || msg->cm.type != SFE_RX_CONN_STATS_SYNC_MSG))
		return;

	s = &msg->msg.conn_stats;
	atomic64_inc(&sfe_cm_stat_flushed);
	if (s->reason == SFE_RULE_SYNC_REASON_FLUSH ||
	    s->reason == SFE_RULE_SYNC_REASON_EVICT ||
	    s->reason == SFE_RULE_SYNC_REASON_FLUSH_SWITCH_AE)
		atomic64_inc(&sfe_cm_stat_engine_flushed);
	pr_debug_ratelimited("sfe_cm: engine dropped [%pI6]:%u -> [%pI6]:%u (proto %u reason %u cause %u)\n",
			    s->flow_ip, ntohs(s->flow_ident), s->return_ip, ntohs(s->return_ident),
			    s->protocol, s->reason, s->cause);
}
#endif

/*
 * sfe_cm_sync_request()
 *	Ask the engine for one batch of connection statistics; the answer arrives
 *	asynchronously through the sync_many callback.
 */
static void sfe_cm_sync_request(bool is_v4)
{
	if (is_v4) {
		struct sfe_ipv4_msg msg;

		if (unlikely(!sfe_v4_ctx))
			return;

		memset(&msg, 0, sizeof(msg));
		sfe_ipv4_msg_init(&msg, 0, SFE_TX_CONN_STATS_SYNC_MANY_MSG,
				  sizeof(struct sfe_ipv4_conn_sync_many_msg), NULL, NULL);
		sfe_ipv4_tx(sfe_v4_ctx, &msg);
		return;
	}

#ifdef SFE_SUPPORT_IPV6
	{
		struct sfe_ipv6_msg msg;

		if (unlikely(!sfe_v6_ctx))
			return;

		memset(&msg, 0, sizeof(msg));
		sfe_ipv6_msg_init(&msg, 0, SFE_TX_CONN_STATS_SYNC_MANY_MSG,
				  sizeof(struct sfe_ipv6_conn_sync_many_msg), NULL, NULL);
		sfe_ipv6_tx(sfe_v6_ctx, &msg);
	}
#endif
}

/*
 * sfe_cm_sync_work()
 *	Round driver for the connection synchronisation of one address family.
 */
static void sfe_cm_sync_work(struct work_struct *work)
{
	struct sfe_cm_sync *sync = container_of(work, struct sfe_cm_sync, dwork.work);

	/*
	 * Re-claim the conntrack event notifier slot (vanilla kernels
	 * only, a no-op otherwise).
	 */
	sfe_cm_conntrack_notifier_reclaim();

	/*
	 * A device that gains traffic control invalidates the rules built for it
	 * earlier; drop them so they are rebuilt with the new egress state.
	 */
	if (sync->is_v4)
		sfe_cm_shaped_dev_scan();

	sfe_cm_sync_request(sync->is_v4);

	/*
	 * Batches that report work left re-queue this work earlier; this is only
	 * the "start a new round" and lost-response safety net.
	 */
	schedule_delayed_work(&sync->dwork, msecs_to_jiffies(SFE_CM_SYNC_INTERVAL_MS));
}

/*
 * Post-routing packet inspection and rule creation
 */
static unsigned int sfe_cm_post_routing(struct sk_buff *skb, int is_v4)
{
	struct sfe_connection_create sic;
	struct net_device *src_dev, *dest_dev;
	struct net_device *src_dev_tmp = NULL, *dest_dev_tmp = NULL;
	struct net_device *src_br_dev = NULL, *dest_br_dev = NULL;
	enum ip_conntrack_info ctinfo;
	struct nf_conn *ct;
	struct nf_conntrack_tuple orig_tuple, reply_tuple;
	int result;

	if (unlikely(skb->pkt_type == PACKET_BROADCAST || skb->pkt_type == PACKET_MULTICAST))
		return NF_ACCEPT;

	if (skb->sk)
		return NF_ACCEPT;

	/* Locally generated packets carry no input device; they are never offloaded. */
	if (!skb->skb_iif)
		return NF_ACCEPT;

	ct = nf_ct_get(skb, &ctinfo);
	if (unlikely(!ct))
		return NF_ACCEPT;

#if (LINUX_VERSION_CODE < KERNEL_VERSION(4, 12, 0))
	if (unlikely(nf_ct_is_untracked(ct)))
		return NF_ACCEPT;
#else
	if (unlikely(ctinfo == IP_CT_UNTRACKED))
		return NF_ACCEPT;
#endif

	if (!nf_ct_is_confirmed(ct))
		return NF_ACCEPT;

	if (unlikely(nf_ct_is_dying(ct)))
		return NF_ACCEPT;

	/*
	 * Leave the first sfe_cm_delay_pkts packets to the stack: proxies and DPI
	 * get a window to claim the flow, and short lived flows stay out of the
	 * connection table.  Cheapest exit, so it comes first.
	 */
	if (sfe_cm_delay_pkts && sfe_cm_get_pkt_count(ct) < sfe_cm_delay_pkts)
		return NF_ACCEPT;

	/* A refused flow is not examined again on every packet. */
	if (unlikely(sfe_cm_no_accel_test(ct)))
		return NF_ACCEPT;

	/*
	 * A packet mark the engine cannot reproduce means a netfilter rule steers
	 * this flow: the rule only carries ct->mark, so accelerating it would drop
	 * the mark and with it policy routing, tproxy and qdisc classification.
	 * Decided here so a refused flow never pays for the device lookup; with
	 * refuse_all_shaped the stricter device check above already covered it.
	 */
	if (unlikely(!sfe_cm_refuse_all_shaped && skb->mark && skb->mark != ct->mark)) {
		atomic64_inc(&sfe_cm_stat_refused);
		sfe_cm_no_accel_add(ct);
		return NF_ACCEPT;
	}

	struct nf_conn_help *help = nfct_help(ct);

	if (unlikely(help)) {
		struct nf_conntrack_helper *helper = rcu_dereference(help->helper);

		/*
		 * BCM-NAT/BCM-NAT6 only set up an expectation on the first packet and
		 * never inspect payloads, and the mapping is kept alive by a permanent
		 * expectation, so these flows are safe to accelerate; any other ALG
		 * must keep seeing every packet.
		 */
		if (!helper || (strcmp(helper->name, "BCM-NAT") != 0 &&
				strcmp(helper->name, "BCM-NAT6") != 0))
			return NF_ACCEPT;
	}

	orig_tuple = ct->tuplehash[IP_CT_DIR_ORIGINAL].tuple;
	reply_tuple = ct->tuplehash[IP_CT_DIR_REPLY].tuple;

	memset(&sic, 0, sizeof(sic));
	sic.protocol = orig_tuple.dst.protonum;

	if (is_v4) {
		sic.src_ip.ip = orig_tuple.src.u3.ip;
		sic.dest_ip.ip = orig_tuple.dst.u3.ip;
		sic.src_ip_xlate.ip = reply_tuple.dst.u3.ip;
		sic.dest_ip_xlate.ip = reply_tuple.src.u3.ip;
	} else {
#ifdef SFE_SUPPORT_IPV6
		sic.src_ip.ip6[0] = *((struct sfe_ipv6_addr *)&orig_tuple.src.u3.in6);
		sic.dest_ip.ip6[0] = *((struct sfe_ipv6_addr *)&orig_tuple.dst.u3.in6);
		sic.src_ip_xlate.ip6[0] = *((struct sfe_ipv6_addr *)&reply_tuple.dst.u3.in6);
		sic.dest_ip_xlate.ip6[0] = *((struct sfe_ipv6_addr *)&reply_tuple.src.u3.in6);
#else
		return NF_ACCEPT;
#endif
	}

	switch (sic.protocol) {
	case IPPROTO_TCP:
		sic.src_port = orig_tuple.src.u.tcp.port;
		sic.dest_port = orig_tuple.dst.u.tcp.port;
		sic.src_port_xlate = reply_tuple.dst.u.tcp.port;
		sic.dest_port_xlate = reply_tuple.src.u.tcp.port;
		sic.src_td_window_scale = ct->proto.tcp.seen[0].td_scale;
		sic.src_td_max_window = ct->proto.tcp.seen[0].td_maxwin;
		sic.src_td_end = ct->proto.tcp.seen[0].td_end;
		sic.src_td_max_end = ct->proto.tcp.seen[0].td_maxend;
		sic.dest_td_window_scale = ct->proto.tcp.seen[1].td_scale;
		sic.dest_td_max_window = ct->proto.tcp.seen[1].td_maxwin;
		sic.dest_td_end = ct->proto.tcp.seen[1].td_end;
		sic.dest_td_max_end = ct->proto.tcp.seen[1].td_maxend;

		if (!test_bit(IPS_ASSURED_BIT, &ct->status))
			return NF_ACCEPT;

		spin_lock_bh(&ct->lock);
		if (ct->proto.tcp.state != TCP_CONNTRACK_ESTABLISHED) {
			spin_unlock_bh(&ct->lock);
			return NF_ACCEPT;
		}
		spin_unlock_bh(&ct->lock);
		break;

	case IPPROTO_UDP:
		/*
		 * Only confirmed bidirectional UDP sessions are offloaded; one-way
		 * flows (syslog, SNMP traps, RTP/IPTV) stay out unless
		 * udp_require_reply=0.
		 */
		if (sfe_cm_udp_require_reply && !test_bit(IPS_SEEN_REPLY_BIT, &ct->status))
			return NF_ACCEPT;

		sic.src_port = orig_tuple.src.u.udp.port;
		sic.dest_port = orig_tuple.dst.u.udp.port;
		sic.src_port_xlate = reply_tuple.dst.u.udp.port;
		sic.dest_port_xlate = reply_tuple.src.u.udp.port;
		break;

	default:
		return NF_ACCEPT;
	}

	if (skb->priority) {
		sic.dest_priority = skb->priority;
		sic.src_priority = sic.dest_priority;
		sic.flags |= SFE_CREATE_FLAG_REMARK_PRIORITY;
	}

	/*
	 * Optional rule inputs: the connection mark is always carried over, DSCP
	 * and the TCP sequence check are opt in.
	 */
	sic.mark = ct->mark;
	if (sfe_cm_dscp_remark)
		sic.dscp = sfe_cm_skb_dscp(skb, is_v4);
	if (sfe_cm_tcp_no_seq_check)
		sic.flags |= SFE_CREATE_FLAG_NO_SEQ_CHECK;

	if (!sfe_cm_find_dev_and_mac_addr(&sic.src_ip, &src_dev_tmp, sic.src_mac, is_v4,
					  &sic.flow_is_pppoe, &sic.flow_pppoe_session_id, sic.flow_pppoe_remote_mac, &sic.flow_top_dev))
		return NF_ACCEPT;
	src_dev = src_dev_tmp;

	/*
	 * Neither address lookup is done: the translated source never reaches an
	 * L2 header, and the untranslated destination is wrong for DNAT'ed flows
	 * (see sfe_cm_v2_ipv4_create_rule()).
	 */
	if (!sfe_cm_find_dev_and_mac_addr(&sic.dest_ip_xlate, &dest_dev_tmp, sic.dest_mac_xlate, is_v4,
					  &sic.return_is_pppoe, &sic.return_pppoe_session_id, sic.return_pppoe_remote_mac, &sic.return_top_dev))
		goto done1;
	dest_dev = dest_dev_tmp;

	if (src_dev->priv_flags & IFF_BRIDGE_PORT) {
		src_br_dev = sfe_dev_get_master(src_dev);
		if (!src_br_dev)
			goto done2;
		src_dev = src_br_dev;
	}

	if (dest_dev->priv_flags & IFF_BRIDGE_PORT) {
		dest_br_dev = sfe_dev_get_master(dest_dev);
		if (!dest_br_dev)
			goto done3;
		dest_dev = dest_br_dev;
	}

	/*
	 * See sfe_cm_pppoe_use_top(): a stacked side with a shaped top device
	 * stays on that top device, so the kernel keeps encapsulating PPPoE.
	 */
	if (sic.flow_is_pppoe && sfe_cm_pppoe_use_top(sic.flow_top_dev)) {
		src_dev = sic.flow_top_dev;
		sic.flow_is_pppoe = false;
		sic.flow_top_xmit = true;
	}

	if (sic.return_is_pppoe && sfe_cm_pppoe_use_top(sic.return_top_dev)) {
		dest_dev = sic.return_top_dev;
		sic.return_is_pppoe = false;
		sic.return_top_xmit = true;
	}

	sic.src_dev = src_dev;
	sic.dest_dev = dest_dev;
	sic.src_mtu = src_dev->mtu;
	sic.dest_mtu = dest_dev->mtu;

	/*
	 * A PPPoE session on top of the transmitting device carries the smaller MTU;
	 * the engine sizes and fragments on what it is told here.
	 */
	if (sic.flow_is_pppoe && sic.flow_top_dev && sic.flow_top_dev->mtu < sic.src_mtu)
		sic.src_mtu = sic.flow_top_dev->mtu;
	if (sic.return_is_pppoe && sic.return_top_dev && sic.return_top_dev->mtu < sic.dest_mtu)
		sic.dest_mtu = sic.return_top_dev->mtu;

	if (likely(is_v4)) {
		result = sfe_cm_v2_ipv4_create_rule(&sic, skb, ctinfo);
	} else {
#ifdef SFE_SUPPORT_IPV6
		result = sfe_cm_v2_ipv6_create_rule(&sic, skb, ctinfo);
#else
		result = -EINVAL;
#endif
	}

	if (likely(!result)) {
		atomic64_inc(&sfe_cm_stat_created);
	} else {
		atomic64_inc(&sfe_cm_stat_refused);
		sfe_cm_no_accel_add(ct);
	}

	if (dest_br_dev)
		dev_put(dest_br_dev);
done3:
	if (src_br_dev)
		dev_put(src_br_dev);
done2:
	dev_put(dest_dev_tmp);
done1:
	if (sic.flow_top_dev)
		dev_put(sic.flow_top_dev);
	if (sic.return_top_dev)
		dev_put(sic.return_top_dev);
	dev_put(src_dev_tmp);

	return NF_ACCEPT;
}

#if (LINUX_VERSION_CODE >= KERNEL_VERSION(4, 4, 0))
static unsigned int sfe_cm_ipv4_post_routing_hook(void *priv, struct sk_buff *skb, const struct nf_hook_state *state)
{
	return sfe_cm_post_routing(skb, 1);
}

#ifdef SFE_SUPPORT_IPV6
static unsigned int sfe_cm_ipv6_post_routing_hook(void *priv, struct sk_buff *skb, const struct nf_hook_state *state)
{
	return sfe_cm_post_routing(skb, 0);
}
#endif
#else
static unsigned int sfe_cm_ipv4_post_routing_hook(unsigned int hooknum, struct sk_buff *skb,
						  const struct net_device *in, const struct net_device *out,
						  int (*okfn)(struct sk_buff *))
{
	return sfe_cm_post_routing(skb, 1);
}

#ifdef SFE_SUPPORT_IPV6
static unsigned int sfe_cm_ipv6_post_routing_hook(unsigned int hooknum, struct sk_buff *skb,
						  const struct net_device *in, const struct net_device *out,
						  int (*okfn)(struct sk_buff *))
{
	return sfe_cm_post_routing(skb, 0);
}
#endif
#endif

/*
 * Conntrack destroy event monitoring.
 *
 * Kernels with the multi-registrant patch (CONFIG_NF_CONNTRACK_CHAIN_EVENTS) give
 * every user its own notifier; vanilla kernels have a single slot, which is taken
 * over and forwarded to its previous owner.
 */
static void sfe_cm_conntrack_destroy(unsigned int events, const struct nf_ct_event *item)
{
	struct sfe_connection_destroy sid;
	struct nf_conn *ct;
	struct nf_conntrack_tuple orig_tuple;

	if (unlikely(!(events & (1 << IPCT_DESTROY))))
		return;

	if (unlikely(!item || !item->ct))
		return;

	ct = item->ct;

	atomic64_inc(&sfe_cm_stat_destroyed);
	sfe_cm_no_accel_del(ct);

	orig_tuple = ct->tuplehash[IP_CT_DIR_ORIGINAL].tuple;
	memset(&sid, 0, sizeof(sid));
	sid.protocol = orig_tuple.dst.protonum;

	switch (sid.protocol) {
	case IPPROTO_TCP:
		sid.src_port = orig_tuple.src.u.tcp.port;
		sid.dest_port = orig_tuple.dst.u.tcp.port;
		break;
	case IPPROTO_UDP:
		sid.src_port = orig_tuple.src.u.udp.port;
		sid.dest_port = orig_tuple.dst.u.udp.port;
		break;
	default:
		return;
	}

	if (likely(nf_ct_l3num(ct) == AF_INET)) {
		sid.src_ip.ip = orig_tuple.src.u3.ip;
		sid.dest_ip.ip = orig_tuple.dst.u3.ip;
		sfe_cm_v2_ipv4_destroy_rule(&sid);
	} else if (likely(nf_ct_l3num(ct) == AF_INET6)) {
#ifdef SFE_SUPPORT_IPV6
		sid.src_ip.ip6[0] = *((struct sfe_ipv6_addr *)&orig_tuple.src.u3.in6);
		sid.dest_ip.ip6[0] = *((struct sfe_ipv6_addr *)&orig_tuple.dst.u3.in6);
		sfe_cm_v2_ipv6_destroy_rule(&sid);
#endif
	}
}

#ifdef CONFIG_NF_CONNTRACK_CHAIN_EVENTS
static int sfe_cm_conntrack_event(struct notifier_block *this, unsigned long events, void *ptr)
{
	sfe_cm_conntrack_destroy((unsigned int)events, ptr);
	return NOTIFY_DONE;
}

static struct notifier_block sfe_cm_conntrack_notifier = {
	.notifier_call = sfe_cm_conntrack_event,
};

static void sfe_cm_conntrack_notifier_reclaim(void)
{
}
#else
static const struct nf_ct_event_notifier __rcu *sfe_cm_prev_notifier;
static struct nf_ct_event_notifier sfe_cm_conntrack_notifier;

static int sfe_cm_ct_event(unsigned int events, const struct nf_ct_event *item)
{
	const struct nf_ct_event_notifier *prev;
	int ret = 0;

	sfe_cm_conntrack_destroy(events, item);

	/* Keep the previous owner of the slot (ctnetlink) functional. */
	rcu_read_lock();
	prev = rcu_dereference(sfe_cm_prev_notifier);
	if (prev && prev != &sfe_cm_conntrack_notifier && prev->ct_event)
		ret = prev->ct_event(events, item);
	rcu_read_unlock();

	return ret;
}

static int sfe_cm_exp_event(unsigned int events, const struct nf_exp_event *item)
{
	const struct nf_ct_event_notifier *prev;
	int ret = 0;

	rcu_read_lock();
	prev = rcu_dereference(sfe_cm_prev_notifier);
	if (prev && prev->exp_event)
		ret = prev->exp_event(events, item);
	rcu_read_unlock();

	return ret;
}

static struct nf_ct_event_notifier sfe_cm_conntrack_notifier = {
	.ct_event = sfe_cm_ct_event,
	.exp_event = sfe_cm_exp_event,
};

/*
 * sfe_cm_conntrack_notifier_reclaim()
 *	Own the (single) conntrack event notifier slot, remembering its previous
 *	owner so its events can be forwarded.
 */
static DEFINE_MUTEX(sfe_cm_conntrack_notifier_lock);

static void sfe_cm_conntrack_notifier_reclaim(void)
{
	const struct nf_ct_event_notifier *cur;

	mutex_lock(&sfe_cm_conntrack_notifier_lock);

	cur = rcu_access_pointer(init_net.ct.nf_conntrack_event_cb);
	if (cur == &sfe_cm_conntrack_notifier)
		goto out;

	rcu_assign_pointer(sfe_cm_prev_notifier, cur);
	nf_conntrack_unregister_notifier(&init_net);
	nf_conntrack_register_notifier(&init_net, &sfe_cm_conntrack_notifier);
out:
	mutex_unlock(&sfe_cm_conntrack_notifier_lock);
}

/*
 * sfe_cm_conntrack_notifier_release()
 *	Hand the notifier slot back to its previous owner.
 */
static void sfe_cm_conntrack_notifier_release(void)
{
	const struct nf_ct_event_notifier *prev;

	mutex_lock(&sfe_cm_conntrack_notifier_lock);

	if (rcu_access_pointer(init_net.ct.nf_conntrack_event_cb) != &sfe_cm_conntrack_notifier)
		goto out;

	rcu_read_lock();
	prev = rcu_dereference(sfe_cm_prev_notifier);
	rcu_read_unlock();

	nf_conntrack_unregister_notifier(&init_net);
	if (prev)
		nf_conntrack_register_notifier(&init_net, prev);
out:
	mutex_unlock(&sfe_cm_conntrack_notifier_lock);
}
#endif

static struct nf_hook_ops sfe_cm_ops_post_routing[] __read_mostly = {
	{
		.hook = sfe_cm_ipv4_post_routing_hook,
		.pf = NFPROTO_IPV4,
		.hooknum = NF_INET_POST_ROUTING,
		.priority = NF_IP_PRI_NAT_SRC + 1,
	},
#ifdef SFE_SUPPORT_IPV6
	{
		.hook = sfe_cm_ipv6_post_routing_hook,
		.pf = NFPROTO_IPV6,
		.hooknum = NF_INET_POST_ROUTING,
		.priority = NF_IP6_PRI_NAT_SRC + 1,
	},
#endif
};

/*
 * sfe_cm_flush_dev()
 *	Drop every accelerated flow using a device; a rule caches the device, its
 *	MAC and the PPPoE session, so it must not outlive them.
 */
static void sfe_cm_flush_dev(struct net_device *dev)
{
	if (unlikely(!dev))
		return;

	sfe_ipv4_destroy_all_rules_for_dev(dev);

#ifdef SFE_SUPPORT_IPV6
	sfe_ipv6_destroy_all_rules_for_dev(dev);
#endif
}

/*
 * Traffic control can appear on a device (including one the engine bypasses)
 * after flows were built, and those flows would keep skipping it.  The periodic
 * work drops the flows of a device the first time it becomes shaped.
 *
 * Only the sync work touches the list, no locking is needed.
 */
#define SFE_CM_SHAPED_DEV_MAX	64
static int sfe_cm_shaped_devs[SFE_CM_SHAPED_DEV_MAX];

static void sfe_cm_shaped_dev_scan(void)
{
	int seen[SFE_CM_SHAPED_DEV_MAX] = { 0 };
	int nseen = 0;
	int i, j;

	rcu_read_lock();
	{
		struct net_device *dev;

		for_each_netdev_rcu(&init_net, dev) {
			if (nseen == SFE_CM_SHAPED_DEV_MAX) {
				pr_warn_ratelimited("sfe_cm: more than %d traffic control devices, some accelerated flows are not revoked\n",
						    SFE_CM_SHAPED_DEV_MAX);
				break;
			}

			/*
			 * Both directions matter: a bypassed ingress program on a
			 * stacked top device is only noticed by the flush below.
			 */
			if (sfe_dev_is_shaped(dev))
				seen[nseen++] = dev->ifindex;
		}
	}
	rcu_read_unlock();

	for (i = 0; i < nseen; i++) {
		struct net_device *dev;

		for (j = 0; j < SFE_CM_SHAPED_DEV_MAX; j++) {
			if (sfe_cm_shaped_devs[j] == seen[i])
				break;
		}

		if (j != SFE_CM_SHAPED_DEV_MAX)
			continue;

		dev = dev_get_by_index(&init_net, seen[i]);
		if (!dev)
			continue;

		pr_info("sfe_cm: %s now does traffic control, dropping its accelerated flows\n",
			dev->name);
		sfe_cm_flush_dev(dev);
		dev_put(dev);
	}

	memset(sfe_cm_shaped_devs, 0, sizeof(sfe_cm_shaped_devs));
	memcpy(sfe_cm_shaped_devs, seen, sizeof(int) * nseen);
}

static int sfe_cm_device_event(struct notifier_block *this, unsigned long event, void *ptr)
{
	struct net_device *dev = SFE_DEV_EVENT_PTR(ptr);

	/*
	 * A rule caches the device, its MAC and the transmit features taken at
	 * creation, so any change of those drops it.
	 */
	if (dev && (event == NETDEV_DOWN || event == NETDEV_UNREGISTER ||
		    event == NETDEV_CHANGEADDR || event == NETDEV_FEAT_CHANGE ||
		    event == NETDEV_CHANGEMTU))
		sfe_cm_flush_dev(dev);

	return NOTIFY_DONE;
}

static int sfe_cm_inet_event(struct notifier_block *this, unsigned long event, void *ptr)
{
	struct in_ifaddr *ifa = ptr;

	/*
	 * Address notifiers report NETDEV_DOWN and carry the ifaddr going away.
	 */
	if (ifa && ifa->ifa_dev && (event == NETDEV_DOWN))
		sfe_cm_flush_dev(ifa->ifa_dev->dev);

	return NOTIFY_DONE;
}

static int sfe_cm_inet6_event(struct notifier_block *this, unsigned long event, void *ptr)
{
	struct inet6_ifaddr *ifa = ptr;

	if (ifa && ifa->idev && (event == NETDEV_DOWN))
		sfe_cm_flush_dev(ifa->idev->dev);

	return NOTIFY_DONE;
}

static int __init sfe_cm_init(void)
{
	struct sfe_cm *sc = &__sc;
	int result = -1;

	pr_info("sfe_cm: Qualcomm Shortcut-FE v2 Connection Manager loading\n");

	sfe_cm_no_accel = alloc_percpu(struct sfe_cm_no_accel_set);
	if (!sfe_cm_no_accel) {
		pr_err("sfe_cm: failed to allocate the no-accel cache\n");
		return -ENOMEM;
	}

	/*
	 * The accounting extension is added when a conntrack entry is allocated, so
	 * it has to be enabled before the flows to hold back are created.
	 */
	if (sfe_cm_delay_pkts) {
		if (!nf_ct_acct_enabled(&init_net)) {
			sfe_cm_acct_prev = init_net.ct.sysctl_acct;
			init_net.ct.sysctl_acct = 1;
			pr_info("sfe_cm: enabled conntrack accounting for delay_pkts=%u\n",
				sfe_cm_delay_pkts);
		}

		if (!nf_ct_acct_enabled(&init_net)) {
			/* Cannot happen on supported kernels; refuse to pretend. */
			pr_warn("sfe_cm: conntrack accounting unavailable, delay_pkts=%u is turned off\n",
				sfe_cm_delay_pkts);
			sfe_cm_delay_pkts = 0;
		} else {
			pr_info("sfe_cm: holding the first %u packets of every flow in the kernel stack\n",
				sfe_cm_delay_pkts);
		}
	}

	pr_info("sfe_cm: fast_xmit=%d udp_require_reply=%d\n",
		sfe_cm_fast_xmit, sfe_cm_udp_require_reply);

	sfe_cm_sync[0].is_v4 = true;
	INIT_DELAYED_WORK(&sfe_cm_sync[0].dwork, sfe_cm_sync_work);

#ifdef SFE_SUPPORT_IPV6
	sfe_cm_sync[1].is_v4 = false;
	INIT_DELAYED_WORK(&sfe_cm_sync[1].dwork, sfe_cm_sync_work);
#endif

	sfe_v4_ctx = sfe_ipv4_notify_register(sfe_cm_v2_ipv4_one_sync_callback,
					      sfe_cm_v2_ipv4_sync_many_callback, NULL);
	if (!sfe_v4_ctx) {
		pr_err("sfe_cm: failed to register with SFE v2 IPv4 engine\n");
		if (sfe_cm_acct_prev >= 0)
			init_net.ct.sysctl_acct = sfe_cm_acct_prev;
		free_percpu(sfe_cm_no_accel);
		sfe_cm_no_accel = NULL;
		return -ENODEV;
	}

#ifdef SFE_SUPPORT_IPV6
	sfe_v6_ctx = sfe_ipv6_notify_register(sfe_cm_v2_ipv6_one_sync_callback,
					      sfe_cm_v2_ipv6_sync_many_callback, NULL);
	if (!sfe_v6_ctx) {
		pr_warn("sfe_cm: failed to register with SFE v2 IPv6 engine\n");
	}
#endif

	sc->dev_notifier.notifier_call = sfe_cm_device_event;
	sc->dev_notifier.priority = 1;
	register_netdevice_notifier(&sc->dev_notifier);

	sc->inet_notifier.notifier_call = sfe_cm_inet_event;
	sc->inet_notifier.priority = 1;
	register_inetaddr_notifier(&sc->inet_notifier);

	sc->inet6_notifier.notifier_call = sfe_cm_inet6_event;
	sc->inet6_notifier.priority = 1;
	register_inet6addr_notifier(&sc->inet6_notifier);

#ifdef CONFIG_NF_CONNTRACK_CHAIN_EVENTS
	result = nf_conntrack_register_notifier(&init_net, &sfe_cm_conntrack_notifier);
	if (result < 0) {
		pr_err("sfe_cm: failed to register conntrack notifier: %d\n", result);
		goto exit_fail;
	}
#else
	sfe_cm_conntrack_notifier_reclaim();
#endif

	result = nf_register_net_hooks(&init_net, sfe_cm_ops_post_routing, ARRAY_SIZE(sfe_cm_ops_post_routing));
	if (result < 0) {
		pr_err("sfe_cm: failed to register post routing hooks: %d\n", result);
#ifdef CONFIG_NF_CONNTRACK_CHAIN_EVENTS
		nf_conntrack_unregister_notifier(&init_net, &sfe_cm_conntrack_notifier);
#else
		sfe_cm_conntrack_notifier_release();
#endif
		goto exit_fail;
	}

	schedule_delayed_work(&sfe_cm_sync[0].dwork, msecs_to_jiffies(SFE_CM_SYNC_INTERVAL_MS));

#ifdef SFE_SUPPORT_IPV6
	schedule_delayed_work(&sfe_cm_sync[1].dwork, msecs_to_jiffies(SFE_CM_SYNC_INTERVAL_MS));
#endif

	pr_info("sfe_cm: SFE v2 Connection Manager successfully initialized\n");
	return 0;

exit_fail:
	unregister_inet6addr_notifier(&sc->inet6_notifier);
	unregister_inetaddr_notifier(&sc->inet_notifier);
	unregister_netdevice_notifier(&sc->dev_notifier);
	sfe_ipv4_notify_unregister();
#ifdef SFE_SUPPORT_IPV6
	if (sfe_v6_ctx)
		sfe_ipv6_notify_unregister();
#endif
	/* The module never ran: leave the accounting sysctl as we found it. */
	if (sfe_cm_acct_prev >= 0)
		init_net.ct.sysctl_acct = sfe_cm_acct_prev;

	free_percpu(sfe_cm_no_accel);
	sfe_cm_no_accel = NULL;
	return result;
}

static void __exit sfe_cm_exit(void)
{
	struct sfe_cm *sc = &__sc;

	pr_info("sfe_cm: unloading\n");

	nf_unregister_net_hooks(&init_net, sfe_cm_ops_post_routing, ARRAY_SIZE(sfe_cm_ops_post_routing));
#ifdef CONFIG_NF_CONNTRACK_CHAIN_EVENTS
	nf_conntrack_unregister_notifier(&init_net, &sfe_cm_conntrack_notifier);
#else
	sfe_cm_conntrack_notifier_release();
#endif

	unregister_inet6addr_notifier(&sc->inet6_notifier);
	unregister_inetaddr_notifier(&sc->inet_notifier);
	unregister_netdevice_notifier(&sc->dev_notifier);

	sfe_ipv4_notify_unregister();
#ifdef SFE_SUPPORT_IPV6
	if (sfe_v6_ctx)
		sfe_ipv6_notify_unregister();
#endif

	/*
	 * Both engines drained their work above; only now can a callback no
	 * longer rearm the sync work.
	 */
	cancel_delayed_work_sync(&sfe_cm_sync[0].dwork);
#ifdef SFE_SUPPORT_IPV6
	cancel_delayed_work_sync(&sfe_cm_sync[1].dwork);
#endif

	/*
	 * Restore accounting only if this module enabled it and it was not changed
	 * since.
	 */
	if (sfe_cm_acct_prev >= 0 && nf_ct_acct_enabled(&init_net))
		init_net.ct.sysctl_acct = sfe_cm_acct_prev;

	synchronize_rcu();

	free_percpu(sfe_cm_no_accel);
	sfe_cm_no_accel = NULL;
}

module_init(sfe_cm_init);
module_exit(sfe_cm_exit);

MODULE_AUTHOR("Qualcomm Atheros, Inc.");
MODULE_DESCRIPTION("Shortcut Forwarding Engine v2 Connection Manager");
MODULE_LICENSE("Dual BSD/GPL");
