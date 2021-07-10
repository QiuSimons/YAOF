<p align="center">
<img width="768" src="https://raw.githubusercontent.com/QiuSimons/Others/master/YAOF.png" >
</p>
<p align="center">
<img src="https://forthebadge.com/images/badges/built-with-love.svg">
<p>
<p align="center">
<img alt="GitHub All Releases" src="https://img.shields.io/github/downloads/QiuSimons/R2S-R4S-X86-OpenWrt/total?style=for-the-badge">
<img alt="GitHub" src="https://img.shields.io/github/license/sdmkjz/R2S-R4S-X86-OpenWrt?style=for-the-badge">
<p>
<p align="center">
<img src="https://github.com/QiuSimons/R2S-R4S-X86-OpenWrt/workflows/R2S-OpenWrt/badge.svg">
<img src="https://github.com/QiuSimons/R2S-R4S-X86-OpenWrt/workflows/R4S-OpenWrt/badge.svg">
<img src="https://github.com/QiuSimons/R2S-R4S-X86-OpenWrt/workflows/X86-OpenWrt/badge.svg">
<p>


<h1 align="center">请勿用于商业用途!!!</h1>



### 原特性

- 基于原生 OpenWrt 21.02 编译，默认管理地址192.168.1.1
- 同时支持 SFE/Software Offload （选则其一开启，<b>默认开启SFE</b>）
- 内置升级功能可用，物理 Reset 按键可用
- 预配置了部分插件（包括但不限于 DNS 套娃，使用时先将 SSRP 的 DNS 上游提前选成本机5335端口，然后再 ADG 中勾上启用就好*“管理账户root，密码admin”，如果要作用于路由器本身，可以把lan和wan的dns都配置成127.0.0.1，dhcp高级里设置下发dns 6,192.168.1.1。注：这里取决于你设定的路由的ip地址）<b>(注意，6月29日开始取消了dns套娃，使用dnsfilter作为广告过滤手段，使用dnsproxy作为dns分流措施，海外端口5335，国内端口6050，无GUI，自行琢磨使用。或可尝试ssh进入后台，输入setdns后回车，使用预设的dns方案)</b>
- 正式 Release 版本将具有可无脑 opkg kmod 的特性
- R2S核心频率1.6（交换了LAN WAN），R4S核心频率2.2/1.8（建议使用5v4a电源，死机大多数情况下，都是因为<b>你用的电源过于垃圾</b>，另外，你也可以选择使用<b>自带的app限制最大频率</b>，茄子🍆）
- O3 编译
- 插件包含：SSRP，PassWall，OpenClash，AdguardHome，微信推送，网易云解锁，SQM，SmartDNS，ChinaDNS，网络唤醒，DDNS，迅雷快鸟，UPNP，FullCone(防火墙中开启，默认开启)，流量分载，SFE流量分载，irq优化，京东签到，Zerotier，FRPC，FRPS，无线打印，流量监控，过滤军刀，R2S-OLED
- ss协议在armv8上实现了aes硬件加速（请<b>仅使用aead加密</b>的连接方式）
- 如有任何问题，请先尝试ssh进入后台，输入fuck后回车，等待机器重启后确认问题是否已经解决

### R2S新特性
- 取消 OLED，FrpC/S，PassWall
- 增加 Docker，TTYD终端，AdGuardHome，应用过滤支持

### 下载

- 选择自己<b>设备对应的固件</b>，并[下载](https://github.com/sdmkjz/R2S-R4S-OpenWrt/releases)

### 截图

|                      组件                       |                      流量分载                       |
| :----------------------------------------------------------: | :----------------------------------------------------------: |
| ![主页.png](https://raw.githubusercontent.com/sdmkjz/R4S-OpenWrt/master/PIC/app.png) | ![offload.png](https://raw.githubusercontent.com/sdmkjz/R4S-OpenWrt/master/PIC/offload.png) |

### 鸣谢

|          [CTCGFW](https://github.com/immortalwrt)           |           [coolsnowwolf](https://github.com/coolsnowwolf)            |              [Lienol](https://github.com/Lienol)               |
| :----------------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: |
| <img width="60" src="https://avatars.githubusercontent.com/u/53193414"/> | <img width="60" src="https://avatars.githubusercontent.com/u/31687149" /> | <img width="60" src="https://avatars.githubusercontent.com/u/23146169" /> |
|              [NoTengoBattery](https://github.com/NoTengoBattery)               |              [tty228](https://github.com/tty228)               |              [destan19](https://github.com/destan19)               |
| <img width="60" src="https://avatars.githubusercontent.com/u/11285513" /> | <img width="60" src="https://avatars.githubusercontent.com/u/33397881" /> | <img width="60" src="https://avatars.githubusercontent.com/u/3950091" /> |
|              [jerrykuku](https://github.com/jerrykuku)               |              [lisaac](https://github.com/lisaac)               |              [rufengsuixing](https://github.com/rufengsuixing)               |
| <img width="60" src="https://avatars.githubusercontent.com/u/9485680" /> | <img width="60" src="https://avatars.githubusercontent.com/u/3320969" /> | <img width="60" src="https://avatars.githubusercontent.com/u/22387141" /> |
|              [ElonH](https://github.com/ElonH)               |              [NateLol](https://github.com/NateLol)               |              [garypang13](https://github.com/garypang13)               |
| <img width="60" src="https://avatars.githubusercontent.com/u/32666230" /> | <img width="60" src="https://avatars.githubusercontent.com/u/5166306" /> | <img width="60" src="https://avatars.githubusercontent.com/u/48883331" /> |
|              [AmadeusGhost](https://github.com/AmadeusGhost)               |              [1715173329](https://github.com/1715173329)               |              [vernesong](https://github.com/vernesong)               |
| <img width="60" src="https://avatars.githubusercontent.com/u/42570690" /> | <img width="60" src="https://avatars.githubusercontent.com/u/22235437" /> | <img width="60" src="https://avatars.githubusercontent.com/u/42875168" /> |
