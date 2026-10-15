#
# Qualcomm Shortcut-FE v2 for OpenWrt
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=shortcut-fe
PKG_VERSION:=14.0.1.00011
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://git.codelinaro.org/clo/qsdk/oss/lklm/shortcut-fe.git
PKG_SOURCE_VERSION:=NHSS.QSDK.14.0.r1-00011-O
PKG_MIRROR_HASH:=skip

include $(INCLUDE_DIR)/package.mk

#
# CONFIG_NF_CONNTRACK_ACCT exists up to ~6.7; from 6.8 the accounting extension
# is unconditional and only controlled by net.netfilter.nf_conntrack_acct (set by
# /etc/init.d/shortcut-fe).  The entry is kept for older kernels, where the
# delay_pkts threshold needs the extension.
#

define KernelPackage/shortcut-fe
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Support
  TITLE:=Qualcomm Shortcut-FE v2 Engine
  DEPENDS:=@IPV6 +kmod-nf-conntrack
  FILES:=$(PKG_BUILD_DIR)/qca-nss-sfe.ko
  KCONFIG:= \
	   CONFIG_NF_CONNTRACK_ACCT=y \
	   CONFIG_NF_CONNTRACK_CHAIN_EVENTS=y \
	   CONFIG_NF_CONNTRACK_EVENTS=y \
	   CONFIG_NF_CONNTRACK_TIMEOUT=y \
	   CONFIG_SHORTCUT_FE=y \
	   CONFIG_XFRM=y
  PROVIDES:=kmod-shortcut-fe
endef

define KernelPackage/shortcut-fe/description
  Shortcut Forwarding Engine v2 - high performance in-kernel packet forwarding acceleration.
  Pure software data plane running on generic CPUs, zero hardware accelerator dependency.
endef

define KernelPackage/shortcut-fe/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/shortcut-fe $(1)/etc/init.d/shortcut-fe
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/sfe_dump $(1)/usr/bin/sfe_dump
	$(INSTALL_DIR) $(1)/usr/share/ucitrack
	$(INSTALL_DATA) ./files/usr/share/ucitrack/shortcut-fe.json $(1)/usr/share/ucitrack/shortcut-fe.json
endef

define KernelPackage/shortcut-fe-cm
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Support
  TITLE:=Qualcomm Shortcut-FE v2 Connection Manager
  DEPENDS:=+kmod-shortcut-fe
  FILES:=$(PKG_BUILD_DIR)/shortcut-fe-cm.ko
  KCONFIG:= \
	   CONFIG_NF_CONNTRACK_ACCT=y \
	   CONFIG_NF_CONNTRACK_CHAIN_EVENTS=y \
	   CONFIG_NF_CONNTRACK_EVENTS=y \
	   CONFIG_XFRM=y
  PROVIDES:=kmod-shortcut-fe-cm
endef

define KernelPackage/shortcut-fe-cm/description
  Lightweight Connection Manager for Shortcut-FE v2.
  Directly hooks into Netfilter conntrack and offloads flows into SFE v2,
  with zero dependency on Qualcomm ECM.
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(KERNEL_MAKE) \
		M="$(PKG_BUILD_DIR)" \
		SFE_SUPPORT_IPV6=1 \
		modules
endef

$(eval $(call KernelPackage,shortcut-fe))
$(eval $(call KernelPackage,shortcut-fe-cm))
