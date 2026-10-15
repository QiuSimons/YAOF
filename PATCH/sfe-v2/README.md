# Shortcut-FE v2 (SFE v2) 通用移植指南

本目录包含高通 Shortcut-FE v2（基于 QSDK 14.0，`NHSS.QSDK.14.0.r1-00011-O`）针对通用平台（x86/ARM/MIPS）与标准 Linux 内核（5.15 ~ 6.12）的移植包与相关文档。

不依赖 NSS、PPE 或任何高通专用硬件芯片，在原生内核上即可作为外部模块运行。

可选内核补丁（`PATCH/kernel/sfe/`）提供进一步性能增强：
* `952`（`CONFIG_NF_CONNTRACK_CHAIN_EVENTS`）：支持多注册者的 conntrack 事件链通知。
* `953`（`CONFIG_SHORTCUT_FE`）：提供 L2 `netif_receive` 入口钩子、skb 快速转发标记位及网桥统计更新。
在 OpenWrt 源码树中选中 `kmod-shortcut-fe-cm` 会自动通过包级 `KCONFIG` 启用上述配置。若在未打补丁的通用内核或独立 SDK 中编译，模块会自动回退至 Netfilter `PREROUTING` 钩子运行。

---

## 1. 目录结构

`@text
PATCH/sfe-v2/
├── package/             # OpenWrt 源码包（提供 kmod-shortcut-fe 与 kmod-shortcut-fe-cm）
│   ├── Makefile         # 编译规则，集成防火墙配置与 ucitrack 联动
│   ├── patches/         # 单一兼容补丁（001-openwrt-generic-compat.patch）
│   ├── src/             # 连接管理器、兼容层与桩头文件
│   │   ├── sfe_cm.c     # 控制面（conntrack 同步、时钟嘀嗒续期、规则下发）
│   │   ├── sfe_cm.h
│   │   ├── sfe_compat.h # 通用内核兼容层与模块内联 dev_fast_xmit
│   │   ├── asm/unaligned.h
│   │   └── linux/       # debug_mem_usage.h / if_trustsec.h
│   └── files/           # 运行时服务与工具
│       ├── etc/init.d/shortcut-fe             # 防火墙按需启停脚本
│       ├── usr/bin/sfe_dump                  # 状态与统计导出工具
│       └── usr/share/ucitrack/shortcut-fe.json # LuCI 防火墙热重载配置
└── README.md            # 本文件
`@

---

## 2. 补丁与设计精简说明

原版 QSDK SFE 针对高通私有内核及 NSS 硬件设计，移植到通用内核只需解决通用兼容与控制面挂接。

### 2.1 兼容补丁（`001-openwrt-generic-compat.patch`）
* **构建系统（Makefile）**：
  * 去除 `-Werror`，去除对私有 `sfe_pppoe_mgr.o` 的依赖；
  * 集成 `shortcut-fe-cm.o` 联合构建；
  * 引入 `-include $(src)/sfe_compat.h`，跨内核版本兼容垫片统一收敛于头文件处理。
* **双模 Ingress 接收钩子**：
  * 初始化时动态探测 `athrs_fast_nat_recv`。命中 953 补丁则在 L2 `netif_receive` 阶段接管；未打补丁时优先挂 netdev ingress 钩子（`NFPROTO_NETDEV` / `NF_NETDEV_INGRESS`，位于 tc 之后、IP 栈之前），内核没有 `CONFIG_NETFILTER_INGRESS` 时再回退到 Netfilter `NF_INET_PRE_ROUTING`。
* **数据面（sfe_ipv4_*.c / sfe_ipv6_*.c）**：
  * 移除 PPE 硬件虚表（`xmit_dev->offload_ops`）调用，转为软件直发。
* **规则管理接口导出**：
  * 导出 `sfe_ipv4_destroy_all_rules_for_dev()` / `sfe_ipv6_destroy_all_rules_for_dev()` 供连接管理器调用；
  * 规则匹配范围扩展至双向 `top_interface_dev`，保证 PPPoE 与 bridge 等虚拟接口注销时能够完整清理规则。
