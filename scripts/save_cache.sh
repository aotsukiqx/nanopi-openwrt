# set env:
GITHUB_ENV=''
DEVICE=x86
BRANCH="master"


echo "Save cache state"
cd
sleep 60
sudo mount -o remount,compress=no,nodatacow,nodatasum lede
cd lede/; pv /dev/zero > zerospace || true; sync; rm -f zerospace; cd -
sleep 60
sudo umount lede
sudo losetup -d $LOOP_DEVICE
export AUTH="Authorization: token ${{ secrets.SEC_TOKEN }}"
export cache_path='github.com/repos/aotsukiqx/nanopi-openwrt/releases'
export cache_repo_id='56878497'
zstdmt -c --long lede.img | split --numeric=1 -b 2000m - lede.$DEVICE.img.zst.
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