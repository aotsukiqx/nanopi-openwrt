#!/bin/bash

scp -r /etc/dropbear/ root@192.168.2.9:/etc/dropbear/
scp /etc/config/passwall root@192.168.2.9:/etc/config/
scp /etc/config/passwall_server root@192.168.2.9:/etc/config/
scp /etc/config/passwall_show root@192.168.2.9:/etc/config/
scp /etc/apcupsd/apcupsd.conf root@192.168.2.9:/etc/apcupsd/
scp /etc/config/uhttpd root@192.168.2.9:/etc/config/
scp /etc/config/cifs root@192.168.2.9:/etc/config/
scp /etc/config/dhcp root@192.168.2.9:/etc/config/
scp /etc/config/zerotier root@192.168.2.9:/etc/config/
scp -r /etc/config/zero root@192.168.2.9:/etc/config/
scp /etc/v2ray/config.json root@192.168.2.9:/etc/v2ray/config.json
scp -r /root/heimdall root@192.168.2.9:/root/heimdall
scp -r /root/v2s_cert root@192.168.2.9:/root/v2s_cert
scp -r /root/docker-baseimage-ubuntu-bionic root@192.168.2.9:/root/docker-baseimage-ubuntu-bionic