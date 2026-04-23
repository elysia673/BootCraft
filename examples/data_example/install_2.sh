#!/bin/sh

DEV="$1"

if [ -z "$DEV" ]; then
    echo "用法: $0 /dev/sdX1  (EFI 分区设备)"
    exit 1
fi

mount "$DEV" /boot/efi

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)
        TARGET="x86_64-efi"
        ;;
    aarch64|arm64)
        TARGET="arm64-efi"
        ;;
    *)
        echo "不支持的架构: $ARCH"
        umount /boot/efi
        exit 1
        ;;
esac

grub-install --target="$TARGET" --bootloader-id=GRUB --efi-directory=/boot/efi

grub-mkconfig -o /boot/grub/grub.cfg

umount /boot/efi
exit 0