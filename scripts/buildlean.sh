#!/usr/bin/bash
export DEVICE=x86
export BRANCH='master'
export GITHUB_WORKSPACE=~/actions-runner/_work/nanopi-openwrt/nanopi-openwrt
export BUILDLEAN='true'

echo "Cleaning up previous run"
sudo apt update;
sudo apt -y --no-upgrade --no-install-recommends install parallel pv jq build-essential zstd xz-utils cmake asciidoc binutils bzip2 gawk gettext git libncurses5-dev libz-dev patch unzip zlib1g-dev lib32gcc1 libc6-dev-i386 subversion flex uglifyjs git-core gcc-multilib g++-multilib p7zip p7zip-full msmtp libssl-dev texinfo libreadline-dev libglib2.0-dev xmlto qemu-utils upx libelf-dev autoconf automake libtool autopoint ccache curl wget vim nano python2.7 python3 python3-pip python-ply python3-ply haveged lrzsz device-tree-compiler scons antlr3 gperf intltool mkisofs rsync swig
sudo rm -rf /usr/share/dotnet /usr/local/lib/android/sdk
sudo sysctl vm.swappiness=0
cd
umount lean || true
rm -rf  iblean-$DEVICE.tar.xz lean.* luci bin || true

echo "Download building img"
echo "Using image: $DEVICE"
for i in {1..20}
do
  curl -sL --fail https://github.com/aotsukiqx/nanopi-openwrt/releases/download/ib_cache/lean.$DEVICE.img.zst.0$i || break
done | zstdmt -d -o lean.img || (truncate -s 40g lean.img && mkfs.btrfs -M lean.img)
LOOP_DEVICE=$(losetup -f) && echo "LOOP_DEVICE=$LOOP_DEVICE" >> $GITHUB_ENV
sudo losetup -P --direct-io $LOOP_DEVICE lean.img
mkdir lean && sudo mount -o nossd,compress=zstd $LOOP_DEVICE lean
BRANCH="master"
if [ -d 'lean/.git' ]; then
  cd ~
  sudo chown -R $USER:$(id -gn) lean
  cd lean && sudo rm -f zerospace && git config --local user.email "action@github.com" && git config --local user.name "GitHub Action"
  git fetch && git reset --hard origin/$BRANCH
else
  echo "Checkout lede and chown"
  cd ~
  sudo chown $USER:$(id -gn) lean && git clone -b $BRANCH --single-branch https://github.com/coolsnowwolf/lede lean
fi

echo "Update feeds and packages"
cd ~/lean
if [ -d 'feeds' ]; then
  pushd feeds/packages; git restore .; popd
  pushd feeds/luci; git restore .; popd
  pushd feeds/routing; git restore .; popd
  pushd feeds/telephony; git restore .; popd
fi
./scripts/feeds update -a
./scripts/feeds install -f -a
echo "Merge packages & patches..."
# . $GITHUB_WORKSPACE/scripts/merge_packages.sh
# . $GITHUB_WORKSPACE/scripts/patches.sh
cd
BRANCH='master'
svn export https://github.com/openwrt/luci/branches/$BRANCH luci

echo "Custom configure file"
cd ~/lean && rm -rf .tmp/
cat $GITHUB_WORKSPACE/$DEVICE.diffconfig > .config
make defconfig
cat .config

echo "Clean build cache"
cd ~/lean
df -h .
make package/clean
df -h .

echo "Build and deploy packages"
ulimit -SHn 65000
cd ~/lean
while true; do make download -j6 && break || true; done
make -j$[`nproc`+1] IGNORE_ERRORS=1
# make -j1 V=s IGNORE_ERRORS=1
if [ ! -e ~/lean/bin/targets/*/*/*imagebuilder*xz ]; then make V=sc; fi
mv `ls ~/lean/bin/targets/*/*/*imagebuilder*xz` ~/iblean-$DEVICE.tar.xz

echo "======================="
echo "Space usage:"
echo "======================="
df -h
echo "======================="
du -h --max-depth=1 ./ --exclude=build_dir --exclude=bin
du -h --max-depth=1 ./build_dir
du -h --max-depth=1 ./bin
    
echo "Clean build cache"
cd ~/lean
df -h .
make package/clean
df -h .

echo "Prepare artifact"
cd
mkdir -p ./artifact/buildinfo
cd lean
cp -rf $(find ./bin/targets/ -type f -name "*.buildinfo" -o -name "*.manifest") ../artifact/buildinfo/
cp -rf .config ../artifact/buildinfo/
#echo "strDate=$(TZ=UTC-8 date +%Y-%m-%d)" >> $GITHUB_ENV
#echo "strDevice=$(echo $DEVICE | awk '{print toupper($0)}')" >> $GITHUB_ENV
mv bin ~/
rm -rf bin tmp
cd ..
rm -rf $GITHUB_WORKSPACE/artifact
mv artifact $GITHUB_WORKSPACE

echo "Save cache state"
cd
sleep 60
sudo mount -o remount,compress=no,nodatacow,nodatasum lean
cd lean/; pv /dev/zero > zerospace || true; sync; rm -f zerospace; cd -
sleep 60
sudo umount lean
sudo losetup -d $LOOP_DEVICE
export AUTH="Authorization: token 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"
export cache_path='github.com/repos/aotsukiqx/nanopi-openwrt/releases'
export cache_repo_id='56878497'
#zstdmt -c --adapt --long lean.img | parallel --wc --block 1.99G --pipe \
#'curl -s --data-binary @- -H "$AUTH" -H "Content-Type: application/octet-stream" https://uploads.$cache_path/$cache_repo_id/assets?name=lean.'$DEVICE'.img.zst.0{#} > /dev/null'
zstdmt -c --long lean.img | split --numeric=1 -b 2000m - lean.$DEVICE.img.zst.
#for f in *img.zst*
#do
#  while true; do curl --data-binary @$f -H "$AUTH" -H 'Content-Type: application/octet-stream' "https://uploads.$cache_path/$cache_repo_id/assets?name=$f" && break || true; done
#done
while true; do
ret=$(curl -sH "$AUTH" "https://api.$cache_path/tags/ib_cache")
echo $ret | jq -r '.assets[] | select(.name | contains ("lean.'$DEVICE'.img")).id' | \
xargs -n1 -i curl -X DELETE -H "$AUTH" "https://api.$cache_path/assets/{}"
echo $ret | jq -r '.assets[] | select(.name == "iblean-'$DEVICE'.tar.xz").id' | \
xargs -n1 -i curl -X DELETE -H "$AUTH" "https://api.$cache_path/assets/{}"
ls *img.zst* iblean-$DEVICE.tar.xz | parallel --wc 'while true; do curl -T {} -H "$AUTH" -H "Content-Type: application/octet-stream" "https://uploads.$cache_path/$cache_repo_id/assets?name={}" && break || true; done'
set +e
for i in {1..20}; do curl -sL --fail https://github.com/aotsukiqx/nanopi-openwrt/releases/download/ib_cache/lean.$DEVICE.img.zst.0$i || break; done | zstdmt -d -o /dev/null
if [ $? -eq 0 ]; then break; fi
done
set -e

