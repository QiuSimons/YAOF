#
# Copyright (C) 2017-2020
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=qBittorrent-Enhanced-Edition
PKG_VERSION:=4.3.3.10
PKG_RELEASE=1

STRIP:=true

ifeq ($(ARCH),i386)
	PKG_ARCH:=86
endif

ifeq ($(ARCH),x86_64)
	PKG_ARCH:=x86_64-linux-musl
endif

ifeq ($(ARCH),mipsel)
	PKG_ARCH:=mipsel-linux-musl
endif

ifeq ($(ARCH),mips)
	PKG_ARCH:=mipsel-linux-musl
endif

ifeq ($(ARCH),arm64)
	PKG_ARCH:=aarch64-linux-musl
endif

ifeq ($(ARCH),aarch64)
	PKG_ARCH:=aarch64-linux-musl
endif

ifeq ($(ARCH),arm)
ifeq ($(BOARD),bcm53xx)
	PKG_ARCH:=armv5
else ifeq ($(BOARD),kirkwood)
	PKG_ARCH:=armv5
else
	PKG_ARCH:=armv7
endif
endif

PKG_SOURCE:=qbittorrent-nox_$(PKG_ARCH)_static.zip
PKG_SOURCE_URL:=https://github.com/c0re100/qBittorrent-Enhanced-Edition/releases/download/release-$(PKG_VERSION)/
PKG_HASH:=skip

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=BitTorrent
	TITLE:=bittorrent client programmed in C++ / Qt
	URL:=https://www.qbittorrent.org/
endef

define Package/$(PKG_NAME)/description
  qBittorrent is a bittorrent client programmed in C++ / Qt that uses
  libtorrent (sometimes called libtorrent-rasterbar) by Arvid Norberg.
  It aims to be a good alternative to all other bittorrent clients out
  there. qBittorrent is fast, stable and provides unicode support as
  well as many features.
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(BUILD_DIR)/qbittorrent-nox $(1)/usr/bin
	$(INSTALL_DIR) $(1)/etc/qBittorrent
	$(INSTALL_DATA) ./files/ipfilter.dat $(1)/etc/qBittorrent/ipfilter.dat
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
