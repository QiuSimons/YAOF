#!/bin/bash
git clone -b master --depth 1 https://git.openwrt.org/openwrt/openwrt.git openwrt
git clone -b main --depth 1 https://github.com/Lienol/openwrt.git openwrt-lienol
git clone -b main --depth 1 https://github.com/Lienol/openwrt-packages packages-lienol
git clone -b main --depth 1 https://github.com/Lienol/openwrt-luci luci-lienol
git clone -b linksys-ea6350v3-mastertrack --depth 1 https://github.com/NoTengoBattery/openwrt NoTengoBattery
exit 0
