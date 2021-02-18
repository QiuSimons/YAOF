#
# Copyright (C) 2016-2017 GitHub 
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.

include $(TOPDIR)/rules.mk

PKG_NAME:=addition-trans-zh
PKG_VERSION:=1.1
PKG_RELEASE:=52
PKG_LICENSE:=GPLv3
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/addition-trans-zh
  SECTION:=luci
  CATEGORY:=LuCI
  TITLE:=LuCI support for Default Settings
  PKGARCH:=all
  DEPENDS:=+luci-base +kmod-fast-classifier +kmod-tcp-bbr +kmod-ipt-nat6 +kmod-tun +luci-lib-ipkg +luci-compat +openssl-util +iptables-mod-fullconenat +iptables-mod-nat-extra +ip6tables-mod-nat +@LUCI_LANG_zh_Hans
endef

define Package/addition-trans-zh/description
	Language Support Packages.
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/addition-trans-zh/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/zzz-default-settings $(1)/etc/uci-defaults/99-default-settings
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) ./files/getcpu $(1)/bin/getcpu
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	po2lmo ./i18n/default.zh_Hans.po $(1)/usr/lib/lua/luci/i18n/default.zh-cn.lmo
	po2lmo ./i18n/more.zh_Hans.po $(1)/usr/lib/lua/luci/i18n/more.zh-cn.lmo
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/tools
	$(INSTALL_DATA) ./status/status.lua $(1)/usr/lib/lua/luci/tools/status.lua
endef

$(eval $(call BuildPackage,addition-trans-zh))
