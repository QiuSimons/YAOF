#!/bin/bash

# 这个脚本的作用是从不同的仓库中克隆openwrt相关的代码，并进行一些处理

# 定义一个函数，用来克隆指定的仓库和分支
clone_repo() {
  # 参数1是仓库地址，参数2是分支名，参数3是目标目录
  repo_url=$1
  branch_name=$2
  target_dir=$3
  # 克隆仓库到目标目录，并指定分支名和深度为1
  git clone -b $branch_name --depth 1 $repo_url $target_dir
}

# 定义一些变量，存储仓库地址和分支名
latest_release="$(curl -s https://github.com/openwrt/openwrt/tags | grep -Eo "v[0-9\.]+\-*r*c*[0-9]*.tar.gz" | sed -n '/[2-9][3-9]/p' | sed -n 1p | sed 's/.tar.gz//g')"
immortalwrt_repo="https://github.com/immortalwrt/immortalwrt.git"
immortalwrt_pkg_repo="https://github.com/immortalwrt/packages.git"
immortalwrt_luci_repo="https://github.com/immortalwrt/luci.git"
lede_repo="https://github.com/coolsnowwolf/lede.git"
lede_luci_repo="https://github.com/coolsnowwolf/luci.git"
lede_pkg_repo="https://github.com/coolsnowwolf/packages.git"
openwrt_repo="https://github.com/openwrt/openwrt.git"
openwrt_pkg_repo="https://github.com/openwrt/packages.git"
openwrt_luci_repo="https://github.com/openwrt/luci.git"
lienol_repo="https://github.com/Lienol/openwrt.git"
lienol_pkg_repo="https://github.com/Lienol/openwrt-package"
openwrt_add_repo="https://github.com/QiuSimons/OpenWrt-Add.git"
openwrt_node_repo="https://github.com/nxhack/openwrt-node-packages.git"
passwall_pkg_repo="https://github.com/xiaorouji/openwrt-passwall-packages"
passwall_luci_repo="https://github.com/xiaorouji/openwrt-passwall"
openwrt_third_repo="https://github.com/jjm2473/openwrt-third"
dockerman_repo="https://github.com/lisaac/luci-app-dockerman"
diskman_repo="https://github.com/lisaac/luci-app-diskman"
docker_lib_repo="https://github.com/lisaac/luci-lib-docker"
mosdns_repo="https://github.com/QiuSimons/openwrt-mos"
ssrp_repo="https://github.com/fw876/helloworld"
zxlhhyccc_repo="https://github.com/zxlhhyccc/bf-package-master"
linkease_repo="https://github.com/linkease/openwrt-app-actions"
linkease_pkg_repo="https://github.com/jjm2473/packages"
linkease_luci_repo="https://github.com/jjm2473/luci"
sirpdboy_repo="https://github.com/sirpdboy/sirpdboy-package"
sbwdaednext_repo="https://github.com/sbwml/luci-app-daed-next"
lucidaednext_repo="https://github.com/QiuSimons/luci-app-daed-next"
sbwfw876_repo="https://github.com/sbwml/openwrt_helloworld"
sbw_pkg_repo="https://github.com/sbwml/openwrt_pkgs"
natmap_repo="https://github.com/blueberry-pie-11/luci-app-natmap"
xwrt_repo="https://github.com/QiuSimons/openwrt-natflow"

# 开始克隆仓库，并行执行
clone_repo $openwrt_repo $latest_release openwrt &
clone_repo $openwrt_repo openwrt-23.05 openwrt_snap &
clone_repo $immortalwrt_repo openwrt-23.05 immortalwrt_23 &
clone_repo $immortalwrt_pkg_repo master immortalwrt_pkg &
clone_repo $immortalwrt_luci_repo master immortalwrt_luci &
clone_repo $lede_repo master lede &
clone_repo $lede_luci_repo master lede_luci &
clone_repo $lede_pkg_repo master lede_pkg &
clone_repo $openwrt_repo main openwrt_ma &
clone_repo $openwrt_pkg_repo master openwrt_pkg_ma &
clone_repo $openwrt_luci_repo master openwrt_luci_ma &
clone_repo $openwrt_add_repo master OpenWrt-Add &
clone_repo $dockerman_repo master dockerman &
clone_repo $docker_lib_repo master docker_lib &
clone_repo $linkease_repo main linkease &
clone_repo $sirpdboy_repo main sirpdboy &
# 等待所有后台任务完成
wait

# 进行一些处理
find openwrt/package/* -maxdepth 0 ! -name 'firmware' ! -name 'kernel' ! -name 'base-files' ! -name 'Makefile' -exec rm -rf {} +
rm -rf ./openwrt_snap/package/firmware ./openwrt_snap/package/kernel ./openwrt_snap/package/base-files ./openwrt_snap/package/Makefile
cp -rf ./openwrt_snap/package/* ./openwrt/package/
cp -rf ./openwrt_snap/feeds.conf.default ./openwrt/feeds.conf.default

# 退出脚本
exit 0
