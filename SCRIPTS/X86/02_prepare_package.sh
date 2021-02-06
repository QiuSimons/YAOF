#!/bin/bash
#Kernel
clear
#使用O2级别的优化
sed -i 's/Os/O2/g' include/target.mk
sed -i 's/O2/O2/g' ./rules.mk
#更新feed
./scripts/feeds update -a && ./scripts/feeds install -a
#irqbalance
sed -i 's/0/1/g' feeds/packages/utils/irqbalance/files/irqbalance.config

##必要的patch
#luci network
patch -p1 < ../PATCH/new/main/luci_network-add-packet-steering.patch
#patch jsonc
patch -p1 < ../PATCH/new/package/use_json_object_new_int64.patch
#patch dnsmasq
rm -rf ./package/network/services/dnsmasq
svn co https://github.com/openwrt/openwrt/trunk/package/network/services/dnsmasq package/network/services/dnsmasq
patch -p1 < ../PATCH/new/package/dnsmasq-add-filter-aaaa-option.patch
patch -p1 < ../PATCH/new/package/luci-add-filter-aaaa-option.patch
cp -f ../PATCH/new/package/900-add-filter-aaaa-option.patch ./package/network/services/dnsmasq/patches/900-add-filter-aaaa-option.patch
rm -rf ./package/base-files/files/etc/init.d/boot
wget -P package/base-files/files/etc/init.d https://github.com/project-openwrt/openwrt/raw/openwrt-18.06-k5.4/package/base-files/files/etc/init.d/boot
#（从这行开始接下来4个操作全是和fullcone相关的，不需要可以一并注释掉，但极不建议
# Patch Kernel 以解决fullcone冲突
wget -P target/linux/generic/hack-4.14/ https://github.com/coolsnowwolf/lede/raw/master/target/linux/generic/hack-4.14/952-net-conntrack-events-support-multiple-registrant.patch
wget -P target/linux/generic/hack-4.14/ https://github.com/coolsnowwolf/lede/raw/master/target/linux/generic/hack-4.14/202-reduce_module_size.patch
wget -P target/linux/x86/patches-4.14/ https://github.com/coolsnowwolf/lede/raw/master/target/linux/x86/patches-4.14/900-x86-Enable-fast-strings-on-Intel-if-BIOS-hasn-t-already.patch
#Patch FireWall 以增添fullcone功能 
mkdir package/network/config/firewall/patches
wget -P package/network/config/firewall/patches/ https://github.com/project-openwrt/openwrt/raw/master/package/network/config/firewall/patches/fullconenat.patch
# Patch LuCI 以增添fullcone开关
patch -p1 < ../PATCH/new/package/luci-app-firewall_add_fullcone.patch
#pushd feeds/luci
#wget -O- https://github.com/LGA1150/fullconenat-fw3-patch/raw/master/luci.patch | git apply
#popd
#FullCone 相关组件
cp -rf ../openwrt-lienol/package/network/fullconenat ./package/network/fullconenat
#（从这行开始接下来3个操作全是和SFE相关的，不需要可以一并注释掉，但极不建议
# Patch Kernel 以支援SFE
wget -P target/linux/generic/hack-4.14/ https://github.com/coolsnowwolf/lede/raw/master/target/linux/generic/hack-4.14/953-net-patch-linux-kernel-to-support-shortcut-fe.patch
# Patch LuCI 以增添SFE开关
patch -p1 < ../PATCH/new/package/luci-app-firewall_add_sfe_switch.patch
# SFE 相关组件
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/shortcut-fe package/lean/shortcut-fe
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/fast-classifier package/lean/fast-classifier
cp -f ../PATCH/duplicate/shortcut-fe ./package/base-files/files/etc/init.d
# BBR_Patch（2.0
wget -P target/linux/generic/pending-4.14/ https://github.com/project-openwrt/openwrt/raw/openwrt-18.06/target/linux/generic/pending-4.14/607-tcp_bbr-adapt-cwnd-based-on-ack-aggregation-estimation.patch

