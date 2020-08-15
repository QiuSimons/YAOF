#!/bin/bash
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
git clone https://github.com/Lienol/openwrt.git openwrt-lienol
exit 0
