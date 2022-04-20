#!/bin/bash

latest_release="$(curl -s https://github.com/openwrt/openwrt/tags | grep -Eo "v[0-9\.]+\-*r*c*[0-9]*.tar.gz" | sed -n '/[2-9][0-9]/p' | sed -n 1p | sed 's/.tar.gz//g')"
git clone --single-branch -b ${latest_release} https://github.com/openwrt/openwrt openwrt_release
git clone --single-branch -b openwrt-22.03 https://github.com/openwrt/openwrt openwrt
rm -f ./openwrt/include/version.mk
rm -f ./openwrt/include/kernel.mk
rm -f ./openwrt/include/kernel-version.mk
rm -f ./openwrt/include/toolchain-build.mk
rm -f ./openwrt/include/kernel-defaults.mk
rm -f ./openwrt/package/base-files/image-config.in
rm -rf ./openwrt/target/linux/*
cp -f ./openwrt_release/include/version.mk ./openwrt/include/version.mk
cp -f ./openwrt_release/include/kernel.mk ./openwrt/include/kernel.mk
cp -f ./openwrt_release/include/kernel-version.mk ./openwrt/include/kernel-version.mk
cp -f ./openwrt_release/include/toolchain-build.mk ./openwrt/include/toolchain-build.mk
cp -f ./openwrt_release/include/kernel-defaults.mk ./openwrt/include/kernel-defaults.mk
cp -f ./openwrt_release/package/base-files/image-config.in ./openwrt/package/base-files/image-config.in
cp -f ./openwrt_release/version ./openwrt/version
cp -f ./openwrt_release/version.date ./openwrt/version.date
cp -rf ./openwrt_release/target/linux/* ./openwrt/target/linux/

# 获取源代码
#git clone -b main --depth 1 https://github.com/Lienol/openwrt.git openwrt-lienol
#git clone -b main --depth 1 https://github.com/Lienol/openwrt-packages packages-lienol
#git clone -b main --depth 1 https://github.com/Lienol/openwrt-luci luci-lienol
#git clone -b linksys-ea6350v3-mastertrack --depth 1 https://github.com/NoTengoBattery/openwrt NoTengoBattery

exit 0
