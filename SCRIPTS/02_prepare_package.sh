#!/bin/bash
clear

##准备工作
#使用19.07的feed源
rm -f ./feeds.conf.default
wget https://github.com/openwrt/openwrt/raw/openwrt-19.07/feeds.conf.default
wget -P include/ https://github.com/openwrt/openwrt/raw/openwrt-19.07/include/scons.mk
patch -p1 < ../PATCH/new/main/0001-tools-add-upx-ucl-support.patch
#remove annoying snapshot tag
sed -i 's,SNAPSHOT,,g' include/version.mk
sed -i 's,snapshots,,g' package/base-files/image-config.in
#使用O2级别的优化
sed -i 's/Os/O2/g' include/target.mk
sed -i 's/O2/O2/g' ./rules.mk
#更新feed
./scripts/feeds update -a && ./scripts/feeds install -a

##R2S相关
#3328 add idle
wget -P target/linux/rockchip/patches-5.4 https://github.com/project-openwrt/openwrt/raw/master/target/linux/rockchip/patches-5.4/005-arm64-dts-rockchip-Add-RK3328-idle-state.patch
#IRQ
sed -i '/;;/i\set_interface_core 8 "ff160000" "ff160000.i2c"' target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/40-net-smp-affinity
sed -i '/;;/i\set_interface_core 1 "ff150000" "ff150000.i2c"' target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/40-net-smp-affinity
#disabed rk3328 ethernet tcp/udp offloading tx/rx
sed -i '/;;/i\ethtool -K eth0 rx off tx off && logger -t disable-offloading "disabed rk3328 ethernet tcp/udp offloading tx/rx"' target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/40-net-smp-affinity
#r8152新驱动（可选
#wget -O- https://github.com/project-openwrt/openwrt/commit/d8df86130d172b3ce262d2744e2ddd2a6eed5f50.patch | patch -p1
svn co https://github.com/project-openwrt/openwrt/branches/master/package/ctcgfw/r8152 package/new/r8152
sed -i '/rtl8152/d' ./target/linux/rockchip/image/armv8.mk
#HW-RNG（硬件随机数，可选
patch -p1 < ../PATCH/new/main/Support-hardware-random-number-generator-for-RK3328.patch
sed -i 's/-f/-f -i/g' feeds/packages/utils/rng-tools/files/rngd.init
#patch i2c0（服务于OLED，可选
cp -f ../PATCH/new/main/998-rockchip-enable-i2c0-on-NanoPi-R2S.patch ./target/linux/rockchip/patches-5.4/998-rockchip-enable-i2c0-on-NanoPi-R2S.patch
#OC（提升主频，可选
cp -f ../PATCH/new/main/999-unlock-1608mhz-rk3328.patch ./target/linux/rockchip/patches-5.4/999-unlock-1608mhz-rk3328.patch
#SWAP LAN WAN（满足千兆场景，可选
sed -i 's,"eth1" "eth0","eth0" "eth1",g' target/linux/rockchip/armv8/base-files/etc/board.d/02_network
sed -i "s,'eth1' 'eth0','eth0' 'eth1',g" target/linux/rockchip/armv8/base-files/etc/board.d/02_network

