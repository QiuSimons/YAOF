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
echo "net.netfilter.nf_conntrack_helper = 1" >>./package/kernel/linux/files/sysctl-nf-conntrack.conf
# Nginx
sed -i "s/large_client_header_buffers 2 1k/large_client_header_buffers 4 32k/g" feeds/packages/net/nginx-util/files/uci.conf.template
sed -i "s/client_max_body_size 128M/client_max_body_size 2048M/g" feeds/packages/net/nginx-util/files/uci.conf.template
sed -i '/client_max_body_size/a\\tclient_body_buffer_size 8192M;' feeds/packages/net/nginx-util/files/uci.conf.template
sed -i '/client_max_body_size/a\\tserver_names_hash_bucket_size 128;' feeds/packages/net/nginx-util/files/uci.conf.template
sed -i '/ubus_parallel_req/a\        ubus_script_timeout 600;' feeds/packages/net/nginx/files-luci-support/60_nginx-luci-support
sed -ri "/luci-webui.socket/i\ \t\tuwsgi_send_timeout 600\;\n\t\tuwsgi_connect_timeout 600\;\n\t\tuwsgi_read_timeout 600\;" feeds/packages/net/nginx/files-luci-support/luci.locations
sed -ri "/luci-cgi_io.socket/i\ \t\tuwsgi_send_timeout 600\;\n\t\tuwsgi_connect_timeout 600\;\n\t\tuwsgi_read_timeout 600\;" feeds/packages/net/nginx/files-luci-support/luci.locations
# FW4
rm -rf ./package/network/config/firewall4
cp -rf ../openwrt_ma/package/network/config/firewall4 ./package/network/config/firewall4

