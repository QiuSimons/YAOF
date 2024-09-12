#!/bin/bash

#1. 修改默认IP
sed -i 's/192.168.1.1/192.168.10.1/g' Lienol/package/base-files/files/bin/config_generate
#2. 删除最后一行
sed -i '/\/usr\/bin\/zsh/d' Lienol/package/base-files/files/files/etc/profile
#3. 修改默认主题
sed -i 's/luci-theme-bootstrap/luci-theme-kucat/g' Lienol/immortalwrt_23/package/feeds/luci/collections/luci/Makefile
sed -i 's/luci-theme-bootstrap/luci-theme-kucat/g' Lienol/immortalwrt_23/package/feeds/luci/collections/luci-nginx/Makefile
sed -i 's/luci-theme-bootstrap/luci-theme-kucat/g' Lienol/immortalwrt_23/package/feeds/luci/collections/luci-ssl-nginx/Makefile
sed -i 's/luci-theme-bootstrap/luci-theme-kucat/g' Lienol/immortalwrt_23/package/feeds/luci/collections/luci-light/Makefile
