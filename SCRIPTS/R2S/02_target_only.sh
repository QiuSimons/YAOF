#!/bin/bash
clear

# 使用专属优化
sed -i 's,-mcpu=generic,-march=armv8-a+crypto+crc -mabi=lp64,g' include/target.mk
cp -f ../PATCH/mbedtls/100-Implements-AES-and-GCM-with-ARMv8-Crypto-Extensions.patch ./package/libs/mbedtls/patches/100-Implements-AES-and-GCM-with-ARMv8-Crypto-Extensions.patch

# R2S_TL
rm -rf ./target/linux/rockchip
svn co https://github.com/immortalwrt/immortalwrt/branches/master/target/linux/rockchip target/linux/rockchip
rm -rf ./package/boot/uboot-rockchip
svn co https://github.com/immortalwrt/immortalwrt/branches/master/package/boot/uboot-rockchip package/boot/uboot-rockchip
svn co https://github.com/immortalwrt/immortalwrt/branches/master/package/boot/arm-trusted-firmware-rk3328 package/boot/arm-trusted-firmware-rk3328

#增加风扇调速（被动散热不香么？
wget -P target/linux/rockchip/armv8/base-files/etc/init.d/ https://github.com/friendlyarm/friendlywrt/raw/master-v19.07.1/target/linux/rockchip-rk3328/base-files/etc/init.d/fa-rk3328-pwmfan
wget -P target/linux/rockchip/armv8/base-files/usr/bin/ https://github.com/friendlyarm/friendlywrt/raw/master-v19.07.1/target/linux/rockchip-rk3328/base-files/usr/bin/start-rk3328-pwm-fan.sh

# 配置 IRQ 并默认关闭 eth0 offloading rx/rx
sed -i '/set_interface_core 4 "eth1"/a\set_interface_core 8 "ff160000" "ff160000.i2c"' target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/40-net-smp-affinity
sed -i '/set_interface_core 4 "eth1"/a\set_interface_core 1 "ff150000" "ff150000.i2c"' target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/40-net-smp-affinity
sed -i '/;;/i\ethtool -K eth0 rx off tx off && logger -t disable-offloading "disabed rk3328 ethernet tcp/udp offloading tx/rx"' target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/40-net-smp-affinity

# 交换 LAN/WAN 口
sed -i 's,"eth1" "eth0","eth0" "eth1",g' target/linux/rockchip/armv8/base-files/etc/board.d/02_network
sed -i "s,'eth1' 'eth0','eth0' 'eth1',g" target/linux/rockchip/armv8/base-files/etc/board.d/02_network

# 添加 R2S GPU 驱动
rm -rf ./package/kernel/linux/modules/video.mk
wget -P package/kernel/linux/modules/ https://github.com/immortalwrt/immortalwrt/raw/master/package/kernel/linux/modules/video.mk

#Vermagic
latest_version="$(curl -s https://github.com/openwrt/openwrt/releases |grep -Eo "v[0-9\.]+\-*r*c*[0-9]*.tar.gz" |sed -n '/21/p' |sed -n 1p |sed 's/v//g' |sed 's/.tar.gz//g')"
wget https://downloads.openwrt.org/releases/${latest_version}/targets/rockchip/armv8/packages/Packages.gz
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk

# 内核加解密组件
echo '
' >> ./target/linux/rockchip/armv8/config-5.4

# MPTCP
#echo '
#CONFIG_MPTCP=y
#CONFIG_MPTCP_PM_ADVANCED=y
#CONFIG_MPTCP_FULLMESH=y
#CONFIG_DEFAULT_FULLMESH=y
#CONFIG_DEFAULT_MPTCP_PM="fullmesh"
#' >> ./target/linux/rockchip/armv8/config-5.4

# 预配置一些插件
cp -rf ../PATCH/files ./files

chmod -R 755 ./
find ./ -name *.orig | xargs rm -f
find ./ -name *.rej | xargs rm -f

#exit 0
