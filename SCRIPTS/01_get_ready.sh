#!/bin/bash
git clone -b master https://git.openwrt.org/openwrt/openwrt.git openwrt
git clone -b dev-19.07 --single-branch https://github.com/Lienol/openwrt openwrt-lienol
exit 0
