# set env:
GITHUB_WORKSPACE=$(pwd)
GITHUB_ENV=''
DEVICE=r4s
BRANCH="master"

echo "Prepare env"
cd $GITHUB_WORKSPACE
# mkdir -p $GITHUB_WORKSPACE
if [ -d $GITHUB_WORKSPACE ]; then
git clone -b $BRANCH --single-branch https://github.com/aotsukiqx/nanopi-openwrt $GITHUB_WORKSPACE
fi
sudo apt update;
sudo apt -y --no-upgrade --no-install-recommends install pv jq build-essential zstd cmake asciidoc binutils bzip2 gawk gettext git libncurses5-dev libz-dev patch unzip zlib1g-dev lib32gcc1 libc6-dev-i386 subversion flex uglifyjs git-core gcc-multilib g++-multilib p7zip p7zip-full msmtp libssl-dev texinfo libreadline-dev libglib2.0-dev xmlto qemu-utils upx libelf-dev autoconf automake libtool autopoint ccache curl wget vim nano python2.7 python3 python3-pip python-ply python3-ply haveged lrzsz device-tree-compiler scons antlr3 gperf intltool mkisofs rsync swig
sudo rm -rf /usr/share/dotnet /usr/local/lib/android/sdk
sudo sysctl vm.swappiness=0

echo "Checkout..."
cd $GITHUB_WORKSPACE
curl -sL https://raw.githubusercontent.com/klever1988/nanopi-openwrt/zstd-bin/zstd | sudo tee /usr/bin/zstd > /dev/null
for i in {1..20}
do
curl -sL --fail https://github.com/klever1988/sshactions/releases/download/cache/lede.$DEVICE.img.zst.0$i || break
done | zstdmt -d -o lede.img || (truncate -s 40g lede.img && mkfs.btrfs -M lede.img)
LOOP_DEVICE=$(losetup -f) && echo "LOOP_DEVICE=$LOOP_DEVICE" >> $GITHUB_ENV
sudo losetup -P --direct-io $LOOP_DEVICE lede.img
mkdir lede && sudo mount -o nossd,compress=zstd $LOOP_DEVICE lede
BRANCH="master"
if [ -d 'lede/.git' ]; then
echo "feteching origin/$BRANCH"
cd lede && rm -f zerospace && git config --local user.email "action@github.com" && git config --local user.name "GitHub Action"
git fetch && git reset --hard origin/$BRANCH
else
echo "Checkout imortalwrt and chown"
sudo chown $USER:$(id -gn) lede && git clone -b $BRANCH --single-branch https://github.com/immortalwrt/immortalwrt lede
fi

echo "Update feeds and packages"
cd ~/lede
if [ -d 'feeds' ]; then
pushd feeds/packages; git restore .; popd
pushd feeds/luci; git restore .; popd
pushd feeds/routing; git restore .; popd
pushd feeds/telephony; git restore .; popd
fi
./scripts/feeds update -a
./scripts/feeds install -a
. $GITHUB_WORKSPACE/scripts/merge_packages.sh
. $GITHUB_WORKSPACE/scripts/patches.sh
cd
BRANCH="master"
svn export https://github.com/openwrt/luci/branches/$BRANCH luci
pushd luci
ls -d */ | xargs -n1 -i diff -q {} ../lede/feeds/luci/{} | grep Only | grep lede | grep -E applications\|themes | awk '{print $4}' | xargs -n1 -i echo CONFIG_PACKAGE_{}=m > ~/lede/more_luci.txt
popd

echo "Custom configure file"
cd ~/lede
sed -i 's/KERNEL_PATCHVER\=5\.4/KERNEL_PATCHVER\=5\.10/g' target/linux/rockchip/Makefile
sed -i 's/KERNEL_TESTING_PATCHVER\=5\.10/KERNEL_TESTING_PATCHVER\=5\.15/g' target/linux/rockchip/Makefile
cat $GITHUB_WORKSPACE/$DEVICE.config.seed $GITHUB_WORKSPACE/common.seed | sed 's/\(CONFIG_PACKAGE_luci-app-[^A-Z]*=\)y/\1m/' > .config
find package/ -type d -name luci-app-* | rev | cut -d'/' -f1 | rev | xargs -n1 -i echo CONFIG_PACKAGE_{}=m >> .config
cat $GITHUB_WORKSPACE/extra_packages.seed >> .config
cat more_luci.txt >> .config
make defconfig && sed -i -E 's/# (CONFIG_.*_COMPRESS_UPX) is not set/\1=y/' .config && make defconfig
cat .config

