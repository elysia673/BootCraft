# BootCraft 

一个用于将 定制 系统部署到 U 盘并实现自动初始化的工具。

---

## 📦 项目结构

```
.
├── scripts/
├── docs/
├── examples/
```

---

## 🚀 使用方法

### 0. 先使用 scripts/init.sh 获取工具
* sudo scripts/init.sh

### 1. 准备 rootfs 和 EFI
⚠️ 注意：这里需要外置一个存储设备，不然会导致循环打包，然后我默认外置存储设备为sda，数据存储设备为 nvme

参考：

* docs/design.md
* sudo scripts/build-rootfs.sh

---

### 2. 执行部署

参考：
ISO=./archlinux-2020.05.01-x86_64.iso DATA_DIR=./data ./mkusb.sh /dev/sda

```bash
sudo ./scripts/mkusb.sh /dev/sdX
```

⚠️ 注意：会清空整个设备，这里必须用 archlinux 版本无所谓

---

## 💡 原理

* 动态分区（GPT）
* 写入 bootloader
* 解压 rootfs

---

## ⚠️ 注意事项

* 不建议使用 dd 直接复制系统
* 必须使用 root 权限

---

## 📄 License

MIT

