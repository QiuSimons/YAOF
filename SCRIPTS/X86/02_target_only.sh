#!/bin/bash

sed -i 's/O2/O2 -march=x86-64-v2/g' include/target.mk

# libsodium
sed -i 's,no-mips16 no-lto,no-mips16,g' feeds/packages/libs/libsodium/Makefile



echo '#!/bin/sh

# 首次启动时执行的命令
cat /etc/fakeip_network >> /etc/config/network
mv /etc/fakeip_config.json /etc/sing-box/config.json
# 删除原有的 /etc/rc.local 文件
rm -rf /etc/fakeip_network
rm /etc/rc.local

# 重新创建一个新的 /etc/rc.local 文件，并写入指定内容
echo "#!/bin/sh
# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

grep \"Default string\" /tmp/sysinfo/model >> /dev/null
if [ \$? -ne 0 ]; then
    echo should be fine
else
    echo \"Generic PC\" > /tmp/sysinfo/model
fi
nohup /usr/bin/sing-box run -c /etc/sing-box/config.json > /tmp/sbstart.log 2>&1 &
nft -f /etc/nftables.conf &
exit 0" > /etc/rc.local
# 确保新的 /etc/rc.local 文件有可执行权限
chmod +x /etc/rc.local
exit 0' > ./package/base-files/files/etc/rc.local


echo '
config route
	option target '28.0.0.0'
	option netmask '255.0.0.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '8.8.8.8'
	option netmask '255.255.255.255'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '8.8.4.4'
	option netmask '255.255.255.255'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '1.1.1.1'
	option netmask '255.255.255.255'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '1.0.0.1'
	option netmask '255.255.255.255'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '9.9.9.9'
	option netmask '255.255.255.255'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '8.41.4.0'
	option netmask '255.255.255.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '23.23.189.144'
	option netmask '255.255.255.240'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '23.246.0.0'
	option netmask '255.255.192.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '34.195.253.0'
	option netmask '255.255.255.128'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '37.77.184.0'
	option netmask '255.255.248.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '38.72.126.0'
	option netmask '255.255.255.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '45.57.0.0'
	option netmask '255.255.128.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '52.24.178.0'
	option netmask '255.255.255.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '52.35.140.0'
	option netmask '255.255.255.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '54.204.25.0'
	option netmask '255.255.255.240'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '54.213.167.0'
	option netmask '255.255.255.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '64.120.128.0'
	option netmask '255.255.128.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '66.197.128.0'
	option netmask '255.255.128.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '69.53.224.0'
	option netmask '255.255.224.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '103.87.204.0'
	option netmask '255.255.252.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '108.175.32.0'
	option netmask '255.255.240.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '185.2.220.0'
	option netmask '255.255.252.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '185.9.188.0'
	option netmask '255.255.252.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '192.173.64.0'
	option netmask '255.255.192.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '198.38.96.0'
	option netmask '255.255.224.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '198.45.48.0'
	option netmask '255.255.240.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '203.75.84.0'
	option netmask '255.255.255.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '203.198.13.0'
	option netmask '255.255.255.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '203.198.80.0'
	option netmask '255.255.255.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '207.45.72.0'
	option netmask '255.255.252.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '208.75.76.0'
	option netmask '255.255.252.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '210.0.153.0'
	option netmask '255.255.255.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '91.108.56.0'
	option netmask '255.255.252.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '91.108.4.0'
	option netmask '255.255.252.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '91.108.8.0'
	option netmask '255.255.252.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '91.108.16.0'
	option netmask '255.255.252.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '91.108.12.0'
	option netmask '255.255.252.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '149.154.160.0'
	option netmask '255.255.240.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '91.105.192.0'
	option netmask '255.255.254.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '91.108.20.0'
	option netmask '255.255.252.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '185.76.151.0'
	option netmask '255.255.255.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config route
	option target '95.161.64.0'
	option netmask '255.255.240.0'
	option type 'local'
	option table '100'
	option interface 'lan'