##必要的patch
#luci network
patch -p1 < ../PATCH/new/main/luci_network-add-packet-steering.patch
#patch jsonc
patch -p1 < ../PATCH/new/package/use_json_object_new_int64.patch
#patch dnsmasq
patch -p1 < ../PATCH/new/package/dnsmasq-add-filter-aaaa-option.patch
patch -p1 < ../PATCH/new/package/luci-add-filter-aaaa-option.patch
cp -f ../PATCH/new/package/900-add-filter-aaaa-option.patch ./package/network/services/dnsmasq/patches/900-add-filter-aaaa-option.patch
rm -rf ./package/base-files/files/etc/init.d/boot
wget -P package/base-files/files/etc/init.d https://github.com/project-openwrt/openwrt/raw/openwrt-18.06-k5.4/package/base-files/files/etc/init.d/boot
#（从这行开始接下来5个操作全是和fullcone相关的，不需要可以一并注释掉，但极不建议
#回滚FW3
rm -rf ./package/network/config/firewall
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/network/config/firewall package/network/config/firewall
# Patch Kernel 以解决fullcone冲突
pushd target/linux/generic/hack-5.4
wget https://github.com/coolsnowwolf/lede/raw/master/target/linux/generic/hack-5.4/952-net-conntrack-events-support-multiple-registrant.patch
popd
#Patch FireWall 以增添fullcone功能 
mkdir package/network/config/firewall/patches
wget -P package/network/config/firewall/patches/ https://github.com/LGA1150/fullconenat-fw3-patch/raw/master/fullconenat.patch
# Patch LuCI 以增添fullcone开关
pushd feeds/luci
wget -O- https://github.com/LGA1150/fullconenat-fw3-patch/raw/master/luci.patch | git apply
popd
#FullCone 相关组件
cp -rf ../openwrt-lienol/package/network/fullconenat ./package/network/fullconenat
#（从这行开始接下来3个操作全是和SFE相关的，不需要可以一并注释掉，但极不建议
# Patch Kernel 以支援SFE
pushd target/linux/generic/hack-5.4
wget https://github.com/coolsnowwolf/lede/raw/master/target/linux/generic/hack-5.4/953-net-patch-linux-kernel-to-support-shortcut-fe.patch
popd
# Patch LuCI 以增添SFE开关
patch -p1 < ../PATCH/new/package/luci-app-firewall_add_sfe_switch.patch
# SFE 相关组件
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/shortcut-fe package/new/shortcut-fe
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/fast-classifier package/new/fast-classifier
cp -f ../PATCH/duplicate/shortcut-fe ./package/base-files/files/etc/init.d

