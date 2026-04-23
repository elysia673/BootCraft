#!/bin/sh

SD_BOOT=$(df | grep bootmnt | cut -f1 -d' ' | cut -c8)
echo Boot from: /dev/sd$SD_BOOT

SD_DISK=$(blkid | grep /dev/nvme | grep -v sd$SD_BOOT | cut -c-12 | uniq | cut -c12)
if [ -z "$SD_DISK" ] ; then
        SD_DISK=$(blkid | grep /dev/sd | grep -v sd$SD_BOOT | cut -c-8 | uniq | cut -c8)
        if [ -z "$SD_DISK" ] ; then
                echo "DISK NOT FOUND!"
                exit 1
        fi
        DEV=/dev/sd$SD_DISK
else
        DEV=/dev/nvme0n$SD_DISK
fi
echo Install to: $DEV

if ! parted -s $DEV mklabel gpt ; then
        echo Failed to create new gpt partition table
        exit 1
fi
echo Created new gpt partition table

if ! parted -s -- $DEV mkpart EFI fat32 2048s 1050623s ; then
        echo Failed to create EFI partition
fi
echo Create EFI partition

if ! parted -s -- $DEV mkpart ROOT ext4 1050624s -1024s ; then
        echo Failed to create ROOT partition
        exit 1
fi

#此处替换为你的 rootfs
ROOT_TAR="rootfs.tar.gz"
echo Create ROOT partition
if echo "$DEV" | grep -q nvme ; then
        echo Writing EFI partition: ${DEV}p1
        # 此处替换为你的 efi
        dd if="efi.img" of=${DEV}p1 bs=1M
        echo Writing ROOT partition: ${DEV}p2
        mkfs -t ext4 ${DEV}p2
        mkdir -p /tmproot
        mount ${DEV}p2 /tmproot
        tar -xf $ROOT_TAR -C /tmproot
        boot_part="${DEV}p1"
else
        echo Writing EFI partition: ${DEV}1
        # 此处替换为你的 efi
        dd if="efi.img" of=${DEV}1 bs=1M
        echo Writing ROOT partition: ${DEV}2
        mkfs -t ext4 ${DEV}2
        mkdir -p /tmproot
        mount ${DEV}2 /tmproot
        tar -xf $ROOT_TAR -C /tmproot
        boot_part="${DEV}1"
fi
cp install_2.sh /tmproot/bin/install_2.sh
chmod a+x /tmproot/bin/install_2.sh

echo ============== arch-chroot /install_2.sh ${boot_part} ===============
arch-chroot /tmproot /install_2.sh ${boot_part}

rm -f /tmproot/bin/install_2.sh

exit 0