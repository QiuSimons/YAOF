#!/bin/bash

#1. 修改默认IP
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate
#2. 替换bash样式
NEW_PS1='export PS1="\[\e[31m\][\[\e[m\]\[\e[38;5;172m\]\u\[\e[m\]@\[\e[38;5;153m\]\h\[\e[m\] \[\e[38;5;214m\]\W\[\e[m\]\[\e[31m\]]\[\e[m\]\\$ "'
sed -i "s/^export PS1=.*/$NEW_PS1/" package/base-files/files/etc/profile
#3. 修改默认主题
cp -r package/new/luci-theme-edge feeds/luci/themes/luci-theme-edge
sed -i 's/luci-theme-bootstrap/luci-theme-edge/g' feeds/luci/collections/luci-nginx/Makefile
sed -i 's/luci-theme-bootstrap/luci-theme-edge/g' feeds/luci/collections/luci-light/Makefile
