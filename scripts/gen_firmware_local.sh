#!/usr/bin/bash
export DEVICE=x86
export BRANCH='master'
export GITHUB_WORKSPACE=~/actions-runner/_work/nanopi-openwrt/nanopi-openwrt
export BUILDLEAN='true'
export GITHUB_ENV=''

echo "Download ib and prepare environment..."
sudo apt update && sudo apt install qemu-utils
sudo sysctl vm.swappiness=0
ulimit -SHn 65000
curl -L https://github.com/aotsukiqx/nanopi-openwrt/releases/download/ib_cache/iblean-$DEVICE.tar.xz | tar -Jxvf -
mv *imagebuilder* ib && cd ib

echo 'Generating slim firmware...'
sed -i 's/$(OPKG) install $(BUILD_PACKAGES)/$(OPKG) install --force-overwrite $(BUILD_PACKAGES)/' Makefile
ls packages/*.ipk | xargs -n1 basename > package.files
PACKAGES=$(cat $GITHUB_WORKSPACE/$DEVICE.diffconfig | grep CONFIG_PACKAGE | grep -v CONFIG_PACKAGE_luci-app | sed 's/CONFIG_PACKAGE_//;s/=y//' | xargs -n1 -i grep -o {} package.files | sort -u | xargs echo)
PACKAGES="$PACKAGES `grep -o luci-i18n-opkg-zh-cn package.files || true`"
make image PACKAGES="$PACKAGES $LUCI $LP luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn -luci-app-ssr-plus -kmod-i40evf  -kmod-usb-audio -kmod-sound-via82xx -kmod-sound-i8x0 -kmod-sound-hda-intel -kmod-sound-hda-core -kmod-sound-hda-codec-via -kmod-sound-hda-codec-realtek -kmod-sound-hda-codec-hdmi"

mkdir -p $GITHUB_WORKSPACE/release
mv $(ls -1 ./bin/targets/*/*/*img.gz | head -1) $GITHUB_WORKSPACE/release/lean-$DEVICE-slim.img.gz
cd $GITHUB_WORKSPACE/release/ && md5sum lean-$DEVICE-slim.img.gz > lean-$DEVICE-slim.img.gz.md5
gzip -dc lean-$DEVICE-slim.img.gz | md5sum | sed "s/-/lean-$DEVICE-slim.img/" > lean-$DEVICE-slim.img.md5
echo "strDate=$(TZ=UTC-8 date +%Y-%m-%d)" >> $GITHUB_ENV
echo "strDevice=$(echo $DEVICE | awk '{print toupper($0)}')" >> $GITHUB_ENV