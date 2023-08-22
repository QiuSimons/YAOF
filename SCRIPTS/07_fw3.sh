#!/bin/bash
# 回滚 iptables 为 1.8.7（1.8.8有一个致命bug，当上游升级至1.8.9时可以去除下面3行；具体参见https://www.netfilter.org/projects/iptables/files/changes-iptables-1.8.9.txt）
rm -rf ./package/network/utils/iptables
cp -rf ../openwrt_22/package/network/utils/iptables ./package/network/utils/iptables
cp -rf ../lede/package/network/utils/iptables/patches/900-bcm-fullconenat.patch ./package/network/utils/iptables/patches/900-bcm-fullconenat.patch
# 滚回fw3
pushd feeds/luci
patch -Rp1 <../../../PATCH/firewall/luci-app-firewall_add_fullcone_fw4.patch
patch -p1 <../../../PATCH/firewall/luci-app-firewall_add_fullcone_fw3.patch
popd
sed -i 's,iptables-nft,iptables-legacy,g' ./package/new/luci-app-passwall2/Makefile
sed -i 's,iptables-nft,iptables-legacy,g' ./package/new/luci-app-passwall/Makefile
sed -i 's,iptables-nft +kmod-nft-fullcone,iptables-mod-fullconenat,g' ./package/new/addition-trans-zh/Makefile
rm -rf ./feeds/packages/net/miniupnpd
cp -rf ../immortalwrt_pkg_21/net/miniupnpd ./feeds/packages/net/miniupnpd
rm -rf ./feeds/luci/applications/luci-app-upnp
cp -rf ../immortalwrt_luci_21/applications/luci-app-upnp ./feeds/luci/applications/luci-app-upnp
sed -i '/firewall/d' ./.config
sed -i '/offload/d' ./.config
sed -i '/tables/d' ./.config
sed -i '/nft/d' ./.config
sed -i '/Nft/d' ./.config
echo '
CONFIG_PACKAGE_firewall=y
# CONFIG_PACKAGE_firewall4 is not set
# CONFIG_PACKAGE_iptables-nft is not set
CONFIG_PACKAGE_iptables-zz-legacy=y
# CONFIG_PACKAGE_ip6tables-nft is not set
CONFIG_PACKAGE_ip6tables-zz-legacy=y
CONFIG_PACKAGE_xtables-legacy=y
# CONFIG_PACKAGE_xtables-nft is not set
CONFIG_PACKAGE_kmod-nft-offload=n
CONFIG_PACKAGE_kmod-ipt-offload=y
CONFIG_PACKAGE_dnsmasq_full_ipset=y
CONFIG_PACKAGE_dnsmasq_full_nftset=n
CONFIG_PACKAGE_iptables-mod-fullconenat=y
' >>./.config
rm -rf ./feeds/luci/applications/luci-app-zerotier
cp -rf ../lede_luci/applications/luci-app-zerotier ./feeds/luci/applications/luci-app-zerotier
wget -P feeds/luci/applications/luci-app-zerotier/ https://github.com/QiuSimons/OpenWrt-Add/raw/master/move_2_services.sh
chmod -R 755 ./feeds/luci/applications/luci-app-zerotier/move_2_services.sh
pushd feeds/luci/applications/luci-app-zerotier
bash move_2_services.sh
popd
ln -sf ../../../feeds/luci/applications/luci-app-zerotier ./package/feeds/luci/luci-app-zerotier

exit 0