echo "Clean build cache"
# if: ${{ github.event.client_payload.package_clean == 'true' || github.event.inputs.device != '' }}
cd ~/lede
df -h .
make package/clean
df -h .

echo "Build and deploy packages"
ulimit -SHn 65000
cd ~/lede
while true; do make download -j && break || true; done
make -j$[`nproc`+1] IGNORE_ERRORS=1
mv `ls ~/lede/bin/targets/*/*/*imagebuilder*xz` ~/ib-$DEVICE.tar.xz

echo "======================="
echo "Space usage:"
echo "======================="
df -h
echo "======================="
du -h --max-depth=1 ./ --exclude=build_dir --exclude=bin
du -h --max-depth=1 ./build_dir
du -h --max-depth=1 ./bin
          
echo "Clean build cache"
#if: ${{ github.event.client_payload.package_clean == 'true' }}
cd ~/lede
df -h .
make package/clean
df -h .

echo "Prepare artifact"
cd $GITHUB_WORKSPACE
mkdir -p ./artifact/buildinfo
cd lede
cp -rf $(find ./bin/targets/ -type f -name "*.buildinfo" -o -name "*.manifest") ../artifact/buildinfo/
cp -rf .config ../artifact/buildinfo/
echo "strDate=$(TZ=UTC-8 date +%Y-%m-%d)" >> $GITHUB_ENV
echo "strDevice=$(echo $DEVICE | awk '{print toupper($0)}')" >> $GITHUB_ENV
rm -rf bin tmp
cd ..
mv artifact $GITHUB_WORKSPACE

echo "Deliver buildinfo"
#uses: actions/upload-artifact@v2
#with:
#  name: OpenWrt_buildinfo
#  path: ./artifact/buildinfo/

echo "Save cache state"
#if: env.TG
cd $GITHUB_WORKSPACE
sleep 60
sudo mount -o remount,compress=no,nodatacow,nodatasum lede
cd lede/; pv /dev/zero > zerospace || true; sync; rm -f zerospace; cd -
sleep 60
sudo umount lede
sudo losetup -d $LOOP_DEVICE
export AUTH="Authorization: token ${{ secrets.SEC_TOKEN }}"
export cache_path='github.com/repos/aotsukiqx/nanopi-openwrt/releases'
export cache_repo_id='56878497'
#zstdmt -c --adapt --long lede.img | parallel --wc --block 1.99G --pipe \
#'curl -s --data-binary @- -H "$AUTH" -H "Content-Type: application/octet-stream" https://uploads.$cache_path/$cache_repo_id/assets?name=lede.'$DEVICE'.img.zst.0{#} > /dev/null'
zstdmt -c --long lede.img | split --numeric=1 -b 2000m - lede.$DEVICE.img.zst.
#for f in *img.zst*
#do
#  while true; do curl --data-binary @$f -H "$AUTH" -H 'Content-Type: application/octet-stream' "https://uploads.$cache_path/$cache_repo_id/assets?name=$f" && break || true; done
#done
while true; do
ret=$(curl -sH "$AUTH" "https://api.$cache_path/tags/ib_cache")
echo $ret | jq -r '.assets[] | select(.name | contains ("'$DEVICE'.img")).id' | \
xargs -n1 -i curl -X DELETE -H "$AUTH" "https://api.$cache_path/assets/{}"
echo $ret | jq -r '.assets[] | select(.name == "ib-'$DEVICE'.tar.xz").id' | \
xargs -n1 -i curl -X DELETE -H "$AUTH" "https://api.$cache_path/assets/{}"
ls *img.zst* ib-$DEVICE.tar.xz | parallel --wc 'while true; do curl -T {} -H "$AUTH" -H "Content-Type: application/octet-stream" "https://uploads.$cache_path/$cache_repo_id/assets?name={}" && break || true; done'
set +e
for i in {1..20}; do curl -sL --fail https://github.com/aotsukiqx/nanopi-openwrt/releases/download/ib_cache/lede.$DEVICE.img.zst.0$i || break; done | zstdmt -d -o /dev/null
if [ $? -eq 0 ]; then break; fi
done
set -e