* **PPPoE 设备分层识别**：
  * 连接管理器通过 `dev_fill_forward_path()` 识别底层物理网卡与顶层虚拟接口（`pppoe-wan`），并设置 `SFE_RULE_CREATE_FLAG_USE_FLOW/RETURN_BOTTOM_INTERFACE`。

> **本次变更（待提交）**：`sfe_cm_shaped_dev_scan()` 的判据仍为 `sfe_dev_is_shaped()`，即入向与出向都参与判定；曾短暂改为 `sfe_dev_tx_is_shaped()`，但那会让"flow 建立之后才在入向挂上 TC 程序的设备"永远不被扫描到（`sfe_cm_bypass_refused()` 处理的是引擎在入向绕过的堆叠顶层设备），从而永久绕过其入向流控，已回退。

### 2.2 出向路径与 SQM / TC 动态自适应（`fast_xmit`）
SFE 默认通过 `SFE_RULE_CREATE_FLAG_FLOW/RETURN_TRANSMIT_FAST` 绕过内核 Qdisc 队列调度层，直接调用网卡驱动 `ndo_start_xmit()` 发送，可显著提高转发吞吐并降低延迟。为兼容 SQM 流控与 TC 规则，当前版本实现动态自适应检测：

* **判据来自内核，不维护任何队列名单**：
  能不能跳过某个队列由**队列自己声明**：`TCQ_F_CAN_BYPASS`（`pfifo`/`pfifo_fast`/`bfifo`、`codel`/`fq_codel`、`sfq` 按各自 limit 置位；`cake` 主动清除；`net/sched/cls_api.c` 在**任何 filter 挂到该队列时**清除它，因为 filter 必须看到每个包）；无 enqueue 的 `noqueue`/`noop` 本身无可跳过。
  直发条件与内核 `__dev_xmit_skb()` 完全一致：**标志置位 且 队列为空**（`qdisc_qlen()`）——因此不会把包送过一个内核自己都不会跳过的整形器，也不可能让包越过仍在队列里的包（不引入乱序）。
  * 每包判定落在**该包实际使用的那个 txq 的 qdisc** 上（`rcu_dereference(txq->qdisc)`）：`mq` 设备只有被挂 `cake` 的那个队列让路，其余队列照旧直发（不再靠名字识别 `mq`，多队列容器按 `TCQ_F_MQROOT` 结构判定）。
  * 未自行声明的队列（`cake`、`htb`、`tbf`、`hfsc`、`netem`、`red`、`sfb`、`pie`/`fq_pie`、`dualpi2`、`fq`…）、以及**未知/第三方队列**一律保留在内核路径上——**判据缺失只损失直发，永不误跳过流控**；内核没有该标志时同样一律保留。
  * 逃生口是内核标准动作：想让某个 qdisc 一定被尊重，给它挂任意一个 filter 即可（内核自动清除其 `TCQ_F_CAN_BYPASS`），SFE 侧零配置。
* **TC 过滤器感知**：出向在**每包热路径**上判定（`dev_fast_xmit()` 内）；TCP/UDP 把"该队列是否可绕过"按方向缓存一次（`sfe_xmit_qdisc_state`，存于引擎的连接匹配结构），之后每包只校验 qdisc 指针与队列是否为空。入向、以及引擎会在入向绕过的堆叠顶层设备由后台扫描判定（`sfe_dev_is_shaped()` → `sfe_dev_has_shaping_qdisc()`）；两者共用同一套内核判据（见 `sfe_compat.h`）。
* **GSO 包只影响自己**：GRO 之后成形的 GSO 包不能在这里重写，它单独走内核路径，但**不再**把该方向的 `FAST_XMIT` 永久清掉（后续非 GSO 包仍可直发）。
* **双向独立决策**：分别评估入向与出向设备。若 WAN 口配置 SQM，上行流量清除 `TRANSMIT_FAST` 回退至内核 `dev_queue_xmit()` 正常排队；LAN 口无流控时，下行流量仍保持直发驱动。
* **PPPoE 虚拟接口流控兼容（`pppoe_top_xmit`）**：
  当顶层接口（`pppoe-wan`）存在流控时：
  * `pppoe_top_xmit=1`（默认）：改由顶层接口发包。SFE 仅加速 IP 转发，PPPoE 报头封装与排队调度交由内核 PPP 驱动处理，兼顾转发性能与流量控制；
  * `pppoe_top_xmit=0`：对该类连接不予加速，交由内核协议栈标准转发。