##获取额外package
#（不用注释这里的任何东西，这不会对提升action的执行速度起到多大的帮助
#（不需要的包直接修改seed就好
#luci-app-compressed-memory
wget -O- https://patch-diff.githubusercontent.com/raw/openwrt/openwrt/pull/2840.patch | patch -p1
mkdir ./package/new
cp -rf ../NoTengoBattery/feeds/luci/applications/luci-app-compressed-memory ./package/new/luci-app-compressed-memory
sed -i 's,include ../..,include $(TOPDIR)/feeds/luci,g' ./package/new/luci-app-compressed-memory/Makefile
rm -rf ./package/system/compressed-memory
cp -rf ../NoTengoBattery/package/system/compressed-memory ./package/system/compressed-memory
#更换cryptodev-linux
rm -rf ./package/kernel/cryptodev-linux
svn co https://github.com/project-openwrt/openwrt/branches/master/package/kernel/cryptodev-linux package/kernel/cryptodev-linux
#降级openssl（解决性能问题
rm -rf ./package/libs/openssl
svn co -r 90110 https://github.com/openwrt/openwrt/trunk/package/libs/openssl package/libs/openssl
#更换htop
rm -rf ./feeds/packages/admin/htop
svn co https://github.com/openwrt/packages/trunk/admin/htop feeds/packages/admin/htop
#更换lzo
svn co https://github.com/openwrt/packages/trunk/libs/lzo feeds/packages/libs/lzo
ln -sf ../../../feeds/packages/libs/lzo ./package/feeds/packages/lzo
#更换curl
rm -rf ./package/network/utils/curl
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/network/utils/curl package/network/utils/curl
#更换Node版本
rm -rf ./feeds/packages/lang/node
svn co https://github.com/nxhack/openwrt-node-packages/trunk/node feeds/packages/lang/node
rm -rf ./feeds/packages/lang/node-arduino-firmata
svn co https://github.com/nxhack/openwrt-node-packages/trunk/node-arduino-firmata feeds/packages/lang/node-arduino-firmata
rm -rf ./feeds/packages/lang/node-cylon
svn co https://github.com/nxhack/openwrt-node-packages/trunk/node-cylon feeds/packages/lang/node-cylon
rm -rf ./feeds/packages/lang/node-hid
svn co https://github.com/nxhack/openwrt-node-packages/trunk/node-hid feeds/packages/lang/node-hid
rm -rf ./feeds/packages/lang/node-homebridge
svn co https://github.com/nxhack/openwrt-node-packages/trunk/node-homebridge feeds/packages/lang/node-homebridge
rm -rf ./feeds/packages/lang/node-serialport
svn co https://github.com/nxhack/openwrt-node-packages/trunk/node-serialport feeds/packages/lang/node-serialport
rm -rf ./feeds/packages/lang/node-serialport-bindings
svn co https://github.com/nxhack/openwrt-node-packages/trunk/node-serialport-bindings feeds/packages/lang/node-serialport-bindings
#更换libcap
rm -rf ./feeds/packages/libs/libcap/
svn co https://github.com/openwrt/packages/trunk/libs/libcap feeds/packages/libs/libcap
#更换GCC版本
rm -rf ./feeds/packages/devel/gcc
svn co https://github.com/openwrt/packages/trunk/devel/gcc feeds/packages/devel/gcc
#更换Golang版本
rm -rf ./feeds/packages/lang/golang
svn co https://github.com/openwrt/packages/trunk/lang/golang feeds/packages/lang/golang
#python
svn co https://github.com/openwrt/packages/trunk/lang/python/python-cached-property feeds/packages/lang/python/python-cached-property
ln -sf ../../../feeds/packages/lang/python/python-cached-property ./package/feeds/packages/python-cached-property
svn co https://github.com/openwrt/packages/trunk/lang/python/python-distro feeds/packages/lang/python/python-distro
ln -sf ../../../feeds/packages/lang/python/python-distro ./package/feeds/packages/python-distro
svn co https://github.com/openwrt/packages/trunk/lang/python/python-docopt feeds/packages/lang/python/python-docopt
ln -sf ../../../feeds/packages/lang/python/python-docopt ./package/feeds/packages/python-docopt
svn co https://github.com/openwrt/packages/trunk/lang/python/python-docker feeds/packages/lang/python/python-docker
ln -sf ../../../feeds/packages/lang/python/python-docker ./package/feeds/packages/python-docker
svn co https://github.com/openwrt/packages/trunk/lang/python/python-dockerpty feeds/packages/lang/python/python-dockerpty
ln -sf ../../../feeds/packages/lang/python/python-dockerpty ./package/feeds/packages/python-dockerpty
svn co https://github.com/openwrt/packages/trunk/lang/python/python-dotenv feeds/packages/lang/python/python-dotenv
ln -sf ../../../feeds/packages/lang/python/python-dotenv ./package/feeds/packages/python-dotenv
svn co https://github.com/openwrt/packages/trunk/lang/python/python-jsonschema feeds/packages/lang/python/python-jsonschema
ln -sf ../../../feeds/packages/lang/python/python-jsonschema ./package/feeds/packages/python-jsonschema
svn co https://github.com/openwrt/packages/trunk/lang/python/python-texttable feeds/packages/lang/python/python-texttable
ln -sf ../../../feeds/packages/lang/python/python-texttable ./package/feeds/packages/python-texttable
svn co https://github.com/openwrt/packages/trunk/lang/python/python-websocket-client feeds/packages/lang/python/python-websocket-client
ln -sf ../../../feeds/packages/lang/python/python-websocket-client ./package/feeds/packages/python-websocket-client
svn co https://github.com/openwrt/packages/trunk/lang/python/python-paramiko feeds/packages/lang/python/python-paramiko
ln -sf ../../../feeds/packages/lang/python/python-paramiko ./package/feeds/packages/python-paramiko
svn co https://github.com/openwrt/packages/trunk/lang/python/python-pynacl feeds/packages/lang/python/python-pynacl
ln -sf ../../../feeds/packages/lang/python/python-pynacl ./package/feeds/packages/python-pynacl
#beardropper
git clone --depth 1 https://github.com/NateLol/luci-app-beardropper.git package/luci-app-beardropper
sed -i 's/"luci.fs"/"luci.sys".net/g' package/luci-app-beardropper/luasrc/model/cbi/beardropper/setting.lua
sed -i '/firewall/d' package/luci-app-beardropper/root/etc/uci-defaults/luci-beardropper
#luci-app-freq
svn co https://github.com/project-openwrt/openwrt/branches/master/package/lean/luci-app-cpufreq package/lean/luci-app-cpufreq
#京东签到
git clone --depth 1 https://github.com/jerrykuku/node-request.git package/new/node-request
git clone --depth 1 https://github.com/jerrykuku/luci-app-jd-dailybonus.git package/new/luci-app-jd-dailybonus
#uu加速
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-uugamebooster package/lean/luci-app-uugamebooster
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/uugamebooster package/lean/uugamebooster
#arpbind
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-arpbind package/lean/luci-app-arpbind
#Adbyby
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-adbyby-plus package/lean/luci-app-adbyby-plus
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/adbyby package/lean/adbyby
#访问控制
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-accesscontrol package/lean/luci-app-accesscontrol
cp -rf ../PATCH/duplicate/luci-app-control-weburl ./package/new/luci-app-control-weburl
#AutoCore
svn co https://github.com/project-openwrt/openwrt/branches/master/package/lean/autocore package/lean/autocore
svn co https://github.com/project-openwrt/packages/trunk/utils/coremark feeds/packages/utils/coremark
ln -sf ../../../feeds/packages/utils/coremark ./package/feeds/packages/coremark
sed -i 's,default n,default y,g' feeds/packages/utils/coremark/Makefile
#迅雷快鸟
#svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-xlnetacc package/lean/luci-app-xlnetacc
git clone --depth 1 https://github.com/garypang13/luci-app-xlnetacc.git package/lean/luci-app-xlnetacc
#DDNS
rm -rf ./feeds/packages/net/ddns-scripts
rm -rf ./feeds/luci/applications/luci-app-ddns
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/ddns-scripts_aliyun package/lean/ddns-scripts_aliyun
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/ddns-scripts_dnspod package/lean/ddns-scripts_dnspod
svn co https://github.com/openwrt/packages/branches/openwrt-18.06/net/ddns-scripts feeds/packages/net/ddns-scripts
svn co https://github.com/openwrt/luci/branches/openwrt-18.06/applications/luci-app-ddns feeds/luci/applications/luci-app-ddns
#Pandownload
svn co https://github.com/project-openwrt/openwrt/branches/master/package/lean/pandownload-fake-server package/lean/pandownload-fake-server
#oled
git clone -b master --depth 1 https://github.com/NateLol/luci-app-oled.git package/new/luci-app-oled
#网易云解锁
git clone --depth 1 https://github.com/project-openwrt/luci-app-unblockneteasemusic.git package/new/UnblockNeteaseMusic
#定时重启
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-autoreboot package/lean/luci-app-autoreboot
#argon主题
git clone -b master --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/new/luci-theme-argon
git clone -b master --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/new/luci-app-argon-config
#edge主题
git clone -b master --depth 1 https://github.com/garypang13/luci-theme-edge.git package/new/luci-theme-edge
#moschinadns
svn co https://github.com/QiuSimons/openwrt-packages/branches/main/mos-chinadns package/new/mos-chinadns
svn co https://github.com/QiuSimons/openwrt-packages/branches/main/luci-app-moschinadns package/new/luci-app-moschinadns
#AdGuard
cp -rf ../openwrt-lienol/package/diy/luci-app-adguardhome ./package/new/luci-app-adguardhome
svn co https://github.com/openwrt/packages/trunk/net/adguardhome feeds/packages/net/adguardhome
ln -sf ../../../feeds/packages/net/adguardhome ./package/feeds/packages/adguardhome
sed -i '/init/d' feeds/packages/net/adguardhome/Makefile
svn co https://github.com/openwrt/packages/trunk/devel/packr feeds/packages/devel/packr
ln -sf ../../../feeds/packages/devel/packr ./package/feeds/packages/packr
#cp -rf ../openwrt-lienol/package/diy/adguardhome ./package/new/adguardhome
#svn co https://github.com/project-openwrt/openwrt/branches/openwrt-19.07/package/ntlf9t/AdGuardHome package/new/AdGuardHome
#ChinaDNS
git clone -b luci --depth 1 https://github.com/pexcn/openwrt-chinadns-ng.git package/new/luci-app-chinadns-ng
git clone -b master --depth 1 https://github.com/pexcn/openwrt-chinadns-ng.git package/new/chinadns-ng
#VSSR
git clone -b master --depth 1 https://github.com/jerrykuku/luci-app-vssr.git package/lean/luci-app-vssr
git clone -b master --depth 1 https://github.com/jerrykuku/lua-maxminddb.git package/lean/lua-maxminddb
sed -i 's,default n,default y,g' package/lean/luci-app-vssr/Makefile
sed -i '/V2ray:v2ray/d' package/lean/luci-app-vssr/Makefile
#SSRP
svn co https://github.com/fw876/helloworld/trunk/luci-app-ssr-plus package/lean/luci-app-ssr-plus
#svn co https://github.com/Mattraks/helloworld/branches/Preview/luci-app-ssr-plus package/lean/luci-app-ssr-plus
rm -rf ./package/lean/luci-app-ssr-plus/po/zh_Hans
pushd package/lean
#wget -qO - https://patch-diff.githubusercontent.com/raw/fw876/helloworld/pull/271.patch | patch -p1
popd
sed -i 's,default n,default y,g' package/lean/luci-app-ssr-plus/Makefile
sed -i 's,Xray:xray ,Xray:xray-core ,g' package/lean/luci-app-ssr-plus/Makefile
sed -i '/V2ray:v2ray/d' package/lean/luci-app-ssr-plus/Makefile
sed -i '/result.encrypt_method/a\result.fast_open = "1"' package/lean/luci-app-ssr-plus/root/usr/share/shadowsocksr/subscribe.lua
sed -i 's,ispip.clang.cn/all_cn.txt,cdn.jsdelivr.net/gh/QiuSimons/Chnroute/dist/chnroute/chnroute.txt,g' package/lean/luci-app-ssr-plus/root/etc/init.d/shadowsocksr
sed -i 's,YW5vbnltb3Vz/domain-list-community@release/gfwlist.txt,Loyalsoldier/v2ray-rules-dat@release/gfw.txt,g' package/lean/luci-app-ssr-plus/root/etc/init.d/shadowsocksr
#SSRP依赖
rm -rf ./feeds/packages/net/kcptun
rm -rf ./feeds/packages/net/shadowsocks-libev
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/shadowsocksr-libev package/lean/shadowsocksr-libev
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/pdnsd-alt package/lean/pdnsd
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/kcptun package/lean/kcptun
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/srelay package/lean/srelay
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/microsocks package/lean/microsocks
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/dns2socks package/lean/dns2socks
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/redsocks2 package/lean/redsocks2
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/proxychains-ng package/lean/proxychains-ng
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/ipt2socks package/lean/ipt2socks
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/simple-obfs package/lean/simple-obfs
svn co https://github.com/coolsnowwolf/packages/trunk/net/shadowsocks-libev package/lean/shadowsocks-libev
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/trojan package/lean/trojan
svn co https://github.com/project-openwrt/openwrt/branches/master/package/lean/tcpping package/lean/tcpping
svn co https://github.com/fw876/helloworld/trunk/naiveproxy package/lean/naiveproxy
svn co https://github.com/fw876/helloworld/trunk/ipt2socks-alt package/lean/ipt2socks-alt
#PASSWALL
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/luci-app-passwall package/new/luci-app-passwall
sed -i 's,default n,default y,g' package/new/luci-app-passwall/Makefile
sed -i '/V2ray:v2ray/d' package/new/luci-app-passwall/Makefile
cp -f ../PATCH/new/script/move_2_services.sh ./package/new/luci-app-passwall/move_2_services.sh
pushd package/new/luci-app-passwall
bash move_2_services.sh
popd
rm -rf ./feeds/packages/net/https-dns-proxy
svn co https://github.com/Lienol/openwrt-packages/trunk/net/https-dns-proxy feeds/packages/net/https-dns-proxy
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/tcping package/new/tcping
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/trojan-go package/new/trojan-go
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/brook package/new/brook
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/trojan-plus package/new/trojan-plus
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/ssocks package/new/ssocks
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/xray-core package/new/xray-core
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/v2ray package/new/v2ray
svn co https://github.com/xiaorouji/openwrt-passwall/trunk/v2ray-plugin package/new/v2ray-plugin
#luci-app-cpulimit
cp -rf ../PATCH/duplicate/luci-app-cpulimit ./package/lean/luci-app-cpulimit
svn co https://github.com/project-openwrt/openwrt/branches/master/package/ntlf9t/cpulimit package/lean/cpulimit
#订阅转换
svn co https://github.com/project-openwrt/openwrt/branches/openwrt-19.07/package/ctcgfw/subconverter package/new/subconverter
svn co https://github.com/project-openwrt/openwrt/branches/openwrt-19.07/package/ctcgfw/jpcre2 package/new/jpcre2
svn co https://github.com/project-openwrt/openwrt/branches/openwrt-19.07/package/ctcgfw/rapidjson package/new/rapidjson
svn co https://github.com/project-openwrt/openwrt/branches/openwrt-19.07/package/ctcgfw/duktape package/new/duktape
#清理内存
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-ramfree package/lean/luci-app-ramfree
#打印机
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-usb-printer package/lean/luci-app-usb-printer
#流量监视
git clone -b master --depth 1 https://github.com/brvphoenix/wrtbwmon.git package/new/wrtbwmon
git clone -b master --depth 1 https://github.com/brvphoenix/luci-app-wrtbwmon.git package/new/luci-app-wrtbwmon
#流量监管
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-netdata package/lean/luci-app-netdata
#OpenClash
git clone -b master --depth 1 https://github.com/vernesong/OpenClash.git package/new/luci-app-openclash
#SeverChan
git clone -b master --depth 1 https://github.com/tty228/luci-app-serverchan.git package/new/luci-app-serverchan
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/network/utils/iputils package/network/utils/iputils
#SmartDNS
#cp -rf ../packages-lienol/net/smartdns ./package/new/smartdns
mkdir package/new/smartdns
wget -P package/new/smartdns/ https://github.com/HiGarfield/lede-17.01.4-Mod/raw/master/package/extra/smartdns/Makefile
sed -i 's,files/etc/config,$(PKG_BUILD_DIR)/package/openwrt/files/etc/config,g' ./package/new/smartdns/Makefile
cp -rf ../luci-lienol/applications/luci-app-smartdns ./package/new/luci-app-smartdns
sed -i 's,include ../..,include $(TOPDIR)/feeds/luci,g' ./package/new/luci-app-smartdns/Makefile
#上网APP过滤
git clone -b master --depth 1 https://github.com/destan19/OpenAppFilter.git package/new/OpenAppFilter
#Docker
svn co https://github.com/lisaac/luci-app-dockerman/trunk/applications/luci-app-dockerman package/luci-app-dockerman
sed -i 's/+docker-ce/+docker \\\n\t+dockerd/g' ./package/luci-app-dockerman/Makefile
svn co https://github.com/lisaac/luci-lib-docker/trunk/collections/luci-lib-docker package/luci-lib-docker
svn co https://github.com/openwrt/packages/trunk/utils/docker-compose feeds/packages/utils/docker-compose
ln -sf ../../../feeds/packages/utils/docker-compose ./package/feeds/packages/docker-compose
svn co https://github.com/openwrt/packages/trunk/utils/docker feeds/packages/utils/docker
ln -sf ../../../feeds/packages/utils/docker ./package/feeds/packages/docker
svn co https://github.com/openwrt/packages/trunk/utils/dockerd feeds/packages/utils/dockerd
sed -i 's,default n,default y,g' feeds/packages/utils/dockerd/Config.in
ln -sf ../../../feeds/packages/utils/dockerd ./package/feeds/packages/dockerd
svn co https://github.com/openwrt/packages/trunk/utils/cgroupfs-mount feeds/packages/utils/cgroupfs-mount
ln -sf ../../../feeds/packages/utils/cgroupfs-mount ./package/feeds/packages/cgroupfs-mount
svn co https://github.com/openwrt/packages/trunk/utils/containerd feeds/packages/utils/containerd
ln -sf ../../../feeds/packages/utils/containerd ./package/feeds/packages/containerd
svn co https://github.com/openwrt/packages/trunk/utils/libnetwork feeds/packages/utils/libnetwork
ln -sf ../../../feeds/packages/utils/libnetwork ./package/feeds/packages/libnetwork
svn co https://github.com/openwrt/packages/trunk/utils/tini feeds/packages/utils/tini
ln -sf ../../../feeds/packages/utils/tini ./package/feeds/packages/tini
svn co https://github.com/openwrt/packages/trunk/utils/runc feeds/packages/utils/runc
ln -sf ../../../feeds/packages/utils/runc ./package/feeds/packages/runc
svn co https://github.com/openwrt/packages/trunk/utils/yq feeds/packages/utils/yq
ln -sf ../../../feeds/packages/utils/yq ./package/feeds/packages/yq
rm -rf ./feeds/packages/utils/lvm2
svn co https://github.com/openwrt/packages/trunk/utils/lvm2 feeds/packages/utils/lvm2
svn co https://github.com/openwrt/openwrt/trunk/package/libs/libselinux package/libs/libselinux
svn co https://github.com/openwrt/openwrt/trunk/package/libs/libsepol package/libs/libsepol
rm -rf ./feeds/packages/libs/pcre
svn co https://github.com/openwrt/openwrt/trunk/package/libs/pcre package/libs/pcre
#补全部分依赖（实际上并不会用到
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/libs/libnetfilter-log package/libs/libnetfilter-log
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/libs/libnetfilter-queue package/libs/libnetfilter-queue
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/libs/libnetfilter-cttimeout package/libs/libnetfilter-cttimeout
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/libs/libnetfilter-cthelper package/libs/libnetfilter-cthelper
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/utils/fuse package/utils/fuse
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/network/services/samba36 package/network/services/samba36
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/libs/libconfig package/libs/libconfig
svn co https://github.com/openwrt/openwrt/branches/openwrt-19.07/package/libs/libusb-compat package/libs/libusb-compat
svn co https://github.com/openwrt/packages/trunk/libs/nghttp2 feeds/packages/libs/nghttp2
ln -sf ../../../feeds/packages/libs/nghttp2 ./package/feeds/packages/nghttp2
svn co https://github.com/openwrt/packages/trunk/libs/libcap-ng feeds/packages/libs/libcap-ng
ln -sf ../../../feeds/packages/libs/libcap-ng ./package/feeds/packages/libcap-ng
rm -rf ./feeds/packages/utils/collectd
svn co https://github.com/openwrt/packages/trunk/utils/collectd feeds/packages/utils/collectd
svn co https://github.com/openwrt/packages/trunk/utils/usbutils feeds/packages/utils/usbutils
ln -sf ../../../feeds/packages/utils/usbutils ./package/feeds/packages/usbutils
svn co https://github.com/openwrt/packages/trunk/utils/hwdata feeds/packages/utils/hwdata
ln -sf ../../../feeds/packages/utils/hwdata ./package/feeds/packages/hwdata
rm -rf ./feeds/packages/net/dnsdist
svn co https://github.com/openwrt/packages/trunk/net/dnsdist feeds/packages/net/dnsdist
svn co https://github.com/openwrt/packages/trunk/libs/h2o feeds/packages/libs/h2o
ln -sf ../../../feeds/packages/libs/h2o ./package/feeds/packages/h2o
svn co https://github.com/openwrt/packages/trunk/libs/libwslay feeds/packages/libs/libwslay
ln -sf ../../../feeds/packages/libs/libwslay ./package/feeds/packages/libwslay

