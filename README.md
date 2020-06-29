## R2S 基于原生OpenWRT 的固件(AS IS, NO WARRANTY!!!)

### 追新党可以在Action中取每日更新（可能会翻车，风险自担）：
https://github.com/project-openwrt/R2S-OpenWrt/actions

### 本地一键编译命令（注意装好依赖）：
git clone https://github.com/project-openwrt/R2S-OpenWrt.git&&cd R2S-OpenWrt&&bash onekeyr2s.sh

### 注意事项：
0.IRQ脚本依赖nohup组件，fork后自行魔改的用户请补全依赖（默认状态下nohup是openclash的依赖，所以我这边没加，如果你去掉了openclash，请自行补齐依赖）

1.登陆IP：192.168.1.1 密码：无

2.LAN 和 WAN的灯可能不亮

3.OP内置升级可用

4.SSRP使用姿势： ①添加你要的订阅链接 ②再在最后加一行空行 ③右下角点一下保存并应用 ④更新所有订阅服务器节点

5.遇到上不了网的，请自行排查自己的ipv6联通情况，或禁用ipv6（同时禁用WAN和LAN的ipv6）

### 版本信息：
其他模块版本：SNAPSHOT（当日最新）

LUCI版本：19.07（当日最新）

### 特性及功能：
1.O3编译

2.内置三款主题，包含SSRP，openclash，ADBYBY，BearDropper，微信推送，网易云解锁，SQM，SmartDNS，网络唤醒，DDNS，迅雷快鸟，UPNP，FullCone(防火墙中开启)，流量分载(防火墙中开启)，BBR（默认开启）
