#!/bin/sh

set -e

log() {
    echo "[INFO] $*"
}

# 检测架构
ARCH="$(uname -m)"

log "更新软件包列表"
apt update

log "安装通用工具 (libarchive-tools)"
apt install libarchive-tools -y

if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "i386" ] || [ "$ARCH" = "amd64" ]; then
    log "检测到 x86 架构，安装 syslinux"
    apt install syslinux syslinux-utils syslinux-common isolinux -y
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    log "检测到 ARM64 架构，安装 GRUB 及相关工具"
    apt install grub-efi-arm64-bin syslinux-common isolinux -y
else
    echo "[ERROR] 不支持的架构: $ARCH"
    exit 1
fi

log "依赖安装完成"