#IPSEC
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-ipsec-vpnd package/lean/luci-app-ipsec-vpnd
#ipv6-helper
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/ipv6-helper package/lean/ipv6-helper
#Zerotier
svn co https://github.com/project-openwrt/openwrt/branches/master/package/lean/luci-app-zerotier package/lean/luci-app-zerotier
cp -f ../PATCH/new/script/move_2_services.sh ./package/lean/luci-app-zerotier/move_2_services.sh
pushd package/lean/luci-app-zerotier
bash move_2_services.sh
popd
rm -rf ./feeds/packages/net/zerotier/files/etc/init.d/zerotier
#UPNP（回滚以解决某些沙雕设备的沙雕问题
rm -rf ./feeds/packages/net/miniupnpd
svn co https://github.com/coolsnowwolf/packages/trunk/net/miniupnpd feeds/packages/net/miniupnpd
#KMS
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-vlmcsd package/lean/luci-app-vlmcsd
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/vlmcsd package/lean/vlmcsd
#frp
rm -f ./feeds/luci/applications/luci-app-frps
rm -f ./feeds/luci/applications/luci-app-frpc
rm -rf ./feeds/packages/net/frp
rm -f ./package/feeds/packages/frp
#git clone --depth 1 https://github.com/lwz322/luci-app-frps.git package/lean/luci-app-frps
#git clone --depth 1 https://github.com/kuoruan/luci-app-frpc.git package/lean/luci-app-frpc
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-frps package/lean/luci-app-frps
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/luci-app-frpc package/lean/luci-app-frpc
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/frp package/lean/frp
#花生壳
svn co https://github.com/teasiu/dragino2/trunk/package/teasiu/luci-app-phtunnel package/new/luci-app-phtunnel
svn co https://github.com/QiuSimons/dragino2-teasiu/trunk/package/teasiu/luci-app-oray package/new/luci-app-oray
svn co https://github.com/teasiu/dragino2/trunk/package/teasiu/phtunnel package/new/phtunnel
#腾讯DDNS
#svn co https://github.com/Tencent-Cloud-Plugins/tencentcloud-openwrt-plugin-ddns/trunk/tencentcloud_ddns package/lean/luci-app-tencentddns
svn co https://github.com/1715173329/tencentcloud-openwrt-plugin-ddns/trunk/tencentcloud_ddns package/lean/luci-app-tencentddns
#阿里DDNS
svn co https://github.com/kenzok8/openwrt-packages/trunk/luci-app-aliddns package/new/luci-app-aliddns
#翻译及部分功能优化
cp -rf ../PATCH/duplicate/addition-trans-zh ./package/lean/lean-translate
sed -i '/openssl/d' ./package/lean/lean-translate/files/zzz-default-settings
sed -i '/banirq/d' ./package/lean/lean-translate/files/zzz-default-settings
sed -i '/rngd/d' ./package/lean/lean-translate/files/zzz-default-settings

#Vermagic
latest_version="$(curl -s https://github.com/openwrt/openwrt/releases |grep -Eo "v[0-9\.]+.tar.gz" |sed -n '/19/p' |sed -n 1p |sed 's/v//g' |sed 's/.tar.gz//g')"
wget https://downloads.openwrt.org/releases/${latest_version}/targets/x86/64/packages/Packages.gz
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk

##最后的收尾工作
mkdir package/base-files/files/usr/bin
cp -f ../PATCH/new/script/fuck package/base-files/files/usr/bin/fuck
cp -f ../PATCH/new/script/chinadnslist package/base-files/files/usr/bin/chinadnslist
#最大连接
sed -i 's/16384/65536/g' package/kernel/linux/files/sysctl-nf-conntrack.conf
#修改启动等待（可能无效）
sed -i 's/default "5"/default "0"/g' config/Config-images.in
#预配置一些插件
cp -rf ../PATCH/X86/files ./files
#生成默认配置及缓存
rm -rf .config
exit 0
