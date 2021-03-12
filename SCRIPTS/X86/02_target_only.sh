#!/bin/bash
#翻译及部分功能优化
cp -rf ../PATCH/duplicate/addition-trans-zh ./package/lean/lean-translate
sed -i '/openssl/d' ./package/lean/lean-translate/files/zzz-default-settings
sed -i '/banirq/d' ./package/lean/lean-translate/files/zzz-default-settings
sed -i '/rngd/d' ./package/lean/lean-translate/files/zzz-default-settings
sed -i '/system.led/d' ./package/lean/lean-translate/files/zzz-default-settings
sed -i '/network.wan/d' ./package/lean/lean-translate/files/zzz-default-settings
sed -i '/network.lan/d' ./package/lean/lean-translate/files/zzz-default-settings

<<'COMMENT'
#Vermagic
latest_version="$(curl -s https://github.com/openwrt/openwrt/releases |grep -Eo "v[0-9\.]+\-*r*c*[0-9]*.tar.gz" |sed -n '/21/p' |sed -n 1p |sed 's/v//g' |sed 's/.tar.gz//g')"
wget https://downloads.openwrt.org/releases/${latest_version}/targets/x86/64/packages/Packages.gz
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
COMMENT

#Vermagic 2102 SNAPSHOT ONLY
wget https://downloads.openwrt.org/releases/21.02-SNAPSHOT/targets/x86/64/packages/Packages.gz
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk

#预配置一些插件
cp -rf ../PATCH/X86/files ./files


exit 0