### 必要的 Patches ###
# TCP optimizations
cp -rf ../PATCH/backport/TCP/* ./target/linux/generic/backport-5.15/
# x86_csum
cp -rf ../PATCH/backport/x86_csum/* ./target/linux/generic/backport-5.15/
# Patch arm64 型号名称
cp -rf ../immortalwrt_23/target/linux/generic/hack-5.15/312-arm64-cpuinfo-Add-model-name-in-proc-cpuinfo-for-64bit-ta.patch ./target/linux/generic/hack-5.15/312-arm64-cpuinfo-Add-model-name-in-proc-cpuinfo-for-64bit-ta.patch
# BBRv3
cp -rf ../PATCH/BBRv3/kernel/* ./target/linux/generic/backport-5.15/
# LRNG
cp -rf ../PATCH/LRNG/* ./target/linux/generic/hack-5.15/
echo '
# CONFIG_RANDOM_DEFAULT_IMPL is not set
CONFIG_LRNG=y
# CONFIG_LRNG_IRQ is not set
CONFIG_LRNG_JENT=y
CONFIG_LRNG_CPU=y
# CONFIG_LRNG_SCHED is not set
' >>./target/linux/generic/config-5.15
# fstool
wget -qO - https://github.com/coolsnowwolf/lede/commit/8a4db76.patch | patch -p1
# wg
cp -rf ../PATCH/wg/* ./target/linux/generic/hack-5.15/

### Fullcone-NAT 部分 ###
# Patch Kernel 以解决 FullCone 冲突
cp -rf ../lede/target/linux/generic/hack-5.15/952-add-net-conntrack-events-support-multiple-registrant.patch ./target/linux/generic/hack-5.15/952-add-net-conntrack-events-support-multiple-registrant.patch
# bcmfullcone
cp -a ../PATCH/bcmfullcone/*.patch target/linux/generic/hack-5.15/
# Patch FireWall 以增添 FullCone 功能

# FW4
mkdir -p package/network/config/firewall4/patches
cp -f ../PATCH/firewall/firewall4_patches/*.patch ./package/network/config/firewall4/patches/
mkdir -p package/libs/libnftnl/patches
cp -f ../PATCH/firewall/libnftnl/*.patch ./package/libs/libnftnl/patches/
sed -i '/PKG_INSTALL:=/iPKG_FIXUP:=autoreconf' package/libs/libnftnl/Makefile
mkdir -p package/network/utils/nftables/patches
cp -f ../PATCH/firewall/nftables/*.patch ./package/network/utils/nftables/patches/
# custom nft command
patch -p1 < ../PATCH/firewall/100-openwrt-firewall4-add-custom-nft-command-support.patch
# Patch LuCI 以增添 FullCone 开关
pushd feeds/luci
patch -p1 <../../../PATCH/firewall/01-luci-app-firewall_add_nft-fullcone-bcm-fullcone_option.patch
popd
# ADD
cp -rf ../OpenWrt-Add ./package/new
rm -rf feeds/packages/net/{xray-core,v2ray-core,v2ray-geodata,sing-box}
rm -rf feeds/packages/utils/coremark

### 获取额外的基础软件包 ###
# 更换为 ImmortalWrt Uboot 以及 Target
rm -rf ./target/linux/rockchip
cp -rf ../immortalwrt_23/target/linux/rockchip ./target/linux/rockchip
cp -rf ../PATCH/rockchip-5.15/* ./target/linux/rockchip/patches-5.15/
rm -rf ./package/boot/uboot-rockchip
cp -rf ../immortalwrt_23/package/boot/uboot-rockchip ./package/boot/uboot-rockchip
rm -rf ./package/boot/arm-trusted-firmware-rockchip
cp -rf ../immortalwrt_23/package/boot/arm-trusted-firmware-rockchip ./package/boot/arm-trusted-firmware-rockchip
sed -i '/REQUIRE_IMAGE_METADATA/d' target/linux/rockchip/armv8/base-files/lib/upgrade/platform.sh
#intel-firmware
wget -qO - https://github.com/openwrt/openwrt/commit/9c58add.patch | patch -p1
wget -qO - https://github.com/openwrt/openwrt/commit/64f1a65.patch | patch -p1
wget -qO - https://github.com/openwrt/openwrt/commit/c21a3570.patch | patch -p1
sed -i '/I915/d' target/linux/x86/64/config-5.15
# Disable Mitigations
sed -i 's,rootwait,rootwait mitigations=off,g' target/linux/rockchip/image/default.bootscript
sed -i 's,@CMDLINE@ noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-efi.cfg
sed -i 's,@CMDLINE@ noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-iso.cfg
sed -i 's,@CMDLINE@ noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-pc.cfg


### 获取额外的 LuCI 应用、主题和依赖 ###
# dae ready
rm -rf ./feeds/packages/net/daed
rm -rf ./package/new/luci-app-daed
git clone -b test --depth 1 https://github.com/QiuSimons/luci-app-daed package/new/luci-app-daed
# btf
wget -qO - https://github.com/immortalwrt/immortalwrt/commit/73e5679.patch | patch -p1
wget https://github.com/immortalwrt/immortalwrt/raw/openwrt-23.05/target/linux/generic/backport-5.15/051-v5.18-bpf-Add-config-to-allow-loading-modules-with-BTF-mismatch.patch -O target/linux/generic/backport-5.15/051-v5.18-bpf-Add-config-to-allow-loading-modules-with-BTF-mismatch.patch
# bpf_loop
cp -f ../PATCH/bpf_loop/*.patch ./target/linux/generic/backport-5.15/
# mount cgroupv2
pushd feeds/packages
patch -p1 <../../../PATCH/cgroupfs-mount/0001-fix-cgroupfs-mount.patch
popd
mkdir -p feeds/packages/utils/cgroupfs-mount/patches
cp -rf ../PATCH/cgroupfs-mount/900-mount-cgroup-v2-hierarchy-to-sys-fs-cgroup-cgroup2.patch ./feeds/packages/utils/cgroupfs-mount/patches/
cp -rf ../PATCH/cgroupfs-mount/901-fix-cgroupfs-umount.patch ./feeds/packages/utils/cgroupfs-mount/patches/
cp -rf ../PATCH/cgroupfs-mount/902-mount-sys-fs-cgroup-systemd-for-docker-systemd-suppo.patch ./feeds/packages/utils/cgroupfs-mount/patches/
# luci-app-ap-modem
cp -rf ../linkease/applications/luci-app-ap-modem ./package/new/luci-app-ap-modem
# 更换 Nodejs 版本
rm -rf ./feeds/packages/lang/node
rm -rf ./package/new/feeds_packages_lang_node-prebuilt
cp -rf ../OpenWrt-Add/feeds_packages_lang_node-prebuilt ./feeds/packages/lang/node
# igc-fix
cp -rf ../lede/target/linux/x86/patches-5.15/996-intel-igc-i225-i226-disable-eee.patch ./target/linux/x86/patches-5.15/996-intel-igc-i225-i226-disable-eee.patch
# 更换 golang 版本
rm -rf ./feeds/packages/lang/golang
cp -rf ../openwrt_pkg_ma/lang/golang ./feeds/packages/lang/golang
# 访问控制
cp -rf ../OpenWrt-Add/luci-app-control-weburl ./package/new/luci-app-control-weburl
# MAC 地址与 IP 绑定
cp -rf ../immortalwrt_luci/applications/luci-app-arpbind ./feeds/luci/applications/luci-app-arpbind
ln -sf ../../../feeds/luci/applications/luci-app-arpbind ./package/feeds/luci/luci-app-arpbind
# Boost 通用即插即用
rm -rf ./feeds/packages/net/miniupnpd
cp -rf ../openwrt_pkg_ma/net/miniupnpd ./feeds/packages/net/miniupnpd
wget https://github.com/miniupnp/miniupnp/commit/0e8c68d.patch -O feeds/packages/net/miniupnpd/patches/0e8c68d.patch
sed -i 's,/miniupnpd/,/,g' ./feeds/packages/net/miniupnpd/patches/0e8c68d.patch
wget https://github.com/miniupnp/miniupnp/commit/21541fc.patch -O feeds/packages/net/miniupnpd/patches/21541fc.patch
sed -i 's,/miniupnpd/,/,g' ./feeds/packages/net/miniupnpd/patches/21541fc.patch
wget https://github.com/miniupnp/miniupnp/commit/b78a363.patch -O feeds/packages/net/miniupnpd/patches/b78a363.patch
sed -i 's,/miniupnpd/,/,g' ./feeds/packages/net/miniupnpd/patches/b78a363.patch
wget https://github.com/miniupnp/miniupnp/commit/8f2f392.patch -O feeds/packages/net/miniupnpd/patches/8f2f392.patch
sed -i 's,/miniupnpd/,/,g' ./feeds/packages/net/miniupnpd/patches/8f2f392.patch
wget https://github.com/miniupnp/miniupnp/commit/60f5705.patch -O feeds/packages/net/miniupnpd/patches/60f5705.patch
sed -i 's,/miniupnpd/,/,g' ./feeds/packages/net/miniupnpd/patches/60f5705.patch
wget https://github.com/miniupnp/miniupnp/commit/3f3582b.patch -O feeds/packages/net/miniupnpd/patches/3f3582b.patch
sed -i 's,/miniupnpd/,/,g' ./feeds/packages/net/miniupnpd/patches/3f3582b.patch
pushd feeds/packages
patch -p1 <../../../PATCH/miniupnpd/01-set-presentation_url.patch
patch -p1 <../../../PATCH/miniupnpd/02-force_forwarding.patch
patch -p1 <../../../PATCH/miniupnpd/03-Update-301-options-force_forwarding-support.patch.patch
popd
pushd feeds/luci
wget -qO- https://github.com/openwrt/luci/commit/0b5fb915.patch | patch -p1
popd
# CPU 控制相关
cp -rf ../immortalwrt_pkg/utils/cpulimit ./feeds/packages/utils/cpulimit
ln -sf ../../../feeds/packages/utils/cpulimit ./package/feeds/packages/cpulimit
# 动态DNS
sed -i '/boot()/,+2d' feeds/packages/net/ddns-scripts/files/etc/init.d/ddns
# Docker 容器
rm -rf ./feeds/luci/applications/luci-app-dockerman
cp -rf ../dockerman/applications/luci-app-dockerman ./feeds/luci/applications/luci-app-dockerman
sed -i '/auto_start/d' feeds/luci/applications/luci-app-dockerman/root/etc/uci-defaults/luci-app-dockerman
pushd feeds/packages
wget -qO- https://github.com/openwrt/packages/commit/e2e5ee69.patch | patch -p1
wget -qO- https://github.com/openwrt/packages/pull/20054.patch | patch -p1
popd
sed -i '/sysctl.d/d' feeds/packages/utils/dockerd/Makefile
rm -rf ./feeds/luci/collections/luci-lib-docker
cp -rf ../docker_lib/collections/luci-lib-docker ./feeds/luci/collections/luci-lib-docker
# FRP 内网穿透
rm -rf ./feeds/luci/applications/luci-app-frps
rm -rf ./feeds/luci/applications/luci-app-frpc
rm -rf ./feeds/packages/net/frp
cp -rf ../immortalwrt_pkg/net/frp ./feeds/packages/net/frp
sed -i '/etc/d' feeds/packages/net/frp/Makefile
sed -i '/defaults/{N;d;}' feeds/packages/net/frp/Makefile
cp -rf ../lede_luci/applications/luci-app-frps ./package/new/luci-app-frps
cp -rf ../lede_luci/applications/luci-app-frpc ./package/new/luci-app-frpc
# IPv6 兼容助手
cp -rf ../lede/package/lean/ipv6-helper ./package/new/ipv6-helper
patch -p1 <../PATCH/odhcp6c/1002-odhcp6c-support-dhcpv6-hotplug.patch
# ODHCPD
mkdir -p package/network/services/odhcpd/patches
cp -f ../PATCH/odhcpd/0001-odhcpd-improve-RFC-9096-compliance.patch ./package/network/services/odhcpd/patches/0001-odhcpd-improve-RFC-9096-compliance.patch
# 京东签到 By Jerrykuku
#git clone --depth 1 https://github.com/jerrykuku/node-request.git package/new/node-request
#git clone --depth 1 https://github.com/jerrykuku/luci-app-jd-dailybonus.git package/new/luci-app-jd-dailybonus
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
# uwsgi
sed -i 's,procd_set_param stderr 1,procd_set_param stderr 0,g' feeds/packages/net/uwsgi/files/uwsgi.init
sed -i 's,buffer-size = 10000,buffer-size = 131072,g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's,logger = luci,#logger = luci,g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i '$a cgi-timeout = 600' feeds/packages/net/uwsgi/files-luci-support/luci-*.ini
sed -i 's/threads = 1/threads = 2/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's/processes = 3/processes = 4/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's/cheaper = 1/cheaper = 2/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
# rpcd
sed -i 's/option timeout 30/option timeout 60/g' package/system/rpcd/files/rpcd.config
sed -i 's#20) \* 1000#60) \* 1000#g' feeds/luci/modules/luci-base/htdocs/luci-static/resources/rpc.js
# UU加速器
cp -rf ../lede_luci/applications/luci-app-uugamebooster ./package/new/luci-app-uugamebooster
cp -rf ../lede_pkg/net/uugamebooster ./package/new/uugamebooster
# watchcat
echo > ./feeds/packages/utils/watchcat/files/watchcat.config
# sirpdboy
mkdir -p package/sirpdboy
cp -rf ../sirpdboy/luci-app-autotimeset ./package/sirpdboy/luci-app-autotimeset
sed -i 's,"control","system",g' package/sirpdboy/luci-app-autotimeset/luasrc/controller/autotimeset.lua
sed -i '/firstchild/d' package/sirpdboy/luci-app-autotimeset/luasrc/controller/autotimeset.lua
sed -i 's,control,system,g' package/sirpdboy/luci-app-autotimeset/luasrc/view/autotimeset/log.htm
sed -i '/start()/a \    echo "Service autotimesetrun started!" >/dev/null' package/sirpdboy/luci-app-autotimeset/root/etc/init.d/autotimesetrun
rm -rf ./package/sirpdboy/luci-app-autotimeset/po/zh_Hans
cp -rf ../sirpdboy/luci-app-partexp ./package/sirpdboy/luci-app-partexp
rm -rf ./package/sirpdboy/luci-app-partexp/po/zh_Hans
sed -i 's, - !, -o !,g' package/sirpdboy/luci-app-partexp/root/etc/init.d/partexp
sed -i 's,expquit 1 ,#expquit 1 ,g' package/sirpdboy/luci-app-partexp/root/etc/init.d/partexp
# 翻译及部分功能优化
cp -rf ../OpenWrt-Add/addition-trans-zh ./package/new/addition-trans-zh

### 最后的收尾工作 ###
# Lets Fuck
mkdir -p package/base-files/files/usr/bin
cp -rf ../OpenWrt-Add/fuck ./package/base-files/files/usr/bin/fuck
# 生成默认配置及缓存
rm -rf .config
sed -i 's,CONFIG_WERROR=y,# CONFIG_WERROR is not set,g' target/linux/generic/config-5.15

### Shortcut-FE 部分 ###
# Patch Kernel 以支持 Shortcut-FE
cp -rf ../lede/target/linux/generic/hack-5.15/953-net-patch-linux-kernel-to-support-shortcut-fe.patch ./target/linux/generic/hack-5.15/953-net-patch-linux-kernel-to-support-shortcut-fe.patch
cp -f ../PATCH/backport/sfe/601-netfilter-export-udp_get_timeouts-function.patch ./target/linux/generic/hack-5.15/
cp -rf ../lede/target/linux/generic/pending-5.15/613-netfilter_optional_tcp_window_check.patch ./target/linux/generic/pending-5.15/613-netfilter_optional_tcp_window_check.patch
# Patch LuCI 以增添 Shortcut-FE 开关
patch -p1 < ../PATCH/firewall/luci-app-firewall_add_sfe_switch.patch
# natflow
# patch -p1 < ../PATCH/firewall/luci-app-firewall_add_natflow_switch.patch


# Patch LuCI 以增添 NAT6 开关
pushd feeds/luci
patch -p1 <../../../PATCH/firewall/03-luci-app-firewall_add_ipv6-nat.patch
# Patch LuCI 以支持自定义 nft 规则
patch -p1 <../../../PATCH/firewall/04-luci-add-firewall4-nft-rules-file.patch
popd

#LTO/GC
# Grub 2
sed -i 's,no-lto,no-lto no-gc-sections,g' package/boot/grub2/Makefile
# openssl disable LTO
sed -i 's,no-mips16 gc-sections,no-mips16 gc-sections no-lto,g' package/libs/openssl/Makefile
# nginx
sed -i 's,gc-sections,gc-sections no-lto,g' feeds/packages/net/nginx/Makefile
# libsodium
sed -i 's,no-mips16,no-mips16 no-lto,g' feeds/packages/libs/libsodium/Makefile
#exit 0
