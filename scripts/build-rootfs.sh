#!/bin/sh

set -e

# ===== 可配置变量 =====
DST_DISK="$DST_DISK"
if [ -z "$DST_DISK" ]; then
    DST_DISK="/dev/sda"
fi

EFI_DEV="$EFI_DEV"
# 如果未指定，稍后自动检测

OUT_DIR="$OUT_DIR"
if [ -z "$OUT_DIR" ]; then
    OUT_DIR="$HOME/backup"
fi

SRC_MOUNT="/mnt/tmp-root"
DST_MOUNT="/mnt/external-rootfs"

mkdir -p "$DST_MOUNT" "$SRC_MOUNT" "$OUT_DIR"

# ===== 自动检测 EFI 分区 =====
if [ -z "$EFI_DEV" ]; then
    if mountpoint -q /boot/efi; then
        EFI_DEV="$(df /boot/efi | tail -1 | awk '{print $1}')"
        echo "[INFO] 自动检测到 EFI 分区: $EFI_DEV"
    else
        echo "[ERROR] 未指定 EFI_DEV 且 /boot/efi 未挂载，请设置环境变量 EFI_DEV"
        exit 1
    fi
fi

# 记录 /boot/efi 原本是否已挂载
EFI_WAS_MOUNTED=0
if mountpoint -q /boot/efi; then
    EFI_WAS_MOUNTED=1
fi

# 清理函数
cleanup() {
    echo "[CLEANUP] 卸载临时挂载点..."
    # 卸载 DST_MOUNT（如果已挂载）
    if mountpoint -q "$DST_MOUNT"; then
        umount "$DST_MOUNT" 2>/dev/null || echo "[WARN] 无法卸载 $DST_MOUNT"
    fi
    # 卸载 SRC_MOUNT（如果已挂载）
    if mountpoint -q "$SRC_MOUNT"; then
        umount "$SRC_MOUNT" 2>/dev/null || echo "[WARN] 无法卸载 $SRC_MOUNT"
    fi
    # 恢复 EFI 挂载（如果原本是挂载的，且当前未挂载）
    if [ "$EFI_WAS_MOUNTED" -eq 1 ] && ! mountpoint -q /boot/efi; then
        echo "[CLEANUP] 重新挂载 /boot/efi 到 $EFI_DEV"
        mount "$EFI_DEV" /boot/efi 2>/dev/null || echo "[WARN] 无法重新挂载 /boot/efi，请手动执行: mount $EFI_DEV /boot/efi"
    fi
}

# 注册退出清理
trap cleanup EXIT HUP INT TERM

echo "[1/5] 挂载目标盘..."
mount "$DST_DISK" "$DST_MOUNT"

echo "[2/5] bind 挂载系统..."
mount --bind / "$SRC_MOUNT"

echo "[3/5] rsync 同步系统..."
rsync -aAXHv --delete \
  --exclude={"/proc/*","/sys/*","/dev/*","/run/*","/tmp/*","/mnt/*","/media/*","/lost+found"} \
  "$SRC_MOUNT/" "$DST_MOUNT/"

echo "[4/5] 备份 EFI..."
# 如果 /boot/efi 已挂载则临时卸载
if mountpoint -q /boot/efi; then
    umount /boot/efi
fi
dd if="$EFI_DEV" of="$OUT_DIR/efi.img" bs=1M status=progress

echo "[5/5] 打包 rootfs..."
cd "$DST_MOUNT"
tar --warning=no-file-changed -czpf "$OUT_DIR/rootfs.tar.gz" .

echo "完成！输出目录：$OUT_DIR"
