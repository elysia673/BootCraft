#!/bin/sh

set -eu

# ===== 基础 =====
LOCAL="$(mktemp -d)"
trap 'rm -rf "$LOCAL"' EXIT

log() {
    echo "[INFO] $*"
}

quit() {
    echo "[ERROR] $*" >&2
    exit 1
}

# ===== 参数 =====
DEV="$1"

if [ -z "$DEV" ]; then
    quit "用法: $0 /dev/sdX"
fi

if [ "$(id -u)" != "0" ]; then
    quit "必须由 root 用户执行"
fi

if [ ! -b "$DEV" ]; then
    quit "不是块设备: $DEV"
fi

# ===== 默认参数 =====
ISO="$ISO"
if [ -z "$ISO" ]; then
    ISO="./os.iso"
    log "使用默认 ISO: $ISO"
fi

DATA_DIR="$DATA_DIR"
if [ -z "$DATA_DIR" ]; then
    DATA_DIR="./data"
    log "使用默认 DATA_DIR: $DATA_DIR"
fi

if [ ! -f "$ISO" ]; then
    quit "ISO 不存在: $ISO"
fi

if [ ! -d "$DATA_DIR" ]; then
    quit "DATA_DIR 不存在: $DATA_DIR"
fi

# ===== 防误删 =====
ROOT_DEV="$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')"

if [ "$DEV" = "$ROOT_DEV" ]; then
    quit "禁止操作当前系统盘: $DEV"
fi

# 检查是否挂载
if mount | grep -q "^$DEV"; then
    quit "设备已挂载: $DEV"
fi

# ===== 二次确认 =====
echo "⚠️ 警告: 将清空设备 $DEV"
echo "输入 YES 继续:"
read CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    quit "用户取消"
fi

# ===== 分区 =====
log "创建 GPT 分区表"
parted -s "$DEV" mklabel gpt || quit "创建分区表失败"

log "创建 EFI 分区"
parted -s "$DEV" mkpart EFI fat32 1MiB 1025MiB || quit "创建 EFI 分区失败"

log "创建数据分区"
parted -s "$DEV" mkpart DATA ext4 1025MiB 100% || quit "创建数据分区失败"

partprobe "$DEV"

BOOT_PART="${DEV}1"
DATA_PART="${DEV}2"

# ===== 格式化 =====
log "格式化 EFI 分区"
mkfs.fat -F 32 "$BOOT_PART" || quit "格式化失败"

log "格式化 DATA 分区"
mkfs.ext4 -F "$DATA_PART" || quit "格式化失败"

# ===== 写入系统 =====
mkdir -p "$LOCAL/mnt"

log "挂载 EFI 分区"
mount "$BOOT_PART" "$LOCAL/mnt" || quit "挂载失败"

log "解压 ISO"
bsdtar -x -f "$ISO" -C "$LOCAL/mnt" || quit "解压失败"

umount "$LOCAL/mnt"

# ===== 安装 bootloader =====
log "安装 syslinux"
syslinux -f --directory boot/syslinux --install "$BOOT_PART" || quit "安装失败"

log "写入 MBR"
dd bs=440 count=1 conv=notrunc \
    if=/usr/lib/syslinux/mbr/gptmbr.bin \
    of="$DEV" || quit "写入 MBR 失败"

# ===== 写入数据 =====
log "写入数据分区"
mount "$DATA_PART" "$LOCAL/mnt" || quit "挂载失败"

cp -a "$DATA_DIR"/* "$LOCAL/mnt/" || quit "复制失败"

umount "$LOCAL/mnt"

sync

log "完成 ✔"
exit 0