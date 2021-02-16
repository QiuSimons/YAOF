#
# Copyright (C) 2016-2017 GitHub
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.

include $(TOPDIR)/rules.mk

PKG_NAME:=libncursesw6
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_LICENSE:=GPLv3
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/libncursesw6
  SECTION:=luci
  CATEGORY:=LuCI
  TITLE:=libncursesw6
  PKGARCH:=all
  DEPENDS:=+luci-base
endef

define Package/libncursesw6/description
	libncursesw6.
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/libncursesw6/install
endef

$(eval $(call BuildPackage,libncursesw6))
