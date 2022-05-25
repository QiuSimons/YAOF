#!/bin/bash
clear

### 基础部分 ###
# 使用 O3 级别的优化
sed -i 's/Os/O3 -fno-tree-loop-vectorize -Wl,--gc-sections/g' include/target.mk
wget -qO - https://github.com/openwrt/openwrt/commit/8249a8c.patch | patch -p1
wget -qO - https://github.com/openwrt/openwrt/commit/66fa343.patch | patch -p1
# 更新 Feeds
./scripts/feeds update -a
./scripts/feeds install -a
# 默认开启 Irqbalance
sed -i "s/enabled '0'/enabled '1'/g" feeds/packages/utils/irqbalance/files/irqbalance.config
# 移除 SNAPSHOT 标签
sed -i 's,-SNAPSHOT,,g' include/version.mk
sed -i 's,-SNAPSHOT,,g' package/base-files/image-config.in
# 维多利亚的秘密
rm -rf ./scripts/download.pl
rm -rf ./include/download.mk
wget -P scripts/ https://github.com/immortalwrt/immortalwrt/raw/master/scripts/download.pl
wget -P include/ https://github.com/immortalwrt/immortalwrt/raw/master/include/download.mk
sed -i '/unshift/d' scripts/download.pl
sed -i '/mirror02/d' scripts/download.pl
echo "net.netfilter.nf_conntrack_helper = 1" >>./package/kernel/linux/files/sysctl-nf-conntrack.conf
# IPSET & Firewall
#rm -rf ./package/network/utils/ipset
#svn export https://github.com/openwrt/openwrt/branches/openwrt-21.02/package/network/utils/ipset package/network/utils/ipset
#rm -rf ./package/network/config/firewall
#svn export https://github.com/openwrt/openwrt/branches/openwrt-21.02/package/network/config/firewall package/network/config/firewall
#wget -qO - https://github.com/openwrt/openwrt/commit/a94e954.patch | patch -p1