echo "Send tg notification"
#if: env.TG
#curl -k --data chat_id="${{secrets.TELEGRAM_CHAT_ID}}" --data "text=The ${{env.DEVICE}} build ran completed at ${{job.status}}." "https://api.telegram.org/bot${{secrets.TELEGRAM_BOT_TOKEN}}/sendMessage"

echo "Debug via tmate"
#uses: klever1988/ssh2actions@main
#if: ${{ failure() && env.TG }}
#with:
#  mode: ssh
#env:
#  TELEGRAM_BOT_TOKEN: ${{ secrets.TELEGRAM_BOT_TOKEN }}
#  TELEGRAM_CHAT_ID: ${{ secrets.TELEGRAM_CHAT_ID }}
#  SSH_PASSWORD: ${{secrets.SSH_PASSWORD}}
#  SSH_PUBKEY: ${{secrets.SSH_PUBKEY}}
#  NGROK_TOKEN: ${{secrets.TUNNEL_KEY}}
#  TUNNEL_HOST: ${{secrets.TUNNEL_HOST}}

#generate_slim_firmware:
#  needs: build_packages
#  name: Generate ${{ github.event.client_payload.device || github.event.inputs.device }} slim firmware
#  runs-on: ubuntu-20.04 # ubuntu-20.04
#  env:
#    DEVICE: ${{ github.event.client_payload.device || github.event.inputs.device }}
#    BRANCH: master
#  steps:
#
#    - uses: actions/checkout@v2
#      with:
#        fetch-depth: 1
#
#    - name: Generate firmware
#      run: |
#        sudo apt update && sudo apt install qemu-utils
#        sudo sysctl vm.swappiness=0
#        ulimit -SHn 65000
#        curl -L https://github.com/klever1988/sshactions/releases/download/cache/ib-$DEVICE.tar.xz | tar -Jxvf -
#        mv *imagebuilder* ib && cd ib
#        . $GITHUB_WORKSPACE/scripts/merge_files.sh
#        mkdir -p files/local_feed && sudo mount --bind packages files/local_feed
#        sed -i 's/luci-app-[^ ]*//g' include/target.mk $(find target/ -name Makefile)
#        sed -i 's/$(OPKG) install $(BUILD_PACKAGES)/$(OPKG) install --force-overwrite $(BUILD_PACKAGES)/' Makefile
#        ls packages/*.ipk | xargs -n1 basename > package.files
#        PACKAGES=$(cat $GITHUB_WORKSPACE/$DEVICE.config.seed $GITHUB_WORKSPACE/common.seed | grep CONFIG_PACKAGE | grep -v CONFIG_PACKAGE_luci-app | sed 's/CONFIG_PACKAGE_//;s/=y//' | xargs -n1 -i grep -o {} package.files | sort -u | xargs echo)
#        PACKAGES="$PACKAGES `grep -o luci-i18n-opkg-zh-cn package.files || true`"
#        make image PACKAGES="$PACKAGES $LUCI $LP luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn" FILES="files"
#
#        mkdir -p $GITHUB_WORKSPACE/release
#        mv $(ls -1 ./bin/targets/*/*/*img.gz | head -1) $GITHUB_WORKSPACE/release/$DEVICE-slim.img.gz
#        cd $GITHUB_WORKSPACE/release/ && md5sum $DEVICE-slim.img.gz > $DEVICE-slim.img.gz.md5
#        gzip -dc $DEVICE-slim.img.gz | md5sum | sed "s/-/$DEVICE-slim.img/" > $DEVICE-slim.img.md5
#        echo "strDate=$(TZ=UTC-8 date +%Y-%m-%d)" >> $GITHUB_ENV
#        echo "strDevice=$(echo $DEVICE | awk '{print toupper($0)}')" >> $GITHUB_ENV

#name: Upload release asset
#uses: svenstaro/upload-release-action@v2
#with:
#  repo_token: ${{ secrets.GITHUB_TOKEN }}
#  file: ./release/*
#  tag: ${{env.strDate}}.${{env.BRANCH}}
#  file_glob: true
#  overwrite: true
#  release_name: ${{env.strDate}} ${{env.BRANCH}} 自动发布