##获取额外package
#（不用注释这里的任何东西，这不会对提升action的执行速度起到多大的帮助
#（不需要的包直接修改seed就好
#luci-app-compressed-memory
wget -O- https://patch-diff.githubusercontent.com/raw/openwrt/openwrt/pull/2840.patch | patch -p1
mkdir ./package/new
cp -rf ../NoTengoBattery/feeds/luci/applications/luci-app-compressed-memory ./package/new/luci-app-compressed-memory
sed -i 's,include ../..,include $(TOPDIR)/feeds/luci,g' ./package/new/luci-app-compressed-memory/Makefile
rm -rf ./package/system/compressed-memory
cp -rf ../NoTengoBattery/package/system/compressed-memory ./package/system/compressed-memory
#更换cryptodev-linux
rm -rf ./package/kernel/cryptodev-linux
svn co https://github.com/project-openwrt/openwrt/trunk/package/kernel/cryptodev-linux package/kernel/cryptodev-linux
#更换curl
rm -rf ./package/network/utils/curl
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/network/utils/curl package/network/utils/curl
#更换Node版本
rm -rf ./feeds/packages/lang/node
svn co https://github.com/nxhack/openwrt-node-packages/trunk/node feeds/packages/lang/node
rm -rf ./feeds/packages/lang/node-arduino-firmata
svn co https://github.com/nxhack/openwrt-node-packages/trunk/node-arduino-firmata feeds/packages/lang/node-arduino-firmata
rm -rf ./feeds/packages/lang/node-cylon
svn co https://github.com/nxhack/openwrt-node-packages/trunk/node-cylon feeds/packages/lang/node-cylon
rm -rf ./feeds/packages/lang/node-hid
svn co https://github.com/nxhack/openwrt-node-packages/trunk/node-hid feeds/packages/lang/node-hid
rm -rf ./feeds/packages/lang/node-homebridge
svn co https://github.com/nxhack/openwrt-node-packages/trunk/node-homebridge feeds/packages/lang/node-homebridge
rm -rf ./feeds/packages/lang/node-serialport
svn co https://github.com/nxhack/openwrt-node-packages/trunk/node-serialport feeds/packages/lang/node-serialport
rm -rf ./feeds/packages/lang/node-serialport-bindings
svn co https://github.com/nxhack/openwrt-node-packages/trunk/node-serialport-bindings feeds/packages/lang/node-serialport-bindings
#更换libcap
rm -rf ./feeds/packages/libs/libcap/
svn co https://github.com/openwrt/packages/trunk/libs/libcap feeds/packages/libs/libcap
#更换GCC版本
rm -rf ./feeds/packages/devel/gcc
svn co https://github.com/openwrt/packages/trunk/devel/gcc feeds/packages/devel/gcc
#更换Golang版本
rm -rf ./feeds/packages/lang/golang
svn co https://github.com/openwrt/packages/trunk/lang/golang feeds/packages/lang/golang
#beardropper
git clone https://github.com/NateLol/luci-app-beardropper package/luci-app-beardropper
sed -i 's/"luci.fs"/"luci.sys".net/g' package/luci-app-beardropper/luasrc/model/cbi/beardropper/setting.lua
sed -i '/firewall/d' package/luci-app-beardropper/root/etc/uci-defaults/luci-beardropper
#luci-app-freq
svn co https://github.com/project-openwrt/openwrt/branches/master/package/lean/luci-app-cpufreq package/lean/luci-app-cpufreq
patch -p1 < ../PATCH/new/package/luci-app-freq.patch
#京东签到
git clone https://github.com/jerrykuku/node-request package/new/node-request
git clone https://github.com/jerrykuku/luci-app-jd-dailybonus package/new/luci-app-jd-dailybonus
#arpbind
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-arpbind package/lean/luci-app-arpbind
#Adbyby
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-adbyby-plus package/lean/luci-app-adbyby-plus
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/adbyby package/lean/adbyby
#访问控制
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-accesscontrol package/lean/luci-app-accesscontrol
cp -rf ../PATCH/duplicate/luci-app-control-weburl ./package/new/luci-app-control-weburl
#AutoCore
svn co https://github.com/project-openwrt/openwrt/branches/master/package/lean/autocore package/lean/autocore
svn co https://github.com/project-openwrt/packages/trunk/utils/coremark feeds/packages/utils/coremark
ln -sf ../../../feeds/packages/utils/coremark ./package/feeds/packages/coremark
sed -i 's,default n,default y,g' feeds/packages/utils/coremark/Makefile
#迅雷快鸟
#svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-xlnetacc package/lean/luci-app-xlnetacc
git clone https://github.com/garypang13/luci-app-xlnetacc package/lean/luci-app-xlnetacc
#DDNS
rm -rf ./feeds/packages/net/ddns-scripts
rm -rf ./feeds/luci/applications/luci-app-ddns
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/ddns-scripts_aliyun package/lean/ddns-scripts_aliyun
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/ddns-scripts_dnspod package/lean/ddns-scripts_dnspod
svn co https://github.com/openwrt/packages/branches/openwrt-18.06/net/ddns-scripts feeds/packages/net/ddns-scripts
svn co https://github.com/openwrt/luci/branches/openwrt-18.06/applications/luci-app-ddns feeds/luci/applications/luci-app-ddns
#Pandownload
svn co https://github.com/project-openwrt/openwrt/branches/master/package/lean/pandownload-fake-server package/lean/pandownload-fake-server
#oled
git clone -b master --single-branch https://github.com/NateLol/luci-app-oled package/new/luci-app-oled
#网易云解锁
git clone https://github.com/project-openwrt/luci-app-unblockneteasemusic package/new/UnblockNeteaseMusic
#定时重启
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-autoreboot package/lean/luci-app-autoreboot
#argon主题
git clone -b master --single-branch https://github.com/jerrykuku/luci-theme-argon package/new/luci-theme-argon
git clone -b master --single-branch https://github.com/jerrykuku/luci-app-argon-config package/new/luci-app-argon-config
#edge主题
git clone -b master --single-branch https://github.com/garypang13/luci-theme-edge package/new/luci-theme-edge
#AdGuard
cp -rf ../openwrt-lienol/package/diy/luci-app-adguardhome ./package/new/luci-app-adguardhome
cp -rf ../openwrt-lienol/package/diy/adguardhome ./package/new/adguardhome
#svn co https://github.com/project-openwrt/openwrt/branches/openwrt-19.07/package/ntlf9t/AdGuardHome package/new/AdGuardHome
#ChinaDNS
git clone -b luci https://github.com/pexcn/openwrt-chinadns-ng.git package/new/luci-app-chinadns-ng
git clone https://github.com/pexcn/openwrt-chinadns-ng.git package/new/chinadns-ng
#VSSR
git clone -b master --single-branch https://github.com/jerrykuku/luci-app-vssr package/lean/luci-app-vssr
git clone -b master --single-branch https://github.com/jerrykuku/lua-maxminddb package/lean/lua-maxminddb
#SSRP
svn co https://github.com/fw876/helloworld/trunk/luci-app-ssr-plus package/lean/luci-app-ssr-plus
#SSRP依赖
rm -rf ./feeds/packages/net/kcptun
rm -rf ./feeds/packages/net/shadowsocks-libev
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/shadowsocksr-libev package/lean/shadowsocksr-libev
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/pdnsd-alt package/lean/pdnsd
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/v2ray package/lean/v2ray
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/kcptun package/lean/kcptun
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/v2ray-plugin package/lean/v2ray-plugin
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/srelay package/lean/srelay
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/microsocks package/lean/microsocks
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/dns2socks package/lean/dns2socks
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/redsocks2 package/lean/redsocks2
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/proxychains-ng package/lean/proxychains-ng
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/ipt2socks package/lean/ipt2socks
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/simple-obfs package/lean/simple-obfs
svn co https://github.com/coolsnowwolf/packages/trunk/net/shadowsocks-libev package/lean/shadowsocks-libev
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/trojan package/lean/trojan
svn co https://github.com/project-openwrt/openwrt/trunk/package/lean/tcpping package/lean/tcpping
svn co https://github.com/fw876/helloworld/trunk/naiveproxy package/lean/naiveproxy
#PASSWALL
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/luci-app-passwall package/new/luci-app-passwall
cp -f ../PATCH/new/script/move_2_services.sh ./package/new/luci-app-passwall/move_2_services.sh
pushd package/new/luci-app-passwall
bash move_2_services.sh
popd
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/tcping package/new/tcping
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/trojan-go package/new/trojan-go
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/brook package/new/brook
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/trojan-plus package/new/trojan-plus
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/ssocks package/new/ssocks
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/xray package/new/xray
#luci-app-cpulimit
cp -rf ../PATCH/duplicate/luci-app-cpulimit ./package/lean/luci-app-cpulimit
svn co https://github.com/project-openwrt/openwrt/branches/master/package/ntlf9t/cpulimit package/lean/cpulimit
#订阅转换
svn co https://github.com/project-openwrt/openwrt/branches/openwrt-19.07/package/ctcgfw/subconverter package/new/subconverter
svn co https://github.com/project-openwrt/openwrt/branches/openwrt-19.07/package/ctcgfw/jpcre2 package/new/jpcre2
svn co https://github.com/project-openwrt/openwrt/branches/openwrt-19.07/package/ctcgfw/rapidjson package/new/rapidjson
svn co https://github.com/project-openwrt/openwrt/branches/openwrt-19.07/package/ctcgfw/duktape package/new/duktape
#清理内存
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-ramfree package/lean/luci-app-ramfree
#打印机
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-usb-printer package/lean/luci-app-usb-printer
#流量监视
git clone -b master --single-branch https://github.com/brvphoenix/wrtbwmon package/new/wrtbwmon
git clone -b master --single-branch https://github.com/brvphoenix/luci-app-wrtbwmon package/new/luci-app-wrtbwmon
#流量监管
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-netdata package/lean/luci-app-netdata
#OpenClash
git clone -b master --single-branch https://github.com/vernesong/OpenClash package/new/luci-app-openclash
#SeverChan
git clone -b master --single-branch https://github.com/tty228/luci-app-serverchan package/new/luci-app-serverchan
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/network/utils/iputils package/network/utils/iputils
#SmartDNS
cp -rf ../packages-lienol/net/smartdns ./package/new/smartdns
cp -rf ../luci-lienol/applications/luci-app-smartdns ./package/new/luci-app-smartdns
sed -i 's,include ../..,include $(TOPDIR)/feeds/luci,g' ./package/new/luci-app-smartdns/Makefile
#上网APP过滤
git clone -b master --single-branch https://github.com/destan19/OpenAppFilter package/new/OpenAppFilter
#Docker
svn co https://github.com/lisaac/luci-app-dockerman/trunk/applications/luci-app-dockerman package/luci-app-dockerman
svn co https://github.com/lisaac/luci-lib-docker/trunk/collections/luci-lib-docker package/luci-lib-docker
svn co https://github.com/openwrt/packages/trunk/utils/docker-ce feeds/packages/utils/docker-ce
sed -i '/runc.installer/d' ./feeds/packages/utils/docker-ce/Makefile
ln -sf ../../../feeds/packages/utils/docker-ce ./package/feeds/packages/docker-ce
svn co https://github.com/openwrt/packages/trunk/utils/cgroupfs-mount feeds/packages/utils/cgroupfs-mount
ln -sf ../../../feeds/packages/utils/cgroupfs-mount ./package/feeds/packages/cgroupfs-mount
svn co https://github.com/openwrt/packages/trunk/utils/containerd feeds/packages/utils/containerd
ln -sf ../../../feeds/packages/utils/containerd ./package/feeds/packages/containerd
svn co https://github.com/openwrt/packages/trunk/utils/libnetwork feeds/packages/utils/libnetwork
ln -sf ../../../feeds/packages/utils/libnetwork ./package/feeds/packages/libnetwork
svn co https://github.com/openwrt/packages/trunk/utils/tini feeds/packages/utils/tini
ln -sf ../../../feeds/packages/utils/tini ./package/feeds/packages/tini
svn co https://github.com/openwrt/packages/trunk/utils/runc feeds/packages/utils/runc
ln -sf ../../../feeds/packages/utils/runc ./package/feeds/packages/runc
svn co https://github.com/openwrt/packages/trunk/utils/yq feeds/packages/utils/yq
ln -sf ../../../feeds/packages/utils/yq ./package/feeds/packages/yq
rm -rf ./feeds/packages/utils/lvm2
svn co https://github.com/openwrt/packages/trunk/utils/lvm2 feeds/packages/utils/lvm2
#补全部分依赖（实际上并不会用到
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/libs/libnetfilter-log package/libs/libnetfilter-log
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/libs/libnetfilter-queue package/libs/libnetfilter-queue
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/libs/libnetfilter-cttimeout package/libs/libnetfilter-cttimeout
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/libs/libnetfilter-cthelper package/libs/libnetfilter-cthelper
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/utils/fuse package/utils/fuse
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/network/services/samba36 package/network/services/samba36
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/libs/libconfig package/libs/libconfig
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/libs/libusb-compat package/libs/libusb-compat
svn co https://github.com/openwrt/packages/trunk/libs/nghttp2 feeds/packages/libs/nghttp2
ln -sf ../../../feeds/packages/libs/nghttp2 ./package/feeds/packages/nghttp2
svn co https://github.com/openwrt/packages/trunk/libs/libcap-ng feeds/packages/libs/libcap-ng
ln -sf ../../../feeds/packages/libs/libcap-ng ./package/feeds/packages/libcap-ng
rm -rf ./feeds/packages/utils/collectd
svn co https://github.com/openwrt/packages/trunk/utils/collectd feeds/packages/utils/collectd
#IPSEC
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-ipsec-vpnd package/lean/luci-app-ipsec-vpnd
#Zerotier
svn co https://github.com/project-openwrt/openwrt/branches/master/package/lean/luci-app-zerotier package/lean/luci-app-zerotier
cp -f ../PATCH/new/script/move_2_services.sh ./package/lean/luci-app-zerotier/move_2_services.sh
pushd package/lean/luci-app-zerotier
bash move_2_services.sh
popd
rm -rf ./feeds/packages/net/zerotier/files/etc/init.d/zerotier
#UPNP（回滚以解决某些沙雕设备的沙雕问题
rm -rf ./feeds/packages/net/miniupnpd
svn co https://github.com/coolsnowwolf/packages/trunk/net/miniupnpd feeds/packages/net/miniupnpd
#KMS
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-vlmcsd package/lean/luci-app-vlmcsd
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/vlmcsd package/lean/vlmcsd
#frp
rm -f ./feeds/luci/applications/luci-app-frps
rm -f ./feeds/luci/applications/luci-app-frpc
rm -rf ./feeds/packages/net/frp
rm -f ./package/feeds/packages/frp
git clone https://github.com/lwz322/luci-app-frps.git package/lean/luci-app-frps
git clone https://github.com/kuoruan/luci-app-frpc.git package/lean/luci-app-frpc
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/frp package/feeds/packages/frp
#花生壳
svn co https://github.com/teasiu/dragino2/trunk/package/teasiu/luci-app-phtunnel package/new/luci-app-phtunnel
svn co https://github.com/teasiu/dragino2/trunk/package/teasiu/luci-app-oray package/new/luci-app-oray
svn co https://github.com/teasiu/dragino2/trunk/package/teasiu/phtunnel package/new/phtunnel
#翻译及部分功能优化
cp -rf ../PATCH/duplicate/addition-trans-zh-master ./package/lean/lean-translate