### 必要的 Patches ###
# offload bug fix
wget -qO - https://github.com/openwrt/openwrt/pull/4849.patch | patch -p1
# TCP performance optimizations backport from linux/net-next
#cp -rf ../PATCH/backport/TCP/* ./target/linux/generic/backport-5.10/
# UDP performance optimizations backport from linux/net-next
#cp -rf ../PATCH/backport/UDP/* ./target/linux/generic/backport-5.10/
# introduce "le9" Linux kernel patches
cp -f ../PATCH/backport/995-le9i.patch ./target/linux/generic/hack-5.10/995-le9i.patch
cp -f ../PATCH/backport/290-remove-kconfig-CONFIG_I8K.patch ./target/linux/generic/hack-5.10/290-remove-kconfig-CONFIG_I8K.patch
# ZSTD
cp -rf ../PATCH/backport/ZSTD/* ./target/linux/generic/hack-5.10/
# Futex
cp -rf ../PATCH/futex/* ./target/linux/generic/hack-5.10/
# Patch arm64 型号名称
wget -P target/linux/generic/hack-5.10/ https://github.com/immortalwrt/immortalwrt/raw/master/target/linux/generic/hack-5.10/312-arm64-cpuinfo-Add-model-name-in-proc-cpuinfo-for-64bit-ta.patch
#FW4
#rm -rf ./package/network/config/firewall4
#svn export https://github.com/openwrt/openwrt/trunk/package/network/config/firewall4 package/network/config/firewall4
#rm -rf ./package/utils/ucode
#svn export https://github.com/openwrt/openwrt/trunk/package/utils/ucode package/utils/ucode
# Patch dnsmasq
#rm -rf ./package/network/services/dnsmasq
#svn export https://github.com/aparcar/openwrt/branches/dnsmasq-2.87test5/package/network/services/dnsmasq package/network/services/dnsmasq
#patch -p1 <../PATCH/dnsmasq/dnsmasq-add-filter-aaaa-option.patch
#patch -p1 <../PATCH/dnsmasq/luci-add-filter-aaaa-option.patch
#cp -f ../PATCH/dnsmasq/900-add-filter-aaaa-option.patch ./package/network/services/dnsmasq/patches/900-add-filter-aaaa-option.patch
# BBRv2
cp -rf ../PATCH/BBRv2/kernel/* ./target/linux/generic/hack-5.10/
cp -rf ../PATCH/BBRv2/openwrt/package ./
wget -qO - https://github.com/openwrt/openwrt/commit/7db9763.patch | patch -p1

# PRJC
#cp -f ../PATCH/PRJC/960-prjc_v5.10-lts-r3.patch ./target/linux/generic/hack-5.10/960-prjc_v5.10-lts-r3.patch
#echo '
#CONFIG_SCHED_ALT=y
#CONFIG_SCHED_BMQ=y
#' >>./target/linux/generic/config-5.10
# Haproxy
rm -rf ./feeds/packages/net/haproxy
svn export https://github.com/openwrt/packages/trunk/net/haproxy feeds/packages/net/haproxy
pushd feeds/packages
wget -qO - https://github.com/openwrt/packages/commit/a09cbcd.patch | patch -p1
popd
# OPENSSL
wget -P package/libs/openssl/patches/ https://github.com/openssl/openssl/pull/11895.patch
wget -P package/libs/openssl/patches/ https://github.com/openssl/openssl/pull/14578.patch
wget -P package/libs/openssl/patches/ https://github.com/openssl/openssl/pull/16575.patch

### Fullcone-NAT 部分 ###
# Patch Kernel 以解决 FullCone 冲突
pushd target/linux/generic/hack-5.10
wget https://github.com/coolsnowwolf/lede/raw/master/target/linux/generic/hack-5.10/952-net-conntrack-events-support-multiple-registrant.patch
popd
# Patch FireWall 以增添 FullCone 功能
# FW4
mkdir package/network/config/firewall4/patches
wget -P package/network/config/firewall4/patches/ https://github.com/wongsyrone/lede-1/raw/master/package/network/config/firewall4/patches/999-01-firewall4-add-fullcone-support.patch
sed -i 's/-1,3 +1,5/-2,3 +2,5/g' package/network/config/firewall4/patches/999-01-firewall4-add-fullcone-support.patch
mkdir package/libs/libnftnl/patches
wget -P package/libs/libnftnl/patches/ https://github.com/wongsyrone/lede-1/raw/master/package/libs/libnftnl/patches/999-01-libnftnl-add-fullcone-expression-support.patch
sed -i '/PKG_LICENSE_FILES/a PKG_FIXUP:=autoreconf' package/libs/libnftnl/Makefile
mkdir package/network/utils/nftables/patches
wget -P package/network/utils/nftables/patches/ https://github.com/wongsyrone/lede-1/raw/master/package/network/utils/nftables/patches/999-01-nftables-add-fullcone-expression-support.patch
# FW3
mkdir package/network/config/firewall/patches
wget -P package/network/config/firewall/patches/ https://github.com/immortalwrt/immortalwrt/raw/openwrt-21.02/package/network/config/firewall/patches/fullconenat.patch
wget -qO- https://github.com/msylgj/R2S-R4S-OpenWrt/raw/master/PATCHES/001-fix-firewall3-flock.patch | patch -p1
# Patch LuCI 以增添 FullCone 开关
patch -p1 <../PATCH/firewall/luci-app-firewall_add_fullcone.patch
# FullCone PKG
git clone --depth 1 https://github.com/fullcone-nat-nftables/nft-fullcone package/new/nft-fullcone
svn export https://github.com/coolsnowwolf/lede/trunk/package/lean/openwrt-fullconenat package/lean/openwrt-fullconenat
pushd package/lean/openwrt-fullconenat
patch -p2 <../../../../PATCH/firewall/fullcone6.patch
popd

### 获取额外的基础软件包 ###
# 更换为 ImmortalWrt Uboot 以及 Target
rm -rf ./target/linux/rockchip
#svn export https://github.com/immortalwrt/immortalwrt/branches/master/target/linux/rockchip target/linux/rockchip
svn export https://github.com/coolsnowwolf/lede/trunk/target/linux/rockchip target/linux/rockchip
wget -qO - https://github.com/immortalwrt/immortalwrt/commit/af93561.patch | patch -p1
rm -rf ./target/linux/rockchip/Makefile
wget -P target/linux/rockchip/ https://github.com/openwrt/openwrt/raw/openwrt-22.03/target/linux/rockchip/Makefile
rm -rf ./target/linux/rockchip/patches-5.10/002-net-usb-r8152-add-LED-configuration-from-OF.patch
rm -rf ./target/linux/rockchip/patches-5.10/003-dt-bindings-net-add-RTL8152-binding-documentation.patch
rm -rf ./package/boot/uboot-rockchip
#svn export https://github.com/immortalwrt/immortalwrt/branches/master/package/boot/uboot-rockchip package/boot/uboot-rockchip
svn export https://github.com/coolsnowwolf/lede/trunk/package/boot/uboot-rockchip package/boot/uboot-rockchip
svn export https://github.com/immortalwrt/immortalwrt/branches/master/package/boot/arm-trusted-firmware-rockchip-vendor package/boot/arm-trusted-firmware-rockchip-vendor
rm -rf ./package/kernel/linux/modules/video.mk
wget -P package/kernel/linux/modules/ https://github.com/immortalwrt/immortalwrt/raw/master/package/kernel/linux/modules/video.mk
# LRNG
cp -rf ../PATCH/LRNG/* ./target/linux/generic/hack-5.10/
# ImmortalWrt Uboot TMP Fix
#wget -qO- https://github.com/immortalwrt/immortalwrt/commit/433c93e.patch | patch -REp1
wget -qO- https://github.com/coolsnowwolf/lede/commit/0104258.patch | patch -REtp1
# R4S超频到 2.2/1.8 GHz
#rm -rf ./target/linux/rockchip/patches-5.4/992-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch
#cp -f ../PATCH/target_r4s/991-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch ./target/linux/rockchip/patches-5.4/991-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch
#cp -f ../PATCH/target_r4s/213-RK3399-set-critical-CPU-temperature-for-thermal-throttling.patch ./target/linux/rockchip/patches-5.4/213-RK3399-set-critical-CPU-temperature-for-thermal-throttling.patch
# Disable Mitigations
sed -i 's,rootwait,rootwait mitigations=off,g' target/linux/rockchip/image/mmc.bootscript
sed -i 's,rootwait,rootwait mitigations=off,g' target/linux/rockchip/image/nanopi-r2s.bootscript
sed -i 's,rootwait,rootwait mitigations=off,g' target/linux/rockchip/image/nanopi-r4s.bootscript
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-efi.cfg
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-iso.cfg
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-pc.cfg
# AutoCore
svn export https://github.com/immortalwrt/immortalwrt/branches/master/package/emortal/autocore package/lean/autocore
sed -i 's/"getTempInfo" /"getTempInfo", "getCPUBench", "getCPUUsage" /g' package/lean/autocore/files/generic/luci-mod-status-autocore.json
rm -rf ./feeds/packages/utils/coremark
svn export https://github.com/immortalwrt/packages/trunk/utils/coremark feeds/packages/utils/coremark
# 更换 Nodejs 版本
rm -rf ./feeds/packages/lang/node
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node feeds/packages/lang/node
#sed -i '\/bin\/node/a\\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(1)/usr/bin/node' feeds/packages/lang/node/Makefile
rm -rf ./feeds/packages/lang/node-arduino-firmata
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-arduino-firmata feeds/packages/lang/node-arduino-firmata
rm -rf ./feeds/packages/lang/node-cylon
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-cylon feeds/packages/lang/node-cylon
rm -rf ./feeds/packages/lang/node-hid
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-hid feeds/packages/lang/node-hid
rm -rf ./feeds/packages/lang/node-homebridge
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-homebridge feeds/packages/lang/node-homebridge
rm -rf ./feeds/packages/lang/node-serialport
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-serialport feeds/packages/lang/node-serialport
rm -rf ./feeds/packages/lang/node-serialport-bindings
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-serialport-bindings feeds/packages/lang/node-serialport-bindings
rm -rf ./feeds/packages/lang/node-yarn
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-yarn feeds/packages/lang/node-yarn
ln -sf ../../../feeds/packages/lang/node-yarn ./package/feeds/packages/node-yarn
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-serialport-bindings-cpp feeds/packages/lang/node-serialport-bindings-cpp
ln -sf ../../../feeds/packages/lang/node-serialport-bindings-cpp ./package/feeds/packages/node-serialport-bindings-cpp
# R8168驱动
git clone -b master --depth 1 https://github.com/BROBIRD/openwrt-r8168.git package/new/r8168
patch -p1 <../PATCH/r8168/r8168-fix_LAN_led-for_r4s-from_TL.patch
# R8152驱动
svn export https://github.com/immortalwrt/immortalwrt/branches/master/package/kernel/r8152 package/new/r8152
sed -i 's,kmod-usb-net-rtl8152,kmod-usb-net-rtl8152-vendor,g' target/linux/rockchip/image/armv8.mk
# UPX 可执行软件压缩
sed -i '/patchelf pkgconf/i\tools-y += ucl upx' ./tools/Makefile
sed -i '\/autoconf\/compile :=/i\$(curdir)/upx/compile := $(curdir)/ucl/compile' ./tools/Makefile
svn export https://github.com/coolsnowwolf/lede/trunk/tools/ucl tools/ucl
svn export https://github.com/coolsnowwolf/lede/trunk/tools/upx tools/upx

### 获取额外的 LuCI 应用、主题和依赖 ###
# 更换 golang 版本
rm -rf ./feeds/packages/lang/golang
svn export https://github.com/openwrt/packages/trunk/lang/golang feeds/packages/lang/golang
# 访问控制
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-accesscontrol package/lean/luci-app-accesscontrol
svn export https://github.com/QiuSimons/OpenWrt-Add/trunk/luci-app-control-weburl package/new/luci-app-control-weburl
# 广告过滤 Adbyby
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-adbyby-plus package/lean/luci-app-adbyby-plus
svn export https://github.com/coolsnowwolf/lede/trunk/package/lean/adbyby package/lean/adbyby
# 广告过滤 AdGuard
#svn export https://github.com/Lienol/openwrt/trunk/package/diy/luci-app-adguardhome package/new/luci-app-adguardhome
git clone https://github.com/rufengsuixing/luci-app-adguardhome.git package/new/luci-app-adguardhome
rm -rf ./feeds/packages/net/adguardhome
svn export https://github.com/openwrt/packages/trunk/net/adguardhome feeds/packages/net/adguardhome
#sed -i '/\t)/a\\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(GO_PKG_BUILD_BIN_DIR)/AdGuardHome' ./feeds/packages/net/adguardhome/Makefile
sed -i '/init/d' feeds/packages/net/adguardhome/Makefile
# Argon 主题
git clone -b master --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/new/luci-theme-argon
#git clone -b luci-21 --depth 1 https://github.com/jjm2473/luci-theme-argon.git package/new/luci-theme-argon
#wget -P package/new/luci-theme-argon/htdocs/luci-static/argon/background/ https://github.com/QiuSimons/OpenWrt-Add/raw/master/5808303.jpg
rm -rf ./package/new/luci-theme-argon/htdocs/luci-static/argon/background/README.md
#pushd package/new/luci-theme-argon
#git checkout 3b15d06
#popd
git clone -b master --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/new/luci-app-argon-config
# MAC 地址与 IP 绑定
svn export https://github.com/immortalwrt/luci/trunk/applications/luci-app-arpbind feeds/luci/applications/luci-app-arpbind
ln -sf ../../../feeds/luci/applications/luci-app-arpbind ./package/feeds/luci/luci-app-arpbind
# 定时重启
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-autoreboot package/lean/luci-app-autoreboot
# Boost 通用即插即用
svn export https://github.com/QiuSimons/slim-wrt/branches/main/slimapps/application/luci-app-boostupnp package/new/luci-app-boostupnp
rm -rf ./feeds/packages/net/miniupnpd
git clone -b main --depth 1 https://github.com/msylgj/miniupnpd.git feeds/packages/net/miniupnpd
pushd feeds/packages
wget -qO - https://github.com/openwrt/packages/commit/785bbcb.patch | patch -p1
popd
#svn export https://github.com/coolsnowwolf/packages/trunk/net/miniupnpd feeds/packages/net/miniupnpd
# ChinaDNS
git clone -b luci --depth 1 https://github.com/QiuSimons/openwrt-chinadns-ng.git package/new/luci-app-chinadns-ng
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/chinadns-ng package/new/chinadns-ng
# CPU 控制相关
svn export https://github.com/immortalwrt/luci/trunk/applications/luci-app-cpufreq feeds/luci/applications/luci-app-cpufreq
ln -sf ../../../feeds/luci/applications/luci-app-cpufreq ./package/feeds/luci/luci-app-cpufreq
sed -i 's,1608,1800,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/10-cpufreq
sed -i 's,2016,2208,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/10-cpufreq
sed -i 's,1512,1608,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/10-cpufreq
svn export https://github.com/QiuSimons/OpenWrt-Add/trunk/luci-app-cpulimit package/lean/luci-app-cpulimit
svn export https://github.com/immortalwrt/packages/trunk/utils/cpulimit feeds/packages/utils/cpulimit
ln -sf ../../../feeds/packages/utils/cpulimit ./package/feeds/packages/cpulimit
# 动态DNS
sed -i '/boot()/,+2d' feeds/packages/net/ddns-scripts/files/etc/init.d/ddns
svn export https://github.com/linkease/istore-packages/trunk/ddns-scripts_dnspod package/lean/ddns-scripts_dnspod
svn export https://github.com/linkease/istore-packages/trunk/ddns-scripts_aliyun package/lean/ddns-scripts_aliyun
svn export https://github.com/QiuSimons/OpenWrt_luci-app/trunk/luci-app-tencentddns package/lean/luci-app-tencentddns
svn export https://github.com/kenzok8/openwrt-packages/trunk/luci-app-aliddns feeds/luci/applications/luci-app-aliddns
ln -sf ../../../feeds/luci/applications/luci-app-aliddns ./package/feeds/luci/luci-app-aliddns
# Docker 容器
rm -rf ./feeds/luci/applications/luci-app-dockerman
svn export https://github.com/lisaac/luci-app-dockerman/trunk/applications/luci-app-dockerman feeds/luci/applications/luci-app-dockerman
sed -i '/auto_start/d' feeds/luci/applications/luci-app-dockerman/root/etc/uci-defaults/luci-app-dockerman
pushd feeds/packages
wget -qO- https://github.com/openwrt/packages/commit/ed7396a.patch | patch -p1
popd
rm -rf ./feeds/luci/collections/luci-lib-docker
svn export https://github.com/lisaac/luci-lib-docker/trunk/collections/luci-lib-docker feeds/luci/collections/luci-lib-docker
#sed -i 's/+docker/+docker \\\n\t+dockerd/g' ./feeds/luci/applications/luci-app-dockerman/Makefile
sed -i '/sysctl.d/d' feeds/packages/utils/dockerd/Makefile
sed -i 's,# CONFIG_BLK_CGROUP_IOCOST is not set,CONFIG_BLK_CGROUP_IOCOST=y,g' target/linux/generic/config-5.10
# DiskMan
mkdir -p package/new/luci-app-diskman && \
wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/applications/luci-app-diskman/Makefile -O package/new/luci-app-diskman/Makefile
mkdir -p package/new/parted && \
wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/Parted.Makefile -O package/new/parted/Makefile
# Dnsfilter
git clone --depth 1 https://github.com/kiddin9/luci-app-dnsfilter.git package/new/luci-app-dnsfilter
# Dnsproxy
svn export https://github.com/immortalwrt/packages/trunk/net/dnsproxy feeds/packages/net/dnsproxy
ln -sf ../../../feeds/packages/net/dnsproxy ./package/feeds/packages/dnsproxy
sed -i '/CURDIR/d' feeds/packages/net/dnsproxy/Makefile
svn export https://github.com/QiuSimons/OpenWrt-Add/trunk/luci-app-dnsproxy package/new/luci-app-dnsproxy
# Edge 主题
git clone -b master --depth 1 https://github.com/kiddin9/luci-theme-edge.git package/new/luci-theme-edge
# FRP 内网穿透
rm -rf ./feeds/luci/applications/luci-app-frps
rm -rf ./feeds/luci/applications/luci-app-frpc
rm -rf ./feeds/packages/net/frp
rm -f ./package/feeds/packages/frp
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-frps package/lean/luci-app-frps
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-frpc package/lean/luci-app-frpc
svn export https://github.com/coolsnowwolf/packages/trunk/net/frp package/lean/frp
# IPSec
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-ipsec-server package/lean/luci-app-ipsec-server
# IPv6 兼容助手
svn export https://github.com/coolsnowwolf/lede/trunk/package/lean/ipv6-helper package/lean/ipv6-helper
# 京东签到 By Jerrykuku
git clone --depth 1 https://github.com/jerrykuku/node-request.git package/new/node-request
git clone --depth 1 https://github.com/jerrykuku/luci-app-jd-dailybonus.git package/new/luci-app-jd-dailybonus
# MentoHUST
git clone --depth 1 https://github.com/BoringCat/luci-app-mentohust package/new/luci-app-mentohust
git clone --depth 1 https://github.com/KyleRicardo/MentoHUST-OpenWrt-ipk package/new/MentoHUST
# Mosdns
#svn export https://github.com/immortalwrt/packages/trunk/net/mosdns feeds/packages/net/mosdns
#ln -sf ../../../feeds/packages/net/mosdns ./package/feeds/packages/mosdns
#sed -i '/config.yaml/d' feeds/packages/net/mosdns/Makefile
#sed -i '/mosdns-init-openwrt/d' feeds/packages/net/mosdns/Makefile
svn export https://github.com/QiuSimons/openwrt-mos/trunk/mosdns package/new/mosdns
svn export https://github.com/QiuSimons/openwrt-mos/trunk/luci-app-mosdns package/new/luci-app-mosdns
svn export https://github.com/QiuSimons/openwrt-mos/trunk/v2ray-geodata package/new/v2ray-geodata
# 流量监管
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-netdata package/lean/luci-app-netdata
# 上网 APP 过滤
git clone -b master --depth 1 https://github.com/destan19/OpenAppFilter.git package/new/OpenAppFilter
pushd package/new/OpenAppFilter
wget -qO - https://github.com/QiuSimons/OpenAppFilter-destan19/commit/9088cc2.patch | patch -p1
wget https://destan19.github.io/assets/oaf/open_feature/feature-06-18.cfg -O ./open-app-filter/files/feature.cfg
popd
# OLED 驱动程序
git clone -b master --depth 1 https://github.com/NateLol/luci-app-oled.git package/new/luci-app-oled
# OpenClash
#wget -qO - https://github.com/openwrt/openwrt/commit/efc8aff.patch | patch -p1
git clone --single-branch --depth 1 -b dev https://github.com/vernesong/OpenClash.git package/new/luci-app-openclash
# 花生壳内网穿透
svn export https://github.com/teasiu/dragino2/trunk/devices/common/diy/package/teasiu/luci-app-phtunnel package/new/luci-app-phtunnel
svn export https://github.com/teasiu/dragino2/trunk/devices/common/diy/package/teasiu/phtunnel package/new/phtunnel
svn export https://github.com/QiuSimons/dragino2-teasiu/trunk/package/teasiu/luci-app-oray package/new/luci-app-oray
# Passwall
#svn export https://github.com/immortalwrt/luci/trunk/applications/luci-app-passwall package/new/luci-app-passwall
svn export https://github.com/xiaorouji/openwrt-passwall/branches/luci/luci-app-passwall package/new/luci-app-passwall
pushd package/new/luci-app-passwall
sed -i 's,iptables-legacy,iptables-nft,g' Makefile
popd
wget -P package/new/luci-app-passwall/ https://github.com/QiuSimons/OpenWrt-Add/raw/master/move_2_services.sh
chmod -R 755 ./package/new/luci-app-passwall/move_2_services.sh
pushd package/new/luci-app-passwall
bash move_2_services.sh
popd
rm -rf ./feeds/packages/net/https-dns-proxy
svn export https://github.com/Lienol/openwrt-packages/trunk/net/https-dns-proxy feeds/packages/net/https-dns-proxy
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/tcping package/new/tcping
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/trojan-go package/new/trojan-go
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/brook package/new/brook
svn export https://github.com/QiuSimons/OpenWrt-Add/trunk/trojan-plus package/new/trojan-plus
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/ssocks package/new/ssocks
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/hysteria package/new/hysteria
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/dns2tcp package/new/dns2tcp
# Passwall 白名单
echo '
checkip.synology.com
checkipv6.synology.com
checkport.synology.com
ddns.synology.com
account.synology.com
whatismyip.akamai.com
checkip.dyndns.org
teamviewer.com
bing.com
api.ipify.org
epicgames.com
emby.kyarucloud.moe
' >>./package/new/luci-app-passwall/root/usr/share/passwall/rules/direct_host
# Passwall2
svn export https://github.com/xiaorouji/openwrt-passwall2/trunk/luci-app-passwall2 package/new/luci-app-passwall2
wget -P package/new/luci-app-passwall2/ https://github.com/QiuSimons/OpenWrt-Add/raw/master/move_2_services.sh
chmod -R 755 ./package/new/luci-app-passwall2/move_2_services.sh
pushd package/new/luci-app-passwall2
bash move_2_services.sh
popd
pushd package/new/luci-app-passwall2
sed -i 's,iptables-legacy,iptables-nft,g' Makefile
popd
# qBittorrent 下载
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-qbittorrent package/lean/luci-app-qbittorrent
svn export https://github.com/coolsnowwolf/packages/trunk/net/qBittorrent-static package/lean/qBittorrent-static
svn export https://github.com/coolsnowwolf/packages/trunk/net/qBittorrent package/lean/qBittorrent
svn export https://github.com/coolsnowwolf/packages/trunk/libs/qtbase package/lean/qtbase
svn export https://github.com/coolsnowwolf/packages/trunk/libs/qttools package/lean/qttools
svn export https://github.com/coolsnowwolf/packages/trunk/libs/rblibtorrent package/lean/rblibtorrent
# 清理内存
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-ramfree package/lean/luci-app-ramfree
# ServerChan 微信推送
git clone -b master --depth 1 https://github.com/tty228/luci-app-serverchan.git package/new/luci-app-serverchan
# SmartDNS
rm -rf ./feeds/packages/net/smartdns
svn export https://github.com/Lienol/openwrt-packages/trunk/net/smartdns feeds/packages/net/smartdns
rm -rf ./feeds/luci/applications/luci-app-smartdns
svn export https://github.com/immortalwrt/luci/branches/openwrt-18.06/applications/luci-app-smartdns feeds/luci/applications/luci-app-smartdns
# ShadowsocksR Plus+ 依赖
rm -rf ./feeds/packages/net/kcptun
rm -rf ./feeds/packages/net/shadowsocks-libev
rm -rf ./feeds/packages/net/xray-core
svn export https://github.com/coolsnowwolf/packages/trunk/net/shadowsocks-libev package/lean/shadowsocks-libev
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/shadowsocksr-libev package/lean/shadowsocksr-libev
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/pdnsd-alt package/lean/pdnsd
svn export https://github.com/coolsnowwolf/lede/trunk/package/lean/srelay package/lean/srelay
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/microsocks package/lean/microsocks
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/dns2socks package/lean/dns2socks
svn export https://github.com/coolsnowwolf/packages/trunk/net/redsocks2 package/lean/redsocks2
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/ipt2socks package/lean/ipt2socks
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/trojan package/lean/trojan
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/tcping package/lean/tcping
svn export https://github.com/fw876/helloworld/trunk/simple-obfs package/lean/simple-obfs
svn export https://github.com/fw876/helloworld/trunk/naiveproxy package/lean/naiveproxy
svn export https://github.com/fw876/helloworld/trunk/v2ray-core package/lean/v2ray-core
#svn export https://github.com/1715173329/helloworld/branches/v2v5/sagernet-core package/lean/sagernet-core
svn export https://github.com/zxlhhyccc/bf-package-master/trunk/ctcgfw/sagernet-core package/lean/sagernet-core
svn export https://github.com/fw876/helloworld/trunk/xray-core package/lean/xray-core
svn export https://github.com/fw876/helloworld/trunk/v2ray-plugin package/lean/v2ray-plugin
svn export https://github.com/fw876/helloworld/trunk/xray-plugin package/lean/xray-plugin
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/shadowsocks-rust feeds/packages/net/shadowsocks-rust
#svn export https://github.com/immortalwrt/packages/trunk/net/shadowsocks-rust feeds/packages/net/shadowsocks-rust
#sed -i '/Build\/Compile/a\\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $$(PKG_BUILD_DIR)/$(component)' feeds/packages/net/shadowsocks-rust/Makefile
ln -sf ../../../feeds/packages/net/shadowsocks-rust ./package/feeds/packages/shadowsocks-rust
svn export https://github.com/immortalwrt/packages/trunk/net/kcptun feeds/packages/net/kcptun
ln -sf ../../../feeds/packages/net/kcptun ./package/feeds/packages/kcptun
# ShadowsocksR Plus+
#svn export https://github.com/1715173329/helloworld/branches/v2v5/luci-app-ssr-plus package/lean/luci-app-ssr-plus
svn export https://github.com/fw876/helloworld/trunk/luci-app-ssr-plus package/lean/luci-app-ssr-plus
rm -rf ./package/lean/luci-app-ssr-plus/po/zh_Hans
pushd package/lean
#wget -qO - https://github.com/fw876/helloworld/commit/2875c57.patch | patch -p1
wget -qO - https://github.com/fw876/helloworld/commit/5bbf6e7.patch | patch -p1
popd
pushd package/lean/luci-app-ssr-plus
sed -i '/Clang.CN.CIDR/a\o:value("https://gh.404delivr.workers.dev/https://github.com/QiuSimons/Chnroute/raw/master/dist/chnroute/chnroute.txt", translate("QiuSimons/Chnroute"))' luasrc/model/cbi/shadowsocksr/advanced.lua
popd
# v2raya
git clone --depth 1 https://github.com/zxlhhyccc/luci-app-v2raya.git package/new/luci-app-v2raya
rm -rf ./feeds/packages/net/v2raya
svn export https://github.com/openwrt/packages/trunk/net/v2raya feeds/packages/net/v2raya
ln -sf ../../../feeds/packages/net/v2raya ./package/feeds/packages/v2raya
# socat
svn export https://github.com/Lienol/openwrt-package/trunk/luci-app-socat package/new/luci-app-socat
# 订阅转换
svn export https://github.com/immortalwrt/packages/trunk/net/subconverter feeds/packages/net/subconverter
#wget https://github.com/immortalwrt/packages/raw/b7b4499/net/subconverter/Makefile -O feeds/packages/net/subconverter/Makefile
#mkdir -p ./feeds/packages/net/subconverter/patches
#wget https://github.com/immortalwrt/packages/raw/b7b4499/net/subconverter/patches/100-stdcxxfs.patch -O feeds/packages/net/subconverter/patches/100-stdcxxfs.patch
#sed -i '\/bin\/subconverter/a\\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(1)/usr/bin/subconverter' feeds/packages/net/subconverter/Makefile
ln -sf ../../../feeds/packages/net/subconverter ./package/feeds/packages/subconverter
svn export https://github.com/immortalwrt/packages/trunk/libs/jpcre2 feeds/packages/libs/jpcre2
ln -sf ../../../feeds/packages/libs/jpcre2 ./package/feeds/packages/jpcre2
svn export https://github.com/immortalwrt/packages/trunk/libs/rapidjson feeds/packages/libs/rapidjson
ln -sf ../../../feeds/packages/libs/rapidjson ./package/feeds/packages/rapidjson
svn export https://github.com/immortalwrt/packages/trunk/libs/libcron feeds/packages/libs/libcron
#wget https://github.com/immortalwrt/packages/raw/b7b4499/libs/libcron/Makefile -O feeds/packages/libs/libcron/Makefile
ln -sf ../../../feeds/packages/libs/libcron ./package/feeds/packages/libcron
svn export https://github.com/immortalwrt/packages/trunk/libs/quickjspp feeds/packages/libs/quickjspp
#wget https://github.com/immortalwrt/packages/raw/b7b4499/libs/quickjspp/Makefile -O feeds/packages/libs/quickjspp/Makefile
ln -sf ../../../feeds/packages/libs/quickjspp ./package/feeds/packages/quickjspp
svn export https://github.com/immortalwrt/packages/trunk/libs/toml11 feeds/packages/libs/toml11
ln -sf ../../../feeds/packages/libs/toml11 ./package/feeds/packages/toml11
# 网易云音乐解锁
git clone --depth 1 https://github.com/immortalwrt/luci-app-unblockneteasemusic.git package/new/UnblockNeteaseMusic
# ucode
svn export https://github.com/openwrt/openwrt/trunk/package/utils/ucode package/utils/ucode
# USB 打印机
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-usb-printer package/lean/luci-app-usb-printer
# UU加速器
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-uugamebooster package/lean/luci-app-uugamebooster
svn export https://github.com/coolsnowwolf/packages/trunk/net/uugamebooster package/lean/uugamebooster
# KMS 激活助手
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-vlmcsd package/lean/luci-app-vlmcsd
svn export https://github.com/coolsnowwolf/packages/trunk/net/vlmcsd package/lean/vlmcsd
# VSSR
git clone -b master --depth 1 https://github.com/jerrykuku/luci-app-vssr.git package/lean/luci-app-vssr
git clone -b master --depth 1 https://github.com/jerrykuku/lua-maxminddb.git package/lean/lua-maxminddb
pushd package/lean/luci-app-vssr
#sed -i 's,+shadowsocks-libev-ss-local ,,g' Makefile
popd
#sed -i '/result.encrypt_method/a\result.fast_open = "1"' package/lean/luci-app-vssr/root/usr/share/vssr/subscribe.lua
#sed -i 's,ispip.clang.cn/all_cn.txt,raw.sevencdn.com/QiuSimons/Chnroute/master/dist/chnroute/chnroute.txt,g' package/lean/luci-app-vssr/luasrc/controller/vssr.lua
#sed -i 's,ispip.clang.cn/all_cn.txt,raw.sevencdn.com/QiuSimons/Chnroute/master/dist/chnroute/chnroute.txt,g' package/lean/luci-app-vssr/root/usr/share/vssr/update.lua
# 网络唤醒
svn export https://github.com/zxlhhyccc/bf-package-master/trunk/zxlhhyccc/luci-app-services-wolplus package/new/luci-app-services-wolplus
# 流量监视
git clone -b master --depth 1 https://github.com/brvphoenix/wrtbwmon.git package/new/wrtbwmon
git clone -b master --depth 1 https://github.com/brvphoenix/luci-app-wrtbwmon.git package/new/luci-app-wrtbwmon
# 迅雷快鸟宽带加速
git clone --depth 1 https://github.com/kiddin9/luci-app-xlnetacc.git package/lean/luci-app-xlnetacc
# Zerotier
svn export https://github.com/wongsyrone/lede-1/trunk/package/external/luci-app-zerotier feeds/luci/applications/luci-app-zerotier
#svn export https://github.com/immortalwrt/luci/trunk/applications/luci-app-zerotier feeds/luci/applications/luci-app-zerotier
wget -P feeds/luci/applications/luci-app-zerotier/ https://github.com/QiuSimons/OpenWrt-Add/raw/master/move_2_services.sh
chmod -R 755 ./feeds/luci/applications/luci-app-zerotier/move_2_services.sh
pushd feeds/luci/applications/luci-app-zerotier
bash move_2_services.sh
popd
ln -sf ../../../feeds/luci/applications/luci-app-zerotier ./package/feeds/luci/luci-app-zerotier
rm -rf ./feeds/packages/net/zerotier
#svn export https://github.com/openwrt/packages/trunk/net/zerotier feeds/packages/net/zerotier
svn export https://github.com/wongsyrone/packages-1/trunk/net/zerotier feeds/packages/net/zerotier
rm -rf ./feeds/packages/net/zerotier/files/etc/init.d/zerotier
#sed -i '/Default,one/a\\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(PKG_BUILD_DIR)/zerotier-one' feeds/packages/net/zerotier/Makefile
# 翻译及部分功能优化
svn export https://github.com/QiuSimons/OpenWrt-Add/trunk/addition-trans-zh package/lean/lean-translate
sed -i 's,iptables-mod-fullconenat,iptables-nft +kmod-nft-fullcone,g' package/lean/lean-translate/Makefile

### 最后的收尾工作 ###
# Lets Fuck
mkdir package/base-files/files/usr/bin
wget -P package/base-files/files/usr/bin/ https://github.com/QiuSimons/OpenWrt-Add/raw/master/fuck
#wget -P package/base-files/files/usr/bin/ https://github.com/QiuSimons/OpenWrt-Add/raw/master/ss2v2ray
# 最大连接数
sed -i 's/16384/65535/g' package/kernel/linux/files/sysctl-nf-conntrack.conf
# 生成默认配置及缓存
rm -rf .config

echo '
CONFIG_RESERVE_ACTIVEFILE_TO_PREVENT_DISK_THRASHING=y
CONFIG_RESERVE_ACTIVEFILE_KBYTES=65536
CONFIG_RESERVE_INACTIVEFILE_TO_PREVENT_DISK_THRASHING=y
CONFIG_RESERVE_INACTIVEFILE_KBYTES=65536

CONFIG_LRNG=y
# CONFIG_LRNG_OVERSAMPLE_ENTROPY_SOURCES is not set
CONFIG_LRNG_IRQ=y
CONFIG_LRNG_CONTINUOUS_COMPRESSION_ENABLED=y
# CONFIG_LRNG_CONTINUOUS_COMPRESSION_DISABLED is not set
CONFIG_LRNG_ENABLE_CONTINUOUS_COMPRESSION=y
# CONFIG_LRNG_SWITCHABLE_CONTINUOUS_COMPRESSION is not set
# CONFIG_LRNG_COLLECTION_SIZE_32 is not set
# CONFIG_LRNG_COLLECTION_SIZE_256 is not set
# CONFIG_LRNG_COLLECTION_SIZE_512 is not set
CONFIG_LRNG_COLLECTION_SIZE_1024=y
# CONFIG_LRNG_COLLECTION_SIZE_2048 is not set
# CONFIG_LRNG_COLLECTION_SIZE_4096 is not set
# CONFIG_LRNG_COLLECTION_SIZE_8192 is not set
CONFIG_LRNG_COLLECTION_SIZE=1024
# CONFIG_LRNG_HEALTH_TESTS is not set
CONFIG_LRNG_IRQ_ENTROPY_RATE=256
# CONFIG_LRNG_JENT is not set
CONFIG_LRNG_CPU=y
CONFIG_LRNG_CPU_ENTROPY_RATE=8
# CONFIG_LRNG_DRNG_SWITCH is not set
# CONFIG_LRNG_TESTING_MENU is not set
# CONFIG_LRNG_SELFTEST is not set

# CONFIG_IR_SANYO_DECODER is not set
# CONFIG_IR_SHARP_DECODER is not set
# CONFIG_IR_MCE_KBD_DECODER is not set
# CONFIG_IR_XMP_DECODER is not set
# CONFIG_IR_IMON_DECODER is not set
# CONFIG_IR_RCMM_DECODER is not set
# CONFIG_IR_SPI is not set
# CONFIG_IR_GPIO_TX is not set
# CONFIG_IR_PWM_TX is not set
# CONFIG_IR_SERIAL is not set
# CONFIG_IR_SIR is not set
# CONFIG_RC_XBOX_DVD is not set
# CONFIG_IR_TOY is not set
' >>./target/linux/generic/config-5.10

### Shortcut-FE 部分 ###
# Patch Kernel 以支持 Shortcut-FE
#pushd target/linux/generic/hack-5.4
#wget https://github.com/immortalwrt/immortalwrt/raw/master/target/linux/generic/hack-5.4/953-net-patch-linux-kernel-to-support-shortcut-fe.patch
#popd
# Patch LuCI 以增添 Shortcut-FE 开关
#patch -p1 < ../PATCH/firewall/luci-app-firewall_add_sfe_switch.patch
# Shortcut-FE 相关组件
#svn export https://github.com/coolsnowwolf/lede/trunk/package/lean/shortcut-fe package/lean/shortcut-fe
#svn export https://github.com/coolsnowwolf/lede/trunk/package/lean/fast-classifier package/lean/fast-classifier
#wget -P package/base-files/files/etc/init.d/ https://github.com/QiuSimons/OpenWrt-Add/raw/master/shortcut-fe


#exit 0
