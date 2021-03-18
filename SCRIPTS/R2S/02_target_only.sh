#!/bin/bash
clear

# 使用专属优化
sed -i 's,-mcpu=generic,-march=armv8-a+crypto+crc -mabi=lp64,g' include/target.mk
cp -f ../PATCH/new/package/100-Implements-AES-and-GCM-with-ARMv8-Crypto-Extensions.patch ./package/libs/mbedtls/patches/100-Implements-AES-and-GCM-with-ARMv8-Crypto-Extensions.patch

# 解决 DDR 内存问题
patch -p1 < ../PATCH/new/main/0001-dmc-rk3328.patch
wget -P target/linux/rockchip/patches-5.4 https://github.com/immortalwrt/immortalwrt/raw/master/target/linux/rockchip/patches-5.4/803-PM-devfreq-rockchip-add-devfreq-driver-for-rk3328-dmc.patch
wget -P target/linux/rockchip/patches-5.4 https://github.com/immortalwrt/immortalwrt/raw/master/target/linux/rockchip/patches-5.4/804-clk-rockchip-support-setting-ddr-clock-via-SIP-Version-2-.patch
wget -P target/linux/rockchip/patches-5.4 https://github.com/immortalwrt/immortalwrt/raw/master/target/linux/rockchip/patches-5.4/805-PM-devfreq-rockchip-dfi-add-more-soc-support.patch
wget -P target/linux/rockchip/patches-5.4 https://github.com/immortalwrt/immortalwrt/raw/master/target/linux/rockchip/patches-5.4/806-arm64-dts-rockchip-rk3328-add-dfi-node.patch
wget -P target/linux/rockchip/patches-5.4 https://github.com/immortalwrt/immortalwrt/raw/master/target/linux/rockchip/patches-5.4/807-arm64-dts-nanopi-r2s-add-rk3328-dmc-relate-node.patch
svn co https://github.com/immortalwrt/immortalwrt/branches/master/target/linux/rockchip/files target/linux/rockchip/files
svn co https://github.com/immortalwrt/immortalwrt/branches/master/package/boot/arm-trusted-firmware-rk3328 package/boot/arm-trusted-firmware-rk3328

# RK3328 加入 idle 模式
wget -P target/linux/rockchip/patches-5.4 https://github.com/immortalwrt/immortalwrt/raw/master/target/linux/rockchip/patches-5.4/007-arm64-dts-rockchip-Add-RK3328-idle-state.patch
# 修改内核 DMA 到 2MiB
wget -P target/linux/rockchip/patches-5.4 https://github.com/immortalwrt/immortalwrt/raw/master/target/linux/rockchip/patches-5.4/911-kernel-dma-adjust-default-coherent_pool-to-2MiB.patch
# 超频到 1.6 GHz
wget -P target/linux/rockchip/patches-5.4 https://github.com/immortalwrt/immortalwrt/raw/master/target/linux/rockchip/patches-5.4/991-arm64-dts-rockchip-add-more-cpu-operating-points-for.patch
# 开启 i2c0
cp -f ../PATCH/new/main/998-rockchip-enable-i2c0-on-NanoPi-R2S.patch ./target/linux/rockchip/patches-5.4/998-rockchip-enable-i2c0-on-NanoPi-R2S.patch
# 配置 IRQ 并默认关闭 eth0 offloading rx/rx
patch -p1 < ../PATCH/new/main/0002-IRQ-and-disable-eth0-tcp-udp-offloading-tx-rx.patch
# 交换 lan/wan 口
sed -i 's,"eth1" "eth0","eth0" "eth1",g' target/linux/rockchip/armv8/base-files/etc/board.d/02_network
sed -i "s,'eth1' 'eth0','eth0' 'eth1',g" target/linux/rockchip/armv8/base-files/etc/board.d/02_network

# 翻译及部分功能优化
cp -rf ../PATCH/duplicate/addition-trans-zh ./package/lean/lean-translate
echo "
sed -i 's,#devcrypto,devcrypto,g' /etc/ssl/openssl.cnf
sed -i 's,#USE_SOFTDRIVERS = 2,USE_SOFTDRIVERS = 1,g' /etc/ssl/openssl.cnf
exit 0

" >> ./package/lean/lean-translate/files/zzz-default-settings
<<'COMMENT'
#Vermagic
latest_version="$(curl -s https://github.com/openwrt/openwrt/releases |grep -Eo "v[0-9\.]+\-*r*c*[0-9]*.tar.gz" |sed -n '/21/p' |sed -n 1p |sed 's/v//g' |sed 's/.tar.gz//g')"
wget https://downloads.openwrt.org/releases/${latest_version}/targets/rockchip/armv8/packages/Packages.gz
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
COMMENT

# 对齐内核 Vermagic
wget https://downloads.openwrt.org/releases/21.02-SNAPSHOT/targets/rockchip/armv8/packages/Packages.gz
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk

# 内核加解密组件
echo '
CONFIG_ARM64_CRYPTO=y
CONFIG_ARM_PSCI_CPUIDLE_DOMAIN=y
CONFIG_ARM_PSCI_FW=y
CONFIG_ARM_RK3328_DMC_DEVFREQ=y
CONFIG_CRYPTO_AES_ARM64=y
CONFIG_CRYPTO_AES_ARM64_BS=y
CONFIG_CRYPTO_AES_ARM64_CE=y
CONFIG_CRYPTO_AES_ARM64_CE_BLK=y
CONFIG_CRYPTO_AES_ARM64_CE_CCM=y
CONFIG_CRYPTO_AES_ARM64_NEON_BLK=y
CONFIG_CRYPTO_CHACHA20_NEON=y
# CONFIG_CRYPTO_CRCT10DIF_ARM64_CE is not set
CONFIG_CRYPTO_GHASH_ARM64_CE=y
CONFIG_CRYPTO_NHPOLY1305_NEON=y
CONFIG_CRYPTO_POLY1305_NEON=y
CONFIG_CRYPTO_SHA1_ARM64_CE=y
CONFIG_CRYPTO_SHA2_ARM64_CE=y
CONFIG_CRYPTO_SHA256_ARM64=y
CONFIG_CRYPTO_SHA3_ARM64=y
CONFIG_CRYPTO_SHA512_ARM64=y
# CONFIG_CRYPTO_SHA512_ARM64_CE is not set
CONFIG_CRYPTO_SM3_ARM64_CE=y
CONFIG_CRYPTO_SM4_ARM64_CE=y
' >> ./target/linux/rockchip/armv8/config-5.4

# 预配置一些插件
cp -rf ../PATCH/R2S/files ./files

exit 0