echo "generate_firmware:"
cd $GITHUB_WORKSPACE
sudo apt update && sudo apt install qemu-utils
sudo sysctl vm.swappiness=0
ulimit -SHn 65000
curl -L https://github.com/klever1988/sshactions/releases/download/cache/ib-$DEVICE.tar.xz | tar -Jxvf -
set -x
mv *imagebuilder* ib && cd ib
. $GITHUB_WORKSPACE/scripts/merge_files.sh
sed -i '/local/d;s/#//' files/etc/opkg/distfeeds.conf
sed -i 's/luci-app-[^ ]*//g' include/target.mk $(find target/ -name Makefile)
sed -i 's/$(OPKG) install $(BUILD_PACKAGES)/$(OPKG) install --force-overwrite $(BUILD_PACKAGES)/' Makefile
ls packages/*.ipk | xargs -n1 basename > package.files
PACKAGES=$(cat $GITHUB_WORKSPACE/$DEVICE.config.seed $GITHUB_WORKSPACE/common.seed | grep CONFIG_PACKAGE | grep -v CONFIG_PACKAGE_luci-app | sed 's/CONFIG_PACKAGE_//;s/=y//' | xargs -n1 -i grep -o {} package.files | sort -u | xargs echo)
PACKAGES="$PACKAGES `grep -o luci-i18n-opkg-zh-cn package.files || true`"
LUCI=$(cat $GITHUB_WORKSPACE/$DEVICE.config.seed $GITHUB_WORKSPACE/common.seed | grep CONFIG_PACKAGE_luci-app | grep -v docker | sed 's/CONFIG_PACKAGE_//;s/=y//' | xargs -n1 -i grep -o {} package.files | sort -u | xargs echo)
LP=$(echo $LUCI | sed 's/-app-/-i18n-/g;s/ /\n/g' | xargs -n1 -i grep -o {}-zh-cn package.files | xargs echo)
make image PACKAGES="$PACKAGES $LUCI $LP luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn" FILES="files"

mkdir -p $GITHUB_WORKSPACE/release
mv $(ls -1 ./bin/targets/*/*/*img.gz | head -1) $GITHUB_WORKSPACE/release/$DEVICE.img.gz
cd $GITHUB_WORKSPACE/release/ && md5sum $DEVICE.img.gz > $DEVICE.img.gz.md5
gzip -dc $DEVICE.img.gz | md5sum | sed "s/-/$DEVICE.img/" > $DEVICE.img.md5
echo "strDate=$(TZ=UTC-8 date +%Y-%m-%d)" >> $GITHUB_ENV
echo "strDevice=$(echo $DEVICE | awk '{print toupper($0)}')" >> $GITHUB_ENV

#if [[ ${{ github.event.client_payload.device || github.event.inputs.device }} == *"r1s"* ]]; then
#  exit 0
#fi
cd $GITHUB_WORKSPACE/ib
rm -rf bin/
LUCI=$(cat $GITHUB_WORKSPACE/$DEVICE.config.seed $GITHUB_WORKSPACE/common.seed | grep CONFIG_PACKAGE_luci-app | sed 's/CONFIG_PACKAGE_//;s/=y//' | xargs -n1 -i grep -o {} package.files | sort -u | xargs echo)
LP=$(echo $LUCI | sed 's/-app-/-i18n-/g;s/ /\n/g' | xargs -n1 -i grep -o {}-zh-cn package.files | xargs echo | xargs echo)
make image PACKAGES="$PACKAGES $LUCI $LP luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn" FILES="files"
mv $(ls -1 ./bin/targets/*/*/*img.gz | head -1) $GITHUB_WORKSPACE/release/$DEVICE-with-docker.img.gz
cd $GITHUB_WORKSPACE/release/ && md5sum $DEVICE-with-docker.img.gz > $DEVICE-with-docker.img.gz.md5
gzip -dc $DEVICE-with-docker.img.gz | md5sum | sed "s/-/$DEVICE-with-docker.img/" > $DEVICE-with-docker.img.md5

#name: Upload release asset
#uses: svenstaro/upload-release-action@v2
#with:
#  repo_token: ${{ secrets.GITHUB_TOKEN }}
#  file: ./release/*
#  tag: ${{env.strDate}}.${{env.BRANCH}}
#  file_glob: true
#  overwrite: true
#  release_name: ${{env.strDate}} ${{env.BRANCH}} 自动发布
