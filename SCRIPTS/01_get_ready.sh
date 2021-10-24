#!/bin/bash

latest_release="$(curl -s https://api.github.com/repos/openwrt/openwrt/tags | grep -Eo "v21.02.+[0-9\.]" | head -n 1)"
wget -qO openwrt_release.tar.gz https://github.com/openwrt/openwrt/archive/refs/tags/${latest_release}.tar.gz && mkdir openwrt_release && tar -zxvf openwrt_release.tar.gz -C openwrt_release --strip-components 1 && rm openwrt_release.tar.gz
git clone --single-branch -b openwrt-21.02 https://github.com/openwrt/openwrt openwrt
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