#!/bin/bash
git clone https://git.openwrt.org/openwrt/openwrt.git
cd openwrt
patch -p1 < ../PATCH/rockchip-add-support-for-rk3328-radxa-rock-pi-e.patch
patch -p1 < ../PATCH/rockchip-add-support-for-FriendlyARM-NanoPi-R2S.patch
cd ..
exit 0