* **运行时状态追踪与平滑降级**：
  * 发包路径在 RCU 读临界区内实时检查**出向**流控状态，若网卡新增出向流控即时降级为 `dev_queue_xmit()`；
  * 后台任务定期扫描设备状态，对新增流控的设备主动调用 `sfe_destroy_all_rules_for_dev()` 清理规则，使存量连接平滑回退至内核协议栈。
* **全局开关**：设置模块参数 `fast_xmit=0` 可全局强制统一走 `dev_queue_xmit()`。

### 2.3 前置包延迟卸载机制（`delay_pkts`）
控制面支持 `delay_pkts` 模块参数（默认 8），对连接前期的 N 个数据包保持在内核协议栈转发，达到阈值后再建立 SFE 加速规则：
* **过滤短连接**：单次 DNS 查询、NTP 授时及瞬态探测连接因累计包数未达阈值，直接由内核网络栈处理并结束，避免频繁分配与销毁加速表项，降低哈希表抖动。
* **分流与代理兼容**：为应用层协议识别（如 SNI）及连接重定向（TPROXY / REDIRECT）预留决策窗口。被重定向的连接脱离转发链，直连连接在完成握手与识别后转入快路径接管。
* **Conntrack 计账联动**：
  * 延迟卸载依赖 `nf_conn_acct` 扩展计数器。当 `delay_pkts > 0` 时，模块自动开启 `net.netfilter.nf_conntrack_acct`，并在模块卸载时恢复原值；若设为 0 则不启用计账。
  * 可通过 UCI `firewall.@defaults[0].sfe_delay_pkts` 或 `/sys/module/shortcut_fe_cm/parameters/delay_pkts` 动态调整。

### 2.4 连接同步与 conntrack 续期
SFE 快速路径转发绕过 Netfilter，连接管理器通过周期性工作队列（每 1000 ms）向引擎发起批量统计同步请求（`SFE_TX_CONN_STATS_SYNC_MANY_MSG`）：
* 将引擎回传的时钟增量 `inc_ticks` 转换为 jiffies 刷新 `ct->timeout`，防止活跃加速流因 conntrack 超时被回收；
* 同步累计数据包与字节数至 `nf_conn_acct`，保持系统的流量统计准确；
* 采用分批让出调度机制（每批 36~64 条），避免大连接数同步时长时间占用 CPU。

### 2.5 设备状态与事件清理
连接管理器监听网络设备事件（`NETDEV_DOWN`、`NETDEV_UNREGISTER`、`NETDEV_CHANGEADDR`、`NETDEV_FEAT_CHANGE`）以及 IP 地址变更，当网卡下线、MAC 变动或配置调整时，主动销毁关联的 SFE 规则。

### 2.6 Conntrack 事件接入
* 打入 952 补丁（`CONFIG_NF_CONNTRACK_CHAIN_EVENTS`）的内核中，注册至通知链，与其他注册者互不干扰。
* 原生未打补丁内核中，连接管理器接管单一事件回调槽位并将事件向原持有者（如 ctnetlink）链式传递，卸载时安全归还。

### 2.7 数据面与语义边界
* **TC / eBPF Ingress 兼容**：
  若网卡挂载了 TC Ingress 程序（`tcx_ingress` / `miniq_ingress`），`sfe_recv` 主动返回 0 放行至内核执行 BPF 逻辑；未被 BPF 重定向的直连流量在此后仍会被捕获加速：无 953 补丁的构建优先由 netdev ingress 钩子（`NFPROTO_NETDEV`，TC 之后、IP 栈之前）接管，内核缺少 `CONFIG_NETFILTER_INGRESS` 时回退 Netfilter `PREROUTING`。
