#!/bin/bash
clear

### 基础部分 ###
# 使用 O2 级别的优化
sed -i 's/Os/O2/g' include/target.mk
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
cp -rf ../immortalwrt/scripts/download.pl ./scripts/download.pl
cp -rf ../immortalwrt/include/download.mk ./include/download.mk
sed -i '/unshift/d' scripts/download.pl
sed -i '/mirror02/d' scripts/download.pl
echo "net.netfilter.nf_conntrack_helper = 1" >>./package/kernel/linux/files/sysctl-nf-conntrack.conf
# Nginx
sed -i "s/client_max_body_size 128M/client_max_body_size 2048M/g" feeds/packages/net/nginx-util/files/uci.conf.template
sed -i '/client_max_body_size/a\\tclient_body_buffer_size 8192M;' feeds/packages/net/nginx-util/files/uci.conf.template
sed -i '/ubus_parallel_req/a\        ubus_script_timeout 600;' feeds/packages/net/nginx/files-luci-support/60_nginx-luci-support
sed -ri "/luci-webui.socket/i\ \t\tuwsgi_send_timeout 600\;\n\t\tuwsgi_connect_timeout 600\;\n\t\tuwsgi_read_timeout 600\;" feeds/packages/net/nginx/files-luci-support/luci.locations
sed -ri "/luci-cgi_io.socket/i\ \t\tuwsgi_send_timeout 600\;\n\t\tuwsgi_connect_timeout 600\;\n\t\tuwsgi_read_timeout 600\;" feeds/packages/net/nginx/files-luci-support/luci.locations

