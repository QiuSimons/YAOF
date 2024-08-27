#!/bin/bash

#1. 修改默认IP
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate
# 修改默认主题
sed -i 's/luci-theme-bootstrap/luci-theme-kucat/g' feeds/luci/collections/luci/Makefile