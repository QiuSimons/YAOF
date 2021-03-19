#!/bin/bash

# 使用 O2 级别的优化
sed -i 's/O3/O2/g' include/target.mk

# 翻译及部分功能优化
cp -rf ../PATCH/duplicate/addition-trans-zh ./package/lean/lean-translate
echo "
exit 0

" >> ./package/lean/lean-translate/files/zzz-default-settings

# 在 X86 架构下移除 Shadowsocks-rust
sed -i '/Rust:/d' package/lean/luci-app-ssr-plus/Makefile
sed -i '/Rust:/d' package/new/luci-app-passwall/Makefile
sed -i '/Rust:/d' package/lean/luci-app-vssr/Makefile

<<'COMMENT'
#Vermagic
latest_version="$(curl -s https://github.com/openwrt/openwrt/releases |grep -Eo "v[0-9\.]+\-*r*c*[0-9]*.tar.gz" |sed -n '/21/p' |sed -n 1p |sed 's/v//g' |sed 's/.tar.gz//g')"
wget https://downloads.openwrt.org/releases/${latest_version}/targets/x86/64/packages/Packages.gz
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
COMMENT

# 对齐内核 Vermagic
wget https://downloads.openwrt.org/releases/21.02-SNAPSHOT/targets/x86/64/packages/Packages.gz
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk

# 预配置一些插件
cp -rf ../PATCH/X86/files ./files

exit 0