config rule
	option mark '1'
	option lookup '100'

config route6
	option target '2001:b28:f23d::'
	option netmask '48'
	option type 'local'
	option table '200'
	option interface 'lan'

config route6
	option target '2001:b28:f23f::'
	option netmask '48'
	option type 'local'
	option table '200'
	option interface 'lan'

config route6
	option target '2001:67c:4e8::'
	option netmask '48'
	option type 'local'
	option table '200'
	option interface 'lan'

config route6
	option target '2001:b28:f23c::'
	option netmask '48'
	option type 'local'
	option table '200'
	option interface 'lan'

config route6
	option target '2a0a:f280::'
	option netmask '32'
	option type 'local'
	option table '200'
	option interface 'lan'

config route6
	option target '2607:fb10::'
	option netmask '32'
	option type 'local'
	option table '200'
	option interface 'lan'

config route6
	option target '2620:10c:7000::'
	option netmask '44'
	option type 'local'
	option table '200'
	option interface 'lan'

config route6
	option target '2a00:86c0::'
	option netmask '32'
	option type 'local'
	option table '200'
	option interface 'lan'

config route6
	option target '2a03:5640::'
	option netmask '32'
	option type 'local'
	option table '200'
	option interface 'lan'

config route6
	option target 'fc00::'
	option netmask '18'
	option type 'local'
	option table '200'
	option interface 'lan'

config rule6
	option mark '1'
	option lookup '200'

