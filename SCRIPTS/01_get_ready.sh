#!/bin/bash
<<'COMMENT'
latest_release="$(curl -s https://github.com/openwrt/openwrt/releases |grep -Eo "v[0-9\.]+\-*r*c*[0-9]*.tar.gz" |sed -n '/21/p' |sed -n 1p)"
curl -LO "https://github.com/openwrt/openwrt/archive/${latest_release}"
mkdir openwrt_back
shopt -s extglob 
tar zxvf ${latest_release}  --strip-components 1 -C ./openwrt_back
rm -f ${latest_release}
git clone --single-branch -b openwrt-21.02 https://github.com/openwrt/openwrt openwrt_new
rm -f ./openwrt_new/include/version.mk
rm -f ./openwrt_new/include/kernel-version.mk
rm -f ./openwrt_new/package/base-files/image-config.in
rm -rf ./openwrt_new/target/linux/*
cp -f ./openwrt_back/include/version.mk ./openwrt_new/include/version.mk
cp -f ./openwrt_back/include/kernel-version.mk ./openwrt_new/include/kernel-version.mk
cp -f ./openwrt_back/package/base-files/image-config.in ./openwrt_new/package/base-files/image-config.in
cp -rf ./openwrt_back/target/linux/* ./openwrt_new/target/linux/
mkdir openwrt
cp -rf ./openwrt_new/* ./openwrt/
COMMENT
git clone --single-branch -b openwrt-21.02 https://github.com/openwrt/openwrt openwrt
git clone -b main --depth 1 https://github.com/Lienol/openwrt.git openwrt-lienol
git clone -b main --depth 1 https://github.com/Lienol/openwrt-packages packages-lienol
git clone -b main --depth 1 https://github.com/Lienol/openwrt-luci luci-lienol
git clone -b linksys-ea6350v3-mastertrack --depth 1 https://github.com/NoTengoBattery/openwrt NoTengoBattery
exit 0
