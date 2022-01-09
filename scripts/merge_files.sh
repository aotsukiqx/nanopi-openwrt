echo "Merging files..\n"
echo "pwd:$(pwd)"
mkdir -p $GITHUB_WORKSPACE/files/opt/kodexplorer
pushd $GITHUB_WORKSPACE/files/opt/kodexplorer; wget https://static.kodcloud.com/update/download/kodbox.1.26.zip; unzip kodbox.1.26.zip; rm -r kodbox.1.26.zip; popd
chmod 600 $GITHUB_WORKSPACE/files/opt/kodexplorer 

echo "Moving files"
mv $GITHUB_WORKSPACE/files ./
chmod 600 files/etc/dropbear/*
eval `cat .config | grep \" | head -n 10`
. files/etc/opkg/distfeeds.conf | tee files/etc/opkg/distfeeds.conf

echo 'iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 53' >> files/etc/firewall.user
echo 'iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 53' >> files/etc/firewall.user
echo '[ -n "$(command -v ip6tables)" ] && ip6tables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 53' >> files/etc/firewall.user
echo '[ -n "$(command -v ip6tables)" ] && ip6tables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 53' >> files/etc/firewall.user
