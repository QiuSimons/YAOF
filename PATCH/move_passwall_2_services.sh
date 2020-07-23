
#!/bin/bash
# From: QiuSimons

lua_file="$({ find |grep "\.lua"; } 2>"/dev/null")"
for a in ${lua_file}
do
	[ -n "$(grep '"vpn"' "$a")" ] && sed -i 's,"vpn","services",g' "$a"
	[ -n "$(grep '"VPN"' "$a")" ] && sed -i 's,"VPN","services",g' "$a"
	[ -n "$(grep '\[\[vpn\]\]' "$a")" ] && sed -i 's,\[\[vpn\]\],\[\[services\]\],g' "$a"
	[ -n "$(grep 'admin/vpn' "$a")" ] && sed -i 's,admin/vpn,admin/services,g' "$a"
done

htm_file="$({ find |grep "\.htm"; } 2>"/dev/null")"
for b in ${htm_file}
do
	[ -n "$(grep '"vpn"' "$b")" ] && sed -i 's,"vpn","services",g' "$b"
	[ -n "$(grep '"VPN"' "$b")" ] && sed -i 's,"VPN","services",g' "$b"
	[ -n "$(grep '\[\[vpn\]\]' "$b")" ] && sed -i 's,\[\[vpn\]\],\[\[services\]\],g' "$b"
	[ -n "$(grep 'admin/vpn' "$b")" ] && sed -i 's,admin/vpn,admin/services,g' "$b"
done
