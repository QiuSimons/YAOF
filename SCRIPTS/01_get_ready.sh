#!/bin/bash
git clone -b master https://git.openwrt.org/openwrt/openwrt.git openwrt
git clone https://github.com/QiuSimons/openwrt-lienol.git openwrt-lienol
git clone https://github.com/QiuSimons/packages-lienol.git packages-lienol
git clone https://github.com/QiuSimons/luci-lienol.git luci-lienol
git clone -b linksys-ea6350v3-mastertrack https://github.com/QiuSimons/openwrt-NoTengoBattery.git NoTengoBattery
exit 0
