#!/bin/bash
clear

#R4S_TL
rm -rf ./target/linux/rockchip
svn co https://github.com/immortalwrt/immortalwrt/branches/master/target/linux/rockchip target/linux/rockchip
rm -rf ./package/boot/uboot-rockchip
svn co https://github.com/immortalwrt/immortalwrt/branches/master/package/boot/uboot-rockchip package/boot/uboot-rockchip

#overclock 1.8/2.2
rm -rf ./target/linux/rockchip/patches-5.4/992-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch
cp -f ../PATCH/new/main/991-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch ./target/linux/rockchip/patches-5.4/991-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch
cp -f ../PATCH/new/main/213-RK3399-set-critical-CPU-temperature-for-thermal-throttling.patch ./target/linux/rockchip/patches-5.4/213-RK3399-set-critical-CPU-temperature-for-thermal-throttling.patch

#DMC
cp -f ../PATCH/new/main/803-ARM64-dts-rk3399-add-dmc-and-dfi-node.patch.patch ./target/linux/rockchip/patches-5.4/803-ARM64-dts-rk3399-add-dmc-and-dfi-node.patch.patch

#使用特定的优化
sed -i 's,-mcpu=generic,-march=armv8-a+crypto+crc -mcpu=cortex-a72.cortex-a53+crypto+crc -mtune=cortex-a72.cortex-a53,g' include/target.mk

#Experimental
sed -i '/CRYPTO_DEV_ROCKCHIP/d' ./target/linux/rockchip/armv8/config-5.4
sed -i '/HW_RANDOM_ROCKCHIP/d' ./target/linux/rockchip/armv8/config-5.4
echo '
CONFIG_CRYPTO_DEV_ROCKCHIP=y
CONFIG_HW_RANDOM_ROCKCHIP=y
' >> ./target/linux/rockchip/armv8/config-5.4

#Experimental
sed -i '/PM_DEVFREQ/d' ./target/linux/rockchip/armv8/config-5.4
sed -i '/DEVFREQ_GOV_SIMPLE_ONDEMAND/d' ./target/linux/rockchip/armv8/config-5.4
sed -i '/DEVFREQ_GOV_PERFORMANCE/d' ./target/linux/rockchip/armv8/config-5.4
sed -i '/DEVFREQ_GOV_POWERSAVE/d' ./target/linux/rockchip/armv8/config-5.4
sed -i '/DEVFREQ_GOV_USERSPACE/d' ./target/linux/rockchip/armv8/config-5.4
sed -i '/DEVFREQ_GOV_PASSIVE/d' ./target/linux/rockchip/armv8/config-5.4
sed -i '/ARM_RK3328_DMC_DEVFREQ/d' ./target/linux/rockchip/armv8/config-5.4
sed -i '/ARM_RK3399_DMC_DEVFREQ/d' ./target/linux/rockchip/armv8/config-5.4
sed -i '/PM_DEVFREQ_EVENT/d' ./target/linux/rockchip/armv8/config-5.4
sed -i '/DEVFREQ_EVENT_ROCKCHIP_DFI/d' ./target/linux/rockchip/armv8/config-5.4
echo '
CONFIG_PM_DEVFREQ=y
CONFIG_DEVFREQ_GOV_SIMPLE_ONDEMAND=y
CONFIG_DEVFREQ_GOV_PERFORMANCE=m
CONFIG_DEVFREQ_GOV_POWERSAVE=m
CONFIG_DEVFREQ_GOV_USERSPACE=m
CONFIG_DEVFREQ_GOV_PASSIVE=m
CONFIG_ARM_RK3328_DMC_DEVFREQ=y
CONFIG_ARM_RK3399_DMC_DEVFREQ=y
CONFIG_PM_DEVFREQ_EVENT=y
CONFIG_DEVFREQ_EVENT_ROCKCHIP_DFI=y
CONFIG_EXTCON=y
' >> ./target/linux/rockchip/armv8/config-5.4

#IRQ
sed -i '/set_interface_core 20 "eth1"/a\set_interface_core 8 "ff3c0000" "ff3c0000.i2c"' target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/40-net-smp-affinity
sed -i '/set_interface_core 20 "eth1"/a\ethtool -C eth0 rx-usecs 1000 rx-frames 25 tx-usecs 100 tx-frames 25' target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/40-net-smp-affinity

#翻译及部分功能优化
cp -rf ../PATCH/duplicate/addition-trans-zh ./package/lean/lean-translate

<<'COMMENT'
#Vermagic
latest_version="$(curl -s https://github.com/openwrt/openwrt/releases |grep -Eo "v[0-9\.]+\-*r*c*[0-9]*.tar.gz" |sed -n '/21/p' |sed -n 1p |sed 's/v//g' |sed 's/.tar.gz//g')"
wget https://downloads.openwrt.org/releases/${latest_version}/targets/rockchip/armv8/packages/Packages.gz
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
COMMENT

#Vermagic 2102 SNAPSHOT ONLY
wget https://downloads.openwrt.org/releases/21.02-SNAPSHOT/targets/rockchip/armv8/packages/Packages.gz
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk

#预配置一些插件
cp -rf ../PATCH/R4S/files ./files

exit 0
