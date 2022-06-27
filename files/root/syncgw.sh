#!/bin/bash
# 脚本在GW上执行，新刷好的GW在192.168.2.9
# Steps：
# 1. 新GW本地修改静态LAN IP
# 2. 连接LAN，登录在线GW执行本脚本
# 3. 重启新GW并修改LAN IP和配置WAN口拨号
# 4. 替换GW并部署Heimdall

scp -r /etc/dropbear/ root@192.168.2.9:/etc/dropbear/
scp /etc/github.hosts root@192.168.2.9:/etc/
scp /etc/config/passwall root@192.168.2.9:/etc/config/
scp /etc/config/passwall_server root@192.168.2.9:/etc/config/
scp /etc/config/passwall_show root@192.168.2.9:/etc/config/
scp -r /usr/share/passwall/rules root@192.168.2.9:/usr/share/passwall
scp -r /usr/bin/v2ray root@192.168.2.9:/usr/bin/
scp /etc/apcupsd/apcupsd.conf root@192.168.2.9:/etc/apcupsd/
scp /etc/syslog-ng.conf root@192.168.2.9:/etc/
scp /etc/config/uhttpd root@192.168.2.9:/etc/config/
scp /etc/config/autoreboot root@192.168.2.9:/etc/config/
scp /etc/config/cifs root@192.168.2.9:/etc/config/
scp /etc/config/dhcp root@192.168.2.9:/etc/config/
scp /etc/config/zerotier root@192.168.2.9:/etc/config/
scp /etc/config/bandwidthd root@192.168.2.9:/etc/config/
scp /etc/crontabs/root root@192.168.2.9:/etc/crontabs
scp -r /etc/config/zero root@192.168.2.9:/etc/config/
scp /etc/v2ray/config.json root@192.168.2.9:/etc/v2ray/config.json
scp -r /root/heimdall root@192.168.2.9:/root/
scp -r /root/v2s_cert root@192.168.2.9:/root/
scp -r /root/docker-baseimage-ubuntu-bionic root@192.168.2.9:/root/