' >./package/base-files/files/etc/fakeip_network

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
echo '
{
  "log": {
    "disabled": false,
    "level": "debug",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "nodedns",
        "address": "tls://223.5.5.5:853",
        "detour": "direct"
      },
      {
        "tag": "fakeipDNS",
        "address": "fakeip"
      },
      {
        "tag": "block",
        "address": "rcode://success"
      }
    ],
    "rules": [
      {
        "query_type": [
          "SVCB"
        ],
        "server": "block"
      },
      {
        "inbound": "dns-in",
        "server": "fakeipDNS",
        "disable_cache": false,
        "rewrite_ttl": 1
      },
      {
        "outbound": "any",
        "server": "nodedns",
        "disable_cache": true
      }
    ],
    "fakeip": {
      "enabled": true,
      "inet4_range": "28.0.0.1/8",
      "inet6_range": "fc00::/18"
    },
    "independent_cache": true
  },
  "inbounds": [
    {
      "type": "mixed",
      "listen": "::",
      "listen_port": 10000
    },
    {
      "type": "direct",
      "tag": "dns-in",
      "listen": "::",
      "listen_port": 6666
    },
    {
      "type": "redirect",
      "tag": "redirect-in",
      "listen": "::",
      "listen_port": 7899,
      "tcp_fast_open": true,
      "sniff": false,
      "sniff_override_destination": false,
      "sniff_timeout": "300ms",
      "udp_disable_domain_unmapping": false,
      "udp_timeout": "5m"
    },
    {
      "type": "tproxy",
      "tag": "tproxy-in",
      "listen": "::",
      "listen_port": 7896,
      "tcp_fast_open": true,
      "sniff": true,
      "sniff_override_destination": false,
      "sniff_timeout": "100ms"
    },
    {
      "type": "shadowsocks",
      "tag": "ss-in",
      "listen": "0.0.0.0",
      "listen_port": 10813,
      "method": "aes-128-gcm",
      "password": "123456789",
      "multiplex": {}
    }
  ],
  "outbounds": [
    {
      "tag": "♾️Global",
      "type": "selector",
      "outbounds": [
        "♾️test"
      ]
    },
  {
      "tag": "♾️test",
      "server": "vps.herozmy.com",
      "server_port": 111,
      "type": "vless",
      "uuid": "1aed51fe-xxxxx-46e9-xxx-xxxxxxx",
      "tls": {
        "enabled": true,
        "server_name": "xxxx.xxxxxx.com"
      },
      "transport": {
        "type": "ws",
        "path": "/xxxxx"
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "tag": "tolan",
      "type": "direct",
      "bind_interface": "br-lan"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "rules": [
      {
        "inbound": "dns-in",
        "outbound": "dns-out"
      },
      {
        "clash_mode": "direct",
        "outbound": "direct"
      },
      {
        "clash_mode": "global",
        "outbound": "♾️Global"
      },
      {
        "type": "logical",
        "mode": "and",
        "rules": [
          {
            "inbound": "ss-in"
          },
          {
            "ip_cidr": [
              "10.10.10.0/24"
            ]
          }
        ],
        "outbound": "tolan"
      },
      {
        "network": "udp",
        "port": 443,
        "outbound": "block"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "domain_suffix": [
          "browserleaks.com"
        ],
        "outbound": "♾️Global"
      },
      {
        "domain_suffix": [
          "googleapis.com",
          "googleapis.cn",
          "gstatic.com"
        ],
        "outbound": "♾️Global"
      },
      {
        "domain_suffix": [
          "office365.com",
          "office.com"
        ],
        "outbound": "direct"
      },
      {
        "domain_suffix": [
          "push.apple.com",
          "iphone-ld.apple.com",
          "lcdn-locator.apple.com",
          "lcdn-registration.apple.com"
        ],
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-category-games-cn",
        "outbound": "direct"
      },
      {
        "rule_set": [
          "geosite-category-scholar-!cn",
          "geosite-category-scholar-cn"
        ],
        "outbound": "direct"
      },
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-geolocation-!cn",
        "outbound": "♾️Global"
      },
      {
        "rule_set": [
          "geoip-telegram",
          "geosite-telegram"
        ],
        "outbound": "♾️Global"
      },
      {
        "rule_set": [
          "geoip-google",
          "geosite-google"
        ],
        "outbound": "♾️Global"
      },
      {
        "rule_set": "geoip-cn",
        "invert": true,
        "outbound": "♾️Global"
      }
    ],
    "rule_set": [
      {
        "tag": "geoip-google",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/google.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geoip-telegram",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/telegram.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geoip-twitter",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/twitter.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geoip-facebook",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/facebook.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geoip-netflix",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/netflix.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geoip-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geoip-hk",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/hk.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geoip-mo",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/mo.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-openai",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/openai.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-youtube",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/youtube.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-google",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/google.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-github",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/github.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-telegram",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/telegram.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-twitter",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/twitter.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-facebook",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/facebook.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-instagram",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/instagram.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-amazon",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/amazon.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-apple",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/apple.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-apple-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/apple@cn.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-microsoft",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/microsoft.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-microsoft-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/microsoft@cn.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-category-games",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-games.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-category-games-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-games@cn.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-bilibili",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/bilibili.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-tiktok",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/tiktok.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-netflix",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/netflix.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-hbo",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/hbo.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-disney",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/disney.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-primevideo",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/primevideo.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/cn.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-geolocation-!cn",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-!cn.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-ads-all.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-category-scholar-!cn",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-scholar-!cn.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      },
      {
        "tag": "geosite-category-scholar-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-scholar-cn.srs",
        "download_detour": "direct",
        "update_interval": "7d"
      }
    ],
    "final": "♾️Global",
    "auto_detect_interface": true,
    "default_mark": 1
  },
  "experimental": {
    "clash_api": {
      "external_controller": "0.0.0.0:9090",
      "external_ui": "/usr/share/openclash/ui/metacubexd",
      "secret": "",
      "default_mode": "rule"
    },
    "cache_file": {
      "enabled": true,
      "path": "/etc/sing-box/cache.db",
      "cache_id": "my_profile1",
      "store_fakeip": true
    }
  }
}
' >./package/base-files/files/etc/fakeip_config.json

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