### 必要的 Patches ###
# introduce "MG-LRU" Linux kernel patches
cp -rf ../PATCH/backport/MG-LRU/* ./target/linux/generic/pending-5.10/
# TCP optimizations
cp -rf ../PATCH/backport/TCP/* ./target/linux/generic/backport-5.10/
# Patch arm64 型号名称
cp -rf ../immortalwrt/target/linux/generic/hack-5.10/312-arm64-cpuinfo-Add-model-name-in-proc-cpuinfo-for-64bit-ta.patch ./target/linux/generic/hack-5.10/312-arm64-cpuinfo-Add-model-name-in-proc-cpuinfo-for-64bit-ta.patch
# BBRv2
cp -rf ../PATCH/BBRv2/kernel/* ./target/linux/generic/hack-5.10/
cp -rf ../PATCH/BBRv2/openwrt/package ./
wget -qO - https://github.com/openwrt/openwrt/commit/7db9763.patch | patch -p1
# LRNG
cp -rf ../PATCH/LRNG/* ./target/linux/generic/hack-5.10/
# SSL
rm -rf ./package/libs/mbedtls
cp -rf ../immortalwrt/package/libs/mbedtls ./package/libs/mbedtls
rm -rf ./package/libs/openssl
cp -rf ../immortalwrt_21/package/libs/openssl ./package/libs/openssl
# fstool
wget -qO - https://github.com/coolsnowwolf/lede/commit/8a4db76.patch | patch -p1

### Fullcone-NAT 部分 ###
# Patch Kernel 以解决 FullCone 冲突
cp -rf ../lede/target/linux/generic/hack-5.10/952-net-conntrack-events-support-multiple-registrant.patch ./target/linux/generic/hack-5.10/952-net-conntrack-events-support-multiple-registrant.patch
cp -rf ../lede/target/linux/generic/hack-5.10/982-add-bcm-fullconenat-support.patch ./target/linux/generic/hack-5.10/982-add-bcm-fullconenat-support.patch
# Patch FireWall 以增添 FullCone 功能
# FW4
rm -rf ./package/network/config/firewall4
cp -rf ../immortalwrt/package/network/config/firewall4 ./package/network/config/firewall4
cp -f ../PATCH/firewall/990-unconditionally-allow-ct-status-dnat.patch ./package/network/config/firewall4/patches/990-unconditionally-allow-ct-status-dnat.patch
rm -rf ./package/libs/libnftnl
cp -rf ../immortalwrt/package/libs/libnftnl ./package/libs/libnftnl
rm -rf ./package/network/utils/nftables
cp -rf ../immortalwrt/package/network/utils/nftables ./package/network/utils/nftables
# FW3
mkdir -p package/network/config/firewall/patches
cp -rf ../immortalwrt_21/package/network/config/firewall/patches/100-fullconenat.patch ./package/network/config/firewall/patches/100-fullconenat.patch
cp -rf ../lede/package/network/config/firewall/patches/101-bcm-fullconenat.patch ./package/network/config/firewall/patches/101-bcm-fullconenat.patch
# iptables
cp -rf ../lede/package/network/utils/iptables/patches/900-bcm-fullconenat.patch ./package/network/utils/iptables/patches/900-bcm-fullconenat.patch
# network
wget -qO - https://github.com/openwrt/openwrt/commit/bbf39d07.patch | patch -p1
# Patch LuCI 以增添 FullCone 开关
pushd feeds/luci
wget -qO- https://github.com/openwrt/luci/commit/471182b2.patch | patch -p1
popd
# FullCone PKG
git clone --depth 1 https://github.com/fullcone-nat-nftables/nft-fullcone package/new/nft-fullcone
cp -rf ../Lienol/package/network/utils/fullconenat ./package/new/fullconenat

### 获取额外的基础软件包 ###
# 更换为 ImmortalWrt Uboot 以及 Target
rm -rf ./target/linux/rockchip
cp -rf ../lede/target/linux/rockchip ./target/linux/rockchip
rm -rf ./target/linux/rockchip/Makefile
cp -rf ../openwrt_release/target/linux/rockchip/Makefile ./target/linux/rockchip/Makefile
rm -rf ./target/linux/rockchip/armv8/config-5.10
cp -rf ../openwrt_release/target/linux/rockchip/armv8/config-5.10 ./target/linux/rockchip/armv8/config-5.10
rm -rf ./target/linux/rockchip/patches-5.10/002-net-usb-r8152-add-LED-configuration-from-OF.patch
rm -rf ./target/linux/rockchip/patches-5.10/003-dt-bindings-net-add-RTL8152-binding-documentation.patch
cp -rf ../PATCH/rockchip-5.10/* ./target/linux/rockchip/patches-5.10/
rm -rf ./package/firmware/linux-firmware/intel.mk
cp -rf ../lede/package/firmware/linux-firmware/intel.mk ./package/firmware/linux-firmware/intel.mk
rm -rf ./package/firmware/linux-firmware/Makefile
cp -rf ../lede/package/firmware/linux-firmware/Makefile ./package/firmware/linux-firmware/Makefile
mkdir -p target/linux/rockchip/files-5.10
cp -rf ../PATCH/files-5.10 ./target/linux/rockchip/
sed -i 's,+LINUX_6_1:kmod-drm-display-helper,,g' target/linux/rockchip/modules.mk
sed -i '/drm_dp_aux_bus\.ko/d' target/linux/rockchip/modules.mk
rm -rf ./package/boot/uboot-rockchip
cp -rf ../lede/package/boot/uboot-rockchip ./package/boot/uboot-rockchip
cp -rf ../lede/package/boot/arm-trusted-firmware-rockchip-vendor ./package/boot/arm-trusted-firmware-rockchip-vendor
rm -rf ./package/kernel/linux/modules/video.mk
cp -rf ../immortalwrt/package/kernel/linux/modules/video.mk ./package/kernel/linux/modules/video.mk
sed -i '/nouveau\.ko/d' package/kernel/linux/modules/video.mk
# Disable Mitigations
sed -i 's,rootwait,rootwait mitigations=off,g' target/linux/rockchip/image/mmc.bootscript
sed -i 's,rootwait,rootwait mitigations=off,g' target/linux/rockchip/image/nanopi-r2s.bootscript
sed -i 's,rootwait,rootwait mitigations=off,g' target/linux/rockchip/image/nanopi-r4s.bootscript
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-efi.cfg
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-iso.cfg
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-pc.cfg
# Dnsmasq
rm -rf ./package/network/services/dnsmasq
cp -rf ../openwrt_ma/package/network/services/dnsmasq ./package/network/services/dnsmasq
cp -rf ../openwrt_luci_ma/modules/luci-mod-network/htdocs/luci-static/resources/view/network/dhcp.js ./feeds/luci/modules/luci-mod-network/htdocs/luci-static/resources/view/network/


### 获取额外的 LuCI 应用、主题和依赖 ###
# dae ready
cp -rf ../immortalwrt/config/Config-kernel.in ./config/Config-kernel.in
rm -rf ./tools/dwarves
cp -rf ../openwrt_ma/tools/dwarves ./tools/dwarves
wget -qO - https://github.com/openwrt/openwrt/commit/aa95787e.patch | patch -p1
wget -qO - https://github.com/openwrt/openwrt/commit/29d7d6a8.patch | patch -p1
rm -rf ./tools/elfutils
cp -rf ../openwrt_ma/tools/elfutils ./tools/elfutils
rm -rf ./package/libs/elfutils
cp -rf ../openwrt_ma/package/libs/elfutils ./package/libs/elfutils
wget -qO - https://github.com/openwrt/openwrt/commit/b839f3d5.patch | patch -p1
rm -rf ./feeds/packages/net/frr
cp -rf ../openwrt_pkg_ma/net/frr feeds/packages/net/frr
cp -rf ../immortalwrt_pkg/net/dae ./feeds/packages/net/dae
ln -sf ../../../feeds/packages/net/dae ./package/feeds/packages/dae
# i915
wget -qO - https://github.com/openwrt/openwrt/commit/c21a3570.patch | patch -p1
cp -rf ../lede/target/linux/x86/64/config-5.10 ./target/linux/x86/64/config-5.10
# Haproxy
rm -rf ./feeds/packages/net/haproxy
cp -rf ../openwrt_pkg_ma/net/haproxy feeds/packages/net/haproxy
pushd feeds/packages
wget -qO - https://github.com/openwrt/packages/commit/a09cbcd.patch | patch -p1
popd
# AutoCore
cp -rf ../OpenWrt-Add/autocore ./package/new/autocore
sed -i 's/"getTempInfo" /"getTempInfo", "getCPUBench", "getCPUUsage" /g' package/new/autocore/files/generic/luci-mod-status-autocore.json
sed -i '/"$threads"/d' package/new/autocore/files/x86/autocore
rm -rf ./feeds/packages/utils/coremark
cp -rf ../immortalwrt_pkg/utils/coremark ./feeds/packages/utils/coremark
# Airconnect
cp -rf ../OpenWrt-Add/airconnect ./package/new/airconnect
cp -rf ../OpenWrt-Add/luci-app-airconnect ./package/new/luci-app-airconnect
# luci-app-irqbalance
cp -rf ../OpenWrt-Add/luci-app-irqbalance ./package/new/luci-app-irqbalance
# 更换 Nodejs 版本
rm -rf ./feeds/packages/lang/node
cp -rf ../openwrt-node/node ./feeds/packages/lang/node
rm -rf ./feeds/packages/lang/node-arduino-firmata
cp -rf ../openwrt-node/node-arduino-firmata ./feeds/packages/lang/node-arduino-firmata
rm -rf ./feeds/packages/lang/node-cylon
cp -rf ../openwrt-node/node-cylon ./feeds/packages/lang/node-cylon
rm -rf ./feeds/packages/lang/node-hid
cp -rf ../openwrt-node/node-hid ./feeds/packages/lang/node-hid
rm -rf ./feeds/packages/lang/node-homebridge
cp -rf ../openwrt-node/node-homebridge ./feeds/packages/lang/node-homebridge
rm -rf ./feeds/packages/lang/node-serialport
cp -rf ../openwrt-node/node-serialport ./feeds/packages/lang/node-serialport
rm -rf ./feeds/packages/lang/node-serialport-bindings
cp -rf ../openwrt-node/node-serialport-bindings ./feeds/packages/lang/node-serialport-bindings
rm -rf ./feeds/packages/lang/node-yarn
cp -rf ../openwrt-node/node-yarn ./feeds/packages/lang/node-yarn
ln -sf ../../../feeds/packages/lang/node-yarn ./package/feeds/packages/node-yarn
cp -rf ../openwrt-node/node-serialport-bindings-cpp ./feeds/packages/lang/node-serialport-bindings-cpp
ln -sf ../../../feeds/packages/lang/node-serialport-bindings-cpp ./package/feeds/packages/node-serialport-bindings-cpp
# R8168驱动
git clone -b master --depth 1 https://github.com/BROBIRD/openwrt-r8168.git package/new/r8168
patch -p1 <../PATCH/r8168/r8168-fix_LAN_led-for_r4s-from_TL.patch
# R8152驱动
cp -rf ../immortalwrt/package/kernel/r8152 ./package/new/r8152
# r8125驱动
git clone https://github.com/sbwml/package_kernel_r8125 package/new/r8125
# igc-backport
cp -rf ../PATCH/igc-files-5.10 ./target/linux/x86/files-5.10
# UPX 可执行软件压缩
sed -i '/patchelf pkgconf/i\tools-y += ucl upx' ./tools/Makefile
sed -i '\/autoconf\/compile :=/i\$(curdir)/upx/compile := $(curdir)/ucl/compile' ./tools/Makefile
cp -rf ../Lienol/tools/ucl ./tools/ucl
cp -rf ../Lienol/tools/upx ./tools/upx
# 更换 golang 版本
rm -rf ./feeds/packages/lang/golang
cp -rf ../openwrt_pkg_ma/lang/golang ./feeds/packages/lang/golang
# 访问控制
cp -rf ../lede_luci/applications/luci-app-accesscontrol ./package/new/luci-app-accesscontrol
cp -rf ../OpenWrt-Add/luci-app-control-weburl ./package/new/luci-app-control-weburl
# 广告过滤 AdGuard
git clone https://github.com/rufengsuixing/luci-app-adguardhome.git package/new/luci-app-adguardhome
rm -rf ./feeds/packages/net/adguardhome
cp -rf ../openwrt_pkg_ma/net/adguardhome ./feeds/packages/net/adguardhome
sed -i '/init/d' feeds/packages/net/adguardhome/Makefile
# Argon 主题
git clone -b master --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/new/luci-theme-argon
rm -rf ./package/new/luci-theme-argon/htdocs/luci-static/argon/background/README.md
git clone -b master --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/new/luci-app-argon-config
# MAC 地址与 IP 绑定
cp -rf ../immortalwrt_luci/applications/luci-app-arpbind ./feeds/luci/applications/luci-app-arpbind
ln -sf ../../../feeds/luci/applications/luci-app-arpbind ./package/feeds/luci/luci-app-arpbind
# 定时重启
cp -rf ../immortalwrt_luci/applications/luci-app-autoreboot ./feeds/luci/applications/luci-app-autoreboot
ln -sf ../../../feeds/luci/applications/luci-app-autoreboot ./package/feeds/luci/luci-app-autoreboot
# Boost 通用即插即用
rm -rf ./feeds/packages/net/miniupnpd
cp -rf ../openwrt_pkg_ma/net/miniupnpd ./feeds/packages/net/miniupnpd
pushd feeds/packages
wget -qO- https://github.com/openwrt/packages/commit/785bbcb.patch | patch -p1
wget -qO- https://github.com/openwrt/packages/commit/d811cb4.patch | patch -p1
wget -qO- https://github.com/openwrt/packages/commit/9a2da85.patch | patch -p1
wget -qO- https://github.com/openwrt/packages/commit/71dc090.patch | patch -p1
popd
wget -P feeds/packages/net/miniupnpd/patches/ https://github.com/ptpt52/openwrt-packages/raw/master/net/miniupnpd/patches/201-change-default-chain-rule-to-accept.patch
wget -P feeds/packages/net/miniupnpd/patches/ https://github.com/ptpt52/openwrt-packages/raw/master/net/miniupnpd/patches/500-0004-miniupnpd-format-xml-to-make-some-app-happy.patch
wget -P feeds/packages/net/miniupnpd/patches/ https://github.com/ptpt52/openwrt-packages/raw/master/net/miniupnpd/patches/500-0005-miniupnpd-stun-ignore-external-port-changed.patch
wget -P feeds/packages/net/miniupnpd/patches/ https://github.com/ptpt52/openwrt-packages/raw/master/net/miniupnpd/patches/500-0006-miniupnpd-fix-stun-POSTROUTING-filter-for-openwrt.patch
rm -rf ./feeds/luci/applications/luci-app-upnp
cp -rf ../openwrt_luci_ma/applications/luci-app-upnp ./feeds/luci/applications/luci-app-upnp
pushd feeds/luci
wget -qO- https://github.com/openwrt/luci/commit/0b5fb915.patch | patch -p1
popd
# ChinaDNS
git clone -b luci --depth 1 https://github.com/QiuSimons/openwrt-chinadns-ng.git package/new/luci-app-chinadns-ng
cp -rf ../passwall_pkg/chinadns-ng ./package/new/chinadns-ng
# CPU 控制相关
cp -rf ../OpenWrt-Add/luci-app-cpufreq ./feeds/luci/applications/luci-app-cpufreq
ln -sf ../../../feeds/luci/applications/luci-app-cpufreq ./package/feeds/luci/luci-app-cpufreq
sed -i 's,1608,1800,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/10-cpufreq
sed -i 's,2016,2208,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/10-cpufreq
sed -i 's,1512,1608,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/10-cpufreq
cp -rf ../OpenWrt-Add/luci-app-cpulimit ./package/new/luci-app-cpulimit
cp -rf ../immortalwrt_pkg/utils/cpulimit ./feeds/packages/utils/cpulimit
ln -sf ../../../feeds/packages/utils/cpulimit ./package/feeds/packages/cpulimit
# 动态DNS
sed -i '/boot()/,+2d' feeds/packages/net/ddns-scripts/files/etc/init.d/ddns
cp -rf ../openwrt-third/ddns-scripts_aliyun ./feeds/packages/net/ddns-scripts_aliyun
ln -sf ../../../feeds/packages/net/ddns-scripts_aliyun ./package/feeds/packages/ddns-scripts_aliyun
cp -rf ../openwrt-third/ddns-scripts_dnspod ./feeds/packages/net/ddns-scripts_dnspod
ln -sf ../../../feeds/packages/net/ddns-scripts_dnspod ./package/feeds/packages/ddns-scripts_dnspod
# Docker 容器
rm -rf ./feeds/luci/applications/luci-app-dockerman
cp -rf ../dockerman/applications/luci-app-dockerman ./feeds/luci/applications/luci-app-dockerman
sed -i '/auto_start/d' feeds/luci/applications/luci-app-dockerman/root/etc/uci-defaults/luci-app-dockerman
pushd feeds/luci
wget -qO- https://github.com/openwrt/luci/commit/0c1fc7f.patch | patch -p1
popd
pushd feeds/packages
wget -qO- https://github.com/openwrt/packages/commit/d9d5109.patch | patch -p1
popd
sed -i '/sysctl.d/d' feeds/packages/utils/dockerd/Makefile
rm -rf ./feeds/luci/collections/luci-lib-docker
cp -rf ../docker_lib/collections/luci-lib-docker ./feeds/luci/collections/luci-lib-docker
# DiskMan
cp -rf ../diskman/applications/luci-app-diskman ./package/new/luci-app-diskman
mkdir -p package/new/parted && \
wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/Parted.Makefile -O package/new/parted/Makefile
# Dnsfilter
git clone --depth 1 https://github.com/kiddin9/luci-app-dnsfilter.git package/new/luci-app-dnsfilter
# Dnsproxy
cp -rf ../OpenWrt-Add/luci-app-dnsproxy ./package/new/luci-app-dnsproxy
# Edge 主题
git clone -b master --depth 1 https://github.com/kiddin9/luci-theme-edge.git package/new/luci-theme-edge
# FRP 内网穿透
rm -rf ./feeds/luci/applications/luci-app-frps
rm -rf ./feeds/luci/applications/luci-app-frpc
rm -rf ./feeds/packages/net/frp
rm -f ./package/feeds/packages/frp
cp -rf ../lede_luci/applications/luci-app-frps ./package/new/luci-app-frps
cp -rf ../lede_luci/applications/luci-app-frpc ./package/new/luci-app-frpc
cp -rf ../lede_pkg/net/frp ./package/new/frp
# IPSec
cp -rf ../lede_luci/applications/luci-app-ipsec-server ./package/new/luci-app-ipsec-server
# IPv6 兼容助手
cp -rf ../lede/package/lean/ipv6-helper ./package/new/ipv6-helper
# 京东签到 By Jerrykuku
#git clone --depth 1 https://github.com/jerrykuku/node-request.git package/new/node-request
#git clone --depth 1 https://github.com/jerrykuku/luci-app-jd-dailybonus.git package/new/luci-app-jd-dailybonus
# MentoHUST
git clone --depth 1 https://github.com/BoringCat/luci-app-mentohust package/new/luci-app-mentohust
git clone --depth 1 https://github.com/KyleRicardo/MentoHUST-OpenWrt-ipk package/new/MentoHUST
# Mosdns
cp -rf ../mosdns/mosdns ./package/new/mosdns
cp -rf ../mosdns/luci-app-mosdns ./package/new/luci-app-mosdns
cp -rf ../mosdns/v2ray-geodata ./package/new/v2ray-geodata
# 流量监管
cp -rf ../lede_luci/applications/luci-app-netdata ./package/new/luci-app-netdata
# 上网 APP 过滤
git clone -b master --depth 1 https://github.com/destan19/OpenAppFilter.git package/new/OpenAppFilter
pushd package/new/OpenAppFilter
wget -qO - https://github.com/QiuSimons/OpenAppFilter-destan19/commit/9088cc2.patch | patch -p1
wget https://destan19.github.io/assets/oaf/open_feature/feature-cn-22-06-21.cfg -O ./open-app-filter/files/feature.cfg
popd
# OLED 驱动程序
git clone -b master --depth 1 https://github.com/NateLol/luci-app-oled.git package/new/luci-app-oled
# OpenClash
git clone --single-branch --depth 1 -b dev https://github.com/vernesong/OpenClash.git package/new/luci-app-openclash
# Passwall
cp -rf ../passwall_luci/luci-app-passwall ./package/new/luci-app-passwall
pushd package/new/luci-app-passwall
sed -i 's,iptables-legacy,iptables-nft,g' Makefile
popd
wget -P package/new/luci-app-passwall/ https://github.com/QiuSimons/OpenWrt-Add/raw/master/move_2_services.sh
chmod -R 755 ./package/new/luci-app-passwall/move_2_services.sh
pushd package/new/luci-app-passwall
bash move_2_services.sh
popd
cp -rf ../passwall_pkg/tcping ./package/new/tcping
cp -rf ../passwall_pkg/trojan-go ./package/new/trojan-go
cp -rf ../passwall_pkg/brook ./package/new/brook
cp -rf ../passwall_pkg/ssocks ./package/new/ssocks
cp -rf ../passwall_pkg/microsocks ./package/new/microsocks
cp -rf ../passwall_pkg/dns2socks ./package/new/dns2socks
cp -rf ../passwall_pkg/ipt2socks ./package/new/ipt2socks
cp -rf ../passwall_pkg/pdnsd-alt ./package/new/pdnsd-alt
cp -rf ../OpenWrt-Add/trojan-plus ./package/new/trojan-plus
cp -rf ../passwall_pkg/xray-plugin ./package/new/xray-plugin
# Passwall 白名单
echo '
teamviewer.com
epicgames.com
dangdang.com
account.synology.com
ddns.synology.com
checkip.synology.com
checkip.dyndns.org
checkipv6.synology.com
ntp.aliyun.com
cn.ntp.org.cn
ntp.ntsc.ac.cn
' >>./package/new/luci-app-passwall/root/usr/share/passwall/rules/direct_host
# qBittorrent 下载
cp -rf ../lede_luci/applications/luci-app-qbittorrent ./package/new/luci-app-qbittorrent
cp -rf ../lede_pkg/net/qBittorrent-static ./package/new/qBittorrent-static
cp -rf ../lede_pkg/net/qBittorrent ./package/new/qBittorrent
cp -rf ../lede_pkg/libs/qtbase ./package/new/qtbase
cp -rf ../lede_pkg/libs/qttools ./package/new/qttools
cp -rf ../lede_pkg/libs/rblibtorrent ./package/new/rblibtorrent
# 清理内存
cp -rf ../lede_luci/applications/luci-app-ramfree ./package/new/luci-app-ramfree
# ServerChan 微信推送
git clone -b master --depth 1 https://github.com/tty228/luci-app-serverchan.git package/new/luci-app-serverchan
# ShadowsocksR Plus+ 依赖
rm -rf ./feeds/packages/net/shadowsocks-libev
cp -rf ../lede_pkg/net/shadowsocks-libev ./package/new/shadowsocks-libev
cp -rf ../ssrp/redsocks2 ./package/new/redsocks2
cp -rf ../ssrp/trojan ./package/new/trojan
cp -rf ../ssrp/tcping ./package/new/tcping
cp -rf ../ssrp/dns2tcp ./package/new/dns2tcp
cp -rf ../ssrp/gn ./package/new/gn
cp -rf ../ssrp/shadowsocksr-libev ./package/new/shadowsocksr-libev
cp -rf ../ssrp/simple-obfs ./package/new/simple-obfs
cp -rf ../ssrp/naiveproxy ./package/new/naiveproxy
cp -rf ../ssrp/v2ray-core ./package/new/v2ray-core
cp -rf ../ssrp/hysteria ./package/new/hysteria
cp -rf ../ssrp/sagernet-core ./package/new/sagernet-core
rm -rf ./feeds/packages/net/xray-core
cp -rf ../ssrp/xray-core ./package/new/xray-core
cp -rf ../ssrp/v2ray-plugin ./package/new/v2ray-plugin
cp -rf ../ssrp/shadowsocks-rust ./package/new/shadowsocks-rust
cp -rf ../ssrp/lua-neturl ./package/new/lua-neturl
rm -rf ./feeds/packages/net/kcptun
cp -rf ../immortalwrt_pkg/net/kcptun ./feeds/packages/net/kcptun
ln -sf ../../../feeds/packages/net/kcptun ./package/feeds/packages/kcptun
# ShadowsocksR Plus+
cp -rf ../ssrp/luci-app-ssr-plus ./package/new/luci-app-ssr-plus
rm -rf ./package/new/luci-app-ssr-plus/po/zh_Hans
pushd package/new
wget -qO - https://github.com/fw876/helloworld/commit/5bbf6e7.patch | patch -p1
popd
pushd package/new/luci-app-ssr-plus
sed -i '/Clang.CN.CIDR/a\o:value("https://gh.404delivr.workers.dev/https://github.com/QiuSimons/Chnroute/raw/master/dist/chnroute/chnroute.txt", translate("QiuSimons/Chnroute"))' luasrc/model/cbi/shadowsocksr/advanced.lua
popd
# v2raya
git clone --depth 1 https://github.com/zxlhhyccc/luci-app-v2raya.git package/new/luci-app-v2raya
rm -rf ./feeds/packages/net/v2raya
cp -rf ../openwrt_pkg_ma/net/v2raya ./feeds/packages/net/v2raya
ln -sf ../../../feeds/packages/net/v2raya ./package/feeds/packages/v2raya
# socat
cp -rf ../Lienol_pkg/luci-app-socat ./package/new/luci-app-socat
sed -i '/socat\.config/d' feeds/packages/net/socat/Makefile
# 订阅转换
cp -rf ../immortalwrt_pkg/net/subconverter ./feeds/packages/net/subconverter
ln -sf ../../../feeds/packages/net/subconverter ./package/feeds/packages/subconverter
cp -rf ../immortalwrt_pkg/libs/jpcre2 ./feeds/packages/libs/jpcre2
ln -sf ../../../feeds/packages/libs/jpcre2 ./package/feeds/packages/jpcre2
cp -rf ../immortalwrt_pkg/libs/rapidjson ./feeds/packages/libs/rapidjson
ln -sf ../../../feeds/packages/libs/rapidjson ./package/feeds/packages/rapidjson
cp -rf ../immortalwrt_pkg/libs/libcron ./feeds/packages/libs/libcron
ln -sf ../../../feeds/packages/libs/libcron ./package/feeds/packages/libcron
cp -rf ../immortalwrt_pkg/libs/quickjspp ./feeds/packages/libs/quickjspp
ln -sf ../../../feeds/packages/libs/quickjspp ./package/feeds/packages/quickjspp
cp -rf ../immortalwrt_pkg/libs/toml11 ./feeds/packages/libs/toml11
ln -sf ../../../feeds/packages/libs/toml11 ./package/feeds/packages/toml11
# 网易云音乐解锁
git clone -b js --depth 1 https://github.com/UnblockNeteaseMusic/luci-app-unblockneteasemusic.git package/new/UnblockNeteaseMusic
# uwsgi
sed -i 's,procd_set_param stderr 1,procd_set_param stderr 0,g' feeds/packages/net/uwsgi/files/uwsgi.init
sed -i 's,buffer-size = 10000,buffer-size = 131072,g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's,logger = luci,#logger = luci,g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i '$a cgi-timeout = 600' feeds/packages/net/uwsgi/files-luci-support/luci-*.ini
# rpcd
sed -i 's/option timeout 30/option timeout 60/g' package/system/rpcd/files/rpcd.config
sed -i 's#20) \* 1000#60) \* 1000#g' feeds/luci/modules/luci-base/htdocs/luci-static/resources/rpc.js
# USB 打印机
cp -rf ../lede_luci/applications/luci-app-usb-printer ./package/new/luci-app-usb-printer
# UU加速器
cp -rf ../lede_luci/applications/luci-app-uugamebooster ./package/new/luci-app-uugamebooster
cp -rf ../lede_pkg/net/uugamebooster ./package/new/uugamebooster
# KMS 激活助手
cp -rf ../lede_luci/applications/luci-app-vlmcsd ./package/new/luci-app-vlmcsd
cp -rf ../lede_pkg/net/vlmcsd ./package/new/vlmcsd
# VSSR
git clone -b master --depth 1 https://github.com/jerrykuku/luci-app-vssr.git package/new/luci-app-vssr
git clone -b master --depth 1 https://github.com/jerrykuku/lua-maxminddb.git package/new/lua-maxminddb
# 网络唤醒
cp -rf ../zxlhhyccc/zxlhhyccc/luci-app-wolplus ./package/new/luci-app-wolplus
# 流量监视
git clone -b master --depth 1 https://github.com/brvphoenix/wrtbwmon.git package/new/wrtbwmon
git clone -b master --depth 1 https://github.com/brvphoenix/luci-app-wrtbwmon.git package/new/luci-app-wrtbwmon
# 迅雷快鸟宽带加速
git clone --depth 1 https://github.com/kiddin9/luci-app-xlnetacc.git package/lean/luci-app-xlnetacc
# Zerotier
cp -rf ../immortalwrt_luci/applications/luci-app-zerotier ./feeds/luci/applications/luci-app-zerotier
cp -rf ../OpenWrt-Add/move_2_services.sh ./feeds/luci/applications/luci-app-zerotier/move_2_services.sh
chmod -R 755 ./feeds/luci/applications/luci-app-zerotier/move_2_services.sh
pushd feeds/luci/applications/luci-app-zerotier
bash move_2_services.sh
popd
ln -sf ../../../feeds/luci/applications/luci-app-zerotier ./package/feeds/luci/luci-app-zerotier
rm -rf ./feeds/packages/net/zerotier
cp -rf ../immortalwrt_pkg/net/zerotier ./feeds/packages/net/zerotier
# watchcat
echo > ./feeds/packages/utils/watchcat/files/watchcat.config
# 翻译及部分功能优化
cp -rf ../OpenWrt-Add/addition-trans-zh ./package/new/addition-trans-zh
sed -i 's,iptables-mod-fullconenat,iptables-nft +kmod-nft-fullcone,g' package/new/addition-trans-zh/Makefile

### 最后的收尾工作 ###
# Lets Fuck
mkdir -p package/base-files/files/usr/bin
cp -rf ../OpenWrt-Add/fuck ./package/base-files/files/usr/bin/fuck
# 生成默认配置及缓存
rm -rf .config
cat ../SEED/extra.cfg >> ./target/linux/generic/config-5.10

### Shortcut-FE 部分 ###
# Patch Kernel 以支持 Shortcut-FE
cp -rf ../lede/target/linux/generic/hack-5.10/953-net-patch-linux-kernel-to-support-shortcut-fe.patch ./target/linux/generic/hack-5.10/953-net-patch-linux-kernel-to-support-shortcut-fe.patch
# Patch LuCI 以增添 Shortcut-FE 开关
patch -p1 < ../PATCH/firewall/luci-app-firewall_add_sfe_switch.patch
# Shortcut-FE 相关组件
mkdir ./package/lean
mkdir ./package/lean/shortcut-fe
cp -rf ../lede/package/lean/shortcut-fe/fast-classifier ./package/lean/shortcut-fe/fast-classifier
cp -rf ../lede/package/lean/shortcut-fe/shortcut-fe ./package/lean/shortcut-fe/shortcut-fe
cp -rf ../lede/package/lean/shortcut-fe/simulated-driver ./package/lean/shortcut-fe/simulated-driver
wget -qO - https://github.com/coolsnowwolf/lede/commit/e517080.patch | patch -p1
#exit 0
