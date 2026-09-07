#!/bin/sh

LOCAL=$(mktemp -d)
trap 'umount "$LOCAL/mnt" 2>/dev/null; rm -rf "$LOCAL"' EXIT

quit() {
        echo "$1" >&2
        exit 1
}

DEV="$1"

[ "$(id -u)" = 0 ] || quit "必须由root用户执行"
[ -n "$DEV" ] || quit "必须指定设备"
[ -b "$DEV" ] || quit "必须指定一个块设备"

mount | grep -q "^$DEV[[:space:]]" && quit "指定块设备已被挂载"

parted -s -- "$DEV" mklabel gpt || quit "创建分区表失败"
parted -s -- "$DEV" mkpart ARCH_202005 fat32 63s 2100000s \
        || quit "创建1G系统分区失败"
parted -s -- "$DEV" mkpart DATA ext4 2100001s -1024s \
        || quit "创建数据分区失败"

partprobe "$DEV" || quit "重新读取分区表失败"

mkfs.fat -F 32 "${DEV}1" || quit "格式化1G系统分区失败"
mkfs.ext4 "${DEV}2" || quit "格式化数据分区失败"

mkdir -p "$LOCAL/mnt" || quit "创建临时挂载目录失败"

mount "${DEV}1" "$LOCAL/mnt" || quit "mount 1G系统分区失败"

[ -f archlinux-2020.05.01-x86_64.iso ] \
        || quit "找不到 archlinux-2020.05.01-x86_64.iso"

bsdtar -x -v \
        -f archlinux-2020.05.01-x86_64.iso \
        -C "$LOCAL/mnt" \
        || quit "刷进系统分区失败"

umount "$LOCAL/mnt" || quit "卸载1G系统分区失败"

syslinux -f \
        --directory boot/syslinux \
        --install "${DEV}1" \
        || quit "安装SYSLINUX失败"

[ -f /usr/lib/syslinux/mbr/gptmbr.bin ] \
        || quit "找不到 gptmbr.bin"

dd bs=440 count=1 conv=notrunc \
        if=/usr/lib/syslinux/mbr/gptmbr.bin \
        of="$DEV" \
        || quit "刷进mbr失败"

mount "${DEV}2" "$LOCAL/mnt" || quit "mount 数据分区失败"

[ -d data ] || quit "找不到 data 目录"

cp -vrp data/. "$LOCAL/mnt/" || quit "复制数据失败"

umount "$LOCAL/mnt" || quit "卸载数据分区失败"

sync
exit 0
