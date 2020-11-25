#!/bin/bash
notExce(){ 
git clone -b master https://git.openwrt.org/openwrt/staging/blocktrron.git openwrt
cd openwrt
git config --local user.email "action@github.com" && git config --local user.name "GitHub Action"
git remote add upstream https://github.com/openwrt/openwrt.git && git fetch upstream
git rebase upstream/master
git rebase --skip
git rebase --skip
git rebase --skip
git rebase --skip
git rebase --skip
cd ..
}
git clone -b master https://git.openwrt.org/openwrt/openwrt.git openwrt
git clone https://github.com/QiuSimons/openwrt-lienol.git openwrt-lienol
git clone https://github.com/QiuSimons/packages-lienol.git packages-lienol
git clone https://github.com/QiuSimons/luci-lienol.git luci-lienol
git clone -b linksys-ea6350v3-mastertrack https://github.com/QiuSimons/openwrt-NoTengoBattery.git NoTengoBattery
exit 0