* **L2 目的 MAC 与 NAT 映射**：
  引擎仅重写双向目的 MAC 地址（出向 `conn_rule.return_mac`，入向 `conn_rule.flow_mac`），源 MAC 由出口网卡驱动补齐。DNAT 场景下精准映射到翻译后的内网目标 MAC，避免路由错误。
* **UDP 双向确认（`udp_require_reply`）**：
  默认要求 conntrack 标记包含 `IPS_SEEN_REPLY_BIT`，单向 UDP 报文不建加速表，防止单包探测占用表项；若有单向 UDP 业务需求（如 Syslog），可置 `udp_require_reply=0`。
* **连接容量扩展**：
  哈希表扩展至 16 位（65536 桶），单协议族上限 65536 条（IPv4/IPv6 合计 131072 条）。超出上限时平滑返回 `SFE_RET_MAX_CONN_COUNT_REACHED`，未加速流量继续走内核协议栈转发。
* **经典 `tc filter`（`police`/`skbedit`/`fw` 等）**：
  只要 filter 挂在某个 qdisc 上，内核就会清除该 qdisc 的 `TCQ_F_CAN_BYPASS`（`net/sched/cls_api.c`），SFE 随即不再直发该队列——**无需任何 SFE 侧配置**。

### 2.8 模块参数一览
| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `delay_pkts` | 8 | 每条流前 N 个报文留在内核协议栈转发，用于过滤短连接并预留分流窗口；>0 时自动启用 conntrack 计账。UCI：`firewall.@defaults[0].sfe_delay_pkts` |
| `fast_xmit` | 1 | 允许无流控设备绕过 Qdisc 直发驱动；0 = 统一使用 `dev_queue_xmit()`。UCI：`firewall.@defaults[0].sfe_fast_xmit` |
| `udp_require_reply` | 1 | UDP 会话是否必须见到回包才建立加速表；0 = 允许单向 UDP 报文加速 |
| `pppoe_top_xmit` | 1 | PPPoE 顶层设备（如 `pppoe-wan`）存在流控时，改由顶层设备发包以兼容队列调度；0 = 拒绝加速受影响的流 |
| `dscp_remark` | 0 | 是否由引擎在快路径将建流时的 DSCP 重写至双向报文；0 = 保留各报文原生 DSCP |
| `src_iface_check` | 0 | 是否校验报文入接口与建流接口一致；0 = 允许不一致报文退回协议栈处理 |
| `tcp_no_seq_check` | 0 | 是否跳过引擎对 TCP 序列号与窗口的校验；1 = 允许免校验加速 |
| `status`（只读） | — | 读取 `/sys/module/shortcut_fe_cm/parameters/status` 输出当前生效参数与计数统计 |

### 2.9 规则扩展能力说明

| 能力 | 状态 | 说明 |
| --- | --- | --- |
| **连接标记（connmark）同步** | 默认启用 | 建流时将 `ct->mark` 写入规则（`SFE_RULE_CREATE_MARK_VALID`），快路径将其写回 `skb->mark`，并在定期同步时持续同步标记变更，使基于 mark 的流控与策略路由持续生效。`ct->mark == 0` 时不置标志。 |
| **引擎丢流感知** | 默认启用 | 注册单条规则同步回调（`SFE_RX_CONN_STATS_SYNC_MSG`）：当引擎因校验异常、GSO 或表项淘汰移除某条加速流时，更新 `engine_flushed` 计数并通过限速日志记录五元组与原因。 |
| **DSCP 双向改写** | 需配置 `dscp_remark=1` | 建流时记录首包 DSCP 并交由引擎在快路径重写双向报文。 |
| **入接口严格校验** | 需配置 `src_iface_check=1` | 下发 `*_SRC_INTERFACE_CHECK_NO_FLUSH`：要求报文必须来自建流时的网络设备，否则回退系统协议栈。 |
| **跳过 TCP 序列号校验** | 需配置 `tcp_no_seq_check=1` | 下发 `SFE_RULE_CREATE_FLAG_NO_SEQ_CHECK`，用于非对称路由等特定场景。 |
| **运行状态导出** | 默认启用 | 通过 `status` 参数导出当前参数、加速/拒绝/丢弃/销毁计数以及连接上限，支持 `sfe_dump` 一键查询。 |

