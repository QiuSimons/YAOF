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
cd openwrt
git revert 0232bf6 42675aa ba9b8da 00e8725 1a69f50
cd ..
git clone https://github.com/Lienol/openwrt.git openwrt-lienol
git clone https://github.com/Lienol/openwrt-packages packages-lienol
git clone https://github.com/Lienol/openwrt-luci luci-lienol
git clone -b linksys-ea6350v3-mastertrack https://github.com/NoTengoBattery/openwrt NoTengoBattery
exit 0
