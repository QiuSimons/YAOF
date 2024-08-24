#!/bin/bash

sed -i 's/O2/O2 -march=x86-64-v2/g' include/target.mk

# libsodium
sed -i 's,no-mips16 no-lto,no-mips16,g' feeds/packages/libs/libsodium/Makefile

echo '# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

grep "Default string" /tmp/sysinfo/model >> /dev/null
if [ $? -ne 0 ];then
    echo should be fine
else
    echo "Generic PC" > /tmp/sysinfo/model
fi

nohup  /usr/bin/sing-box run -c /etc/sing-box/config.json > /tmp/sbstart.log 2>&1  &
nft -f /etc/nftables.conf &

exit 0
'> ./package/base-files/files/etc/rc.local
echo '
table inet singbox {
  set local_ipv4 {
    type ipv4_addr
    flags interval
    elements = {
      28.0.0.0/8,
      8.8.8.8/32,
      8.8.4.4/32,
      1.0.0.1/32,
      1.1.1.1/32,
      9.9.9.9/32,
      8.41.4.0/24,
      23.23.189.144/28,
      23.246.0.0/18,
      34.195.253.0/25,
      37.77.184.0/21,
      38.72.126.0/24,
      45.57.0.0/17,
      52.24.178.0/24,
      52.35.140.0/24,
      54.204.25.0/28,
      54.213.167.0/24,
      64.120.128.0/17,
      66.197.128.0/17,
      69.53.224.0/19,
      103.87.204.0/22,
      108.175.32.0/20,
      185.2.220.0/22,
      185.9.188.0/22,
      192.173.64.0/18,
      198.38.96.0/19,
      198.45.48.0/20,
      203.75.84.0/24,
      203.198.13.0/24,
      203.198.80.0/24,
      207.45.72.0/22,
      208.75.76.0/22,
      210.0.153.0/24,
      91.108.56.0/22,
      91.108.4.0/22,
      91.108.8.0/22,
      91.108.16.0/22,
      91.108.12.0/22,
      149.154.160.0/20,
      91.105.192.0/23,
      91.108.20.0/22,
      185.76.151.0/24,
      95.161.64.0/20
    }
  }

  set local_ipv6 {
    type ipv6_addr
    flags interval
    elements = {
      2001:b28:f23d::/48,
      2001:b28:f23f::/48,
      2001:67c:4e8::/48,
      2001:b28:f23c::/48,
      2a0a:f280::/32,
      2607:fb10::/32,
      2620:10c:7000::/44,
      2a00:86c0::/32,
      2a03:5640::/32,
      fc00::/18
    }
  }

  set router_ipv4 {
    type ipv4_addr
    flags interval
    elements = {
      28.0.0.0/8,
      8.8.8.8/32,
      8.8.4.4/32,
      1.0.0.1/32,
      1.1.1.1/32,
      9.9.9.9/32
    }
  }

  set router_ipv6 {
    type ipv6_addr
    flags interval
    elements = {
      fc00::/18
    }
  }

  chain singbox-tproxy {
    meta l4proto udp meta mark set 1 tproxy to :7896 accept
  }

  chain singbox-mark {
    meta mark set 1
  }

  chain mangle-prerouting {
    type filter hook prerouting priority mangle; policy accept;
    ip daddr @local_ipv4 meta l4proto udp ct direction original goto singbox-tproxy
    ip6 daddr @local_ipv6 meta l4proto udp ct direction original goto singbox-tproxy
  }

  chain mangle-output {
    type route hook output priority mangle; policy accept;
    ip daddr @router_ipv4 meta l4proto udp ct direction original goto singbox-mark
    ip6 daddr @router_ipv6  meta l4proto udp ct direction original goto singbox-mark
  }

  chain nat-prerouting {
    type nat hook prerouting priority dstnat; policy accept;
    ip daddr @local_ipv4 meta l4proto tcp redirect to :7899
    ip6 daddr @local_ipv6 meta l4proto tcp redirect to :7899
  }

  chain nat-output {
    type nat hook output priority filter; policy accept;
    ip daddr @router_ipv4 meta l4proto tcp redirect to :7899
    ip6 daddr @router_ipv6 meta l4proto tcp redirect to :7899
  }
}

'> ./package/base-files/files/etc/nftables.conf


# enable smp
echo '
CONFIG_X86_INTEL_PSTATE=y
CONFIG_SMP=y
' >>./target/linux/x86/config-5.15

#Vermagic
latest_version="$(curl -s https://github.com/openwrt/openwrt/tags | grep -Eo "v[0-9\.]+\-*r*c*[0-9]*.tar.gz" | sed -n '/[2-9][3-9]/p' | sed -n 1p | sed 's/v//g' | sed 's/.tar.gz//g')"
wget https://downloads.openwrt.org/releases/${latest_version}/targets/x86/64/packages/Packages.gz
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' >.vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk

# 预配置一些插件
cp -rf ../PATCH/files ./files

find ./ -name *.orig | xargs rm -f
find ./ -name *.rej | xargs rm -f

exit 0
