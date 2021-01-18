## R2S/R4S/X86 基于原生OpenWRT 的固件(AS IS, NO WARRANTY!!!)
![R2S-OpenWrt](https://github.com/QiuSimons/R2S-R4S-X86-OpenWrt/workflows/R2S-OpenWrt/badge.svg)
![R4S-OpenWrt](https://github.com/QiuSimons/R2S-R4S-X86-OpenWrt/workflows/R4S-OpenWrt/badge.svg)
![X86-OpenWrt](https://github.com/QiuSimons/R2S-R4S-X86-OpenWrt/workflows/X86-OpenWrt/badge.svg)
### 请勿用于商业用途!!! 请勿用于商业用途!!! 请勿用于商业用途!!! 请勿用于商业用途!!! 请勿用于商业用途!!!

### 下载地址：
https://github.com/QiuSimons/R2S-R4S-OpenWrt/releases

### 追新党可以在Action中取每日更新（可能会翻车，风险自担，需要登陆github后才能下载）：
https://github.com/QiuSimons/R2S-R4S-OpenWrt/actions

### Docker版本自行fork，修改seed，并在自己的Action中自取

### 注意事项：
0.R2S核心频率1.6，R4S核心频率2.2/1.8（特调了电压表，兼容5v3a的供电，但建议使用5v4a）

1.登陆IP：192.168.1.1 密码：无

2.OP内置升级可用

3.遇到上不了网的，请自行排查自己的ipv6联通情况。（推荐关闭ipv6，默认已关闭ipv6的dns解析，手动可以在DHCP/DNS里的高级设置中调整）

4.刷写或升级后遇到任何问题，可以尝试ssh进路由器，输入fuck，回车后等待重启，或可解决，如仍有异常，建议ssh进路由器，输入firstboot -y && reboot now，回车后等待重启

5.预配置了部分插件(预置了DNS套娃，要用的话勾上adg的启动，并保存应用，就好。然后ssrp的dns上游提前选成本机5335端口，openclash还有passwall自行触类旁通。adg管理端口3000，密码admin)
如果要作用于路由器本身，可以把lan和wan的dns都配置成127.0.0.1，dhcp高级里设置下发dns 6,192.168.1.1(这里取决于你设定的路由的ip地址)

### 版本信息：
LUCI版本：19.07（当日最新）

R2S/R4S其他模块版本：SNAPSHOT（当日最新）

R4S的支援由[1715173329](https://github.com/1715173329/)完成！

X86其他模块版本：19.07（当日最新）

### 特性及功能：
1.O2编译

2.内置两款主题

3.插件包含：SSRP，PassWall，OpenClash，AdguardHome，BearDropper，微信推送，网易云解锁，SQM，SmartDNS，ChinaDNS，网络唤醒，DDNS，迅雷快鸟，UPNP，FullCone(防火墙中开启，默认开启)，流量分载(防火墙中开启)，SFE流量分载(也就是SFE加速，防火墙中开启，且默认开启)，BBR（默认开启），irq优化，京东签到，Zerotier，FRPC，FRPS，无线打印，流量监控，过滤军刀，R2S-OLED

