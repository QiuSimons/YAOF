## R2S 基于原生QiuSimons/R2S-OpenWrt

2020.12.17 16:15 新版正在编译中。

### 注意事项：
0.OC至1.6G（未提升电压，原则上不会增加大量额外发热）

1.登陆IP：192.168.1.1 密码：无

2.OP内置升级可用

3.遇到上不了网的，请自行排查自己的ipv6联通情况。（推荐关闭ipv6，默认已关闭ipv6的dns解析，手动可以在DHCP/DNS里的高级设置中调整）

4.刷写或升级后遇到任何问题，可以尝试ssh进路由器，输入fuck，回车后等待重启，或可解决，如仍有异常，建议ssh进路由器，输入firstboot -y && reboot now，回车后等待重启

5.从2020.8.1开始重新交换 LAN WAN，解决千兆环境下IDM下载掉速的问题，用户注意！！！！！（当前靠外的是LAN，靠中心的是WAN）

6.sys灯引导时闪烁，启动后常亮，是上游的设定，有疑问请联系OP官方社区

7.预配置了部分插件(预置了DNS套娃，要用的话勾上adg的启动，并保存应用，就好。然后ssrp的dns上游提前选成本机5335端口，openclash还有passwall自行触类旁通。adg管理端口3000，密码admin)
如果要作用于路由器本身，可以把lan和wan的dns都配置成127.0.0.1，dhcp高级里设置下发dns 6,192.168.1.1(这里取决于你设定的路由的ip地址)

### 版本信息：
其他模块版本：SNAPSHOT（当日最新）

LUCI版本：19.07（当日最新）

### 特性及功能：
1.O2编译

2.内置两款主题

3.插件包含：，PassWall，，AdguardHome，，，，SmartDNS，ChinaDNS，，，，，FullCone(防火墙中开启)，流量分载(防火墙中开启)，SFE流量分载(也就是SFE加速，防火墙中开启，且默认开启)，，，，，，，，，，，

4.核心频率1.5G（稳定与否取决于你设备体制，求稳可以在CPU性能调节优化里降低最大频率）