注：本移植聚焦于单播 IPv4/IPv6 路由与 NAT 转发，不包含高通私有硬件特性（PPE/SAWF）及组播转发。

---

## 3. PPPoE 加速

Linux PPP 虚拟网卡为单队列且持有队列自旋锁（`ppp_xmit_lock`），上下行经由内核驱动开销较高。SFE 通过旁路处理实现 PPPoE 会话线速转发。

### 数据面
* **上行（Encap）**：LAN 侧进入的 IP 报文由 SFE 压入 PPPoE 与 PPP 报头并填充 BRAS MAC，直接从物理网卡发送。
* **下行（Decap）**：收到 `ETH_P_PPP_SES`（0x8864）报文时校验 Session ID 与对端 MAC，剥除 PPPoE/PPP 头后直接发往 LAN。

### 钩子模式与转发路径
* **打入 953 补丁（`CONFIG_SHORTCUT_FE=y`）**：在 L2 `netif_receive` 入口钩子拦截，上下行均可由 SFE 完整卸载。
* **原生通用内核（无 953）**：优先在 netdev ingress 钩子接管物理口上的原始 `ETH_P_PPP_SES` 帧（早于 ppp 解封装），上下行都可加速；只有内核缺少 `CONFIG_NETFILTER_INGRESS` 时才退回 `PRE_ROUTING`，此时看到的是 `pppoe-wan` 上的裸 IP，仅上行可加速。

| 方向 | 无 953（netdev ingress / PRE_ROUTING） | 有 953 |
| --- | --- | --- |
| 上行 LAN→WAN | 直发物理网卡，绕开 PPP | 直发物理网卡，绕开 PPP |
| 下行 WAN→LAN | 有 netdev ingress 钩子时自己剥头进 LAN，否则走内核慢路径 | SFE 解封装直发 LAN |

* **物理出口直发模式**（无流控）：
  SFE 自行处理 PPPoE 封装与解封装，直接调用物理网卡驱动发送，避开 PPP 队列与锁竞争。
* **顶层设备加速模式**（`pppoe-wan` 配置流控时）：
  当顶层接口挂载 Qdisc 或 TC 程序时，SFE 切换为向顶层设备发包（受 `pppoe_top_xmit` 控制）。SFE 跳过路由与 Netfilter 慢路径，封包与流控排队交由 PPP 驱动处理，兼顾转发效率与队列调度。

### 控制面
通过 Linux 5.13+ 引入的 `dev_fill_forward_path()` 解析转发链路：
1. 入/出设备为 PPP 类型（`ARPHRD_PPP`）时，通过 `dev_fill_forward_path()` 回溯出 `DEV_PATH_PPPOE`（Session ID 与 BRAS MAC）及随后的物理网卡 `DEV_PATH_ETHERNET`；
2. 物理网卡作为底层出口接口，`pppoe-wan` 作为顶层设备并标记 `USE_FLOW/RETURN_BOTTOM_INTERFACE`；
3. 链路解析失败时回退至系统内核协议栈转发。

---

## 4. 运行时使用与排查

### 防火墙与 LuCI 集成
* **LuCI 界面**：“网络” -> “防火墙” -> “常规设置” 中，分流模式选择 `Shortcut-FE v2 flow offloading` 并保存应用。
* **按需加载与热重载**：模块由防火墙按需管理。通过 `ucitrack` 联动，在防火墙启用 `shortcut_fe` 时自动加载模块，禁用时自动卸载。

### 命令行排查
`@bash
# 手动控制服务
/etc/init.d/shortcut-fe start
/etc/init.d/shortcut-fe stop

# 查看运行状态与连接统计
/usr/bin/sfe_dump
/usr/bin/sfe_dump ipv4
/usr/bin/sfe_dump ipv6

# 查看模块加载
lsmod | grep shortcut
`@
