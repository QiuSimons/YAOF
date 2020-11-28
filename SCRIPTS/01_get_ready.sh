#!/bin/bash
git clone -b master https://git.openwrt.org/openwrt/openwrt.git openwrt
git clone https://github.com/Lienol/openwrt.git openwrt-lienol
git clone https://github.com/Lienol/openwrt-packages packages-lienol
git clone https://github.com/Lienol/openwrt-luci luci-lienol
git clone -b linksys-ea6350v3-mastertrack https://github.com/NoTengoBattery/openwrt NoTengoBattery
exit 0