##R2S相关
#crypto
echo '
CONFIG_ARM64_CRYPTO=y
CONFIG_CRYPTO_AES_ARM64=y
CONFIG_CRYPTO_AES_ARM64_BS=y
CONFIG_CRYPTO_AES_ARM64_CE=y
CONFIG_CRYPTO_AES_ARM64_CE_BLK=y
CONFIG_CRYPTO_AES_ARM64_CE_CCM=y
CONFIG_CRYPTO_AES_ARM64_NEON_BLK=y
CONFIG_CRYPTO_CHACHA20=y
CONFIG_CRYPTO_CHACHA20_NEON=y
CONFIG_CRYPTO_CRYPTD=y
CONFIG_CRYPTO_GF128MUL=y
CONFIG_CRYPTO_GHASH_ARM64_CE=y
CONFIG_CRYPTO_SHA1=y
CONFIG_CRYPTO_SHA1_ARM64_CE=y
CONFIG_CRYPTO_SHA256_ARM64=y
CONFIG_CRYPTO_SHA2_ARM64_CE=y
# CONFIG_CRYPTO_SHA3_ARM64 is not set
CONFIG_CRYPTO_SHA512_ARM64=y
# CONFIG_CRYPTO_SHA512_ARM64_CE is not set
CONFIG_CRYPTO_SIMD=y
# CONFIG_CRYPTO_SM3_ARM64_CE is not set
# CONFIG_CRYPTO_SM4_ARM64_CE is not set
' >> ./target/linux/rockchip/armv8/config-5.4
#let trojan prefer chacha20(vssr,passwall,ssrp
patch -p1 < ../PATCH/new/main/chacha.patch

##最后的收尾工作
#Lets Fuck
mkdir package/base-files/files/usr/bin
cp -f ../PATCH/new/script/fuck package/base-files/files/usr/bin/fuck
cp -f ../PATCH/new/script/chinadnslist package/base-files/files/usr/bin/chinadnslist
#最大连接
sed -i 's/16384/65536/g' package/kernel/linux/files/sysctl-nf-conntrack.conf
#删除已有配置
rm -rf .config
#预配置一些插件
cp -rf ../PATCH/files ./files
#授予权限
chmod -R 755 ./

exit 0
