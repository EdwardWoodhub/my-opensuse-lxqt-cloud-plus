# 构建工具

Containerfile

# 基座

## 基础镜像

选择SUSE的镜像更容易构建：

[Elemental - Immutable Linux for Rancher](https://elemental.docs.rancher.com/custom-images/)

选择openSUSE的镜像更容易自定义：

[Portal:Container/Base Container - openSUSE Wiki](https://en.opensuse.org/Portal:Container/Base_Container)

[How to Build Elemental OS Images](https://oneuptime.com/blog/post/2026-03-20-elemental-build-os-images/view)


## 镜像拉取

[openSUSE Registry](https://registry.opensuse.org/cgi-bin/cooverview)

```
podman pull registry.opensuse.org/opensuse/leap:16.0
```

## SBOM（软件物料清单）

(1) 官方提供了带 SPDX 的文件，里面列出了镜像里的包，例如：
[download.opensuse.org/distribution/leap/16.0/appliances](https://download.opensuse.org/distribution/leap/16.0/appliances/)
里面有对应的 .spdx.json 文件。

```
curl -sL "https://download.opensuse.org/distribution/leap/16.0/appliances/opensuse-leap-image.x86_64-16.0.0-docker-Build5.16.docker.spdx.json" \
  | jq -r '.packages[] | "\(.name)-\(.versionInfo)"' | sort
```

(2) 还有些别的镜像，暂不需要。

| 类型 | 代表文件 | 有没有内核/GRUB | 用途 | 包数量特点 |
| --- | --- | --- | --- | --- |
| 容器镜像 | opensuse-leap-image.*.docker / registry.opensuse.org/opensuse/leap:16.0 | ❌ 没有 | Docker / Podman 容器 | 最精简（约 100 个包） |
| Minimal VM | Leap-16.0-Minimal-VM.*.qcow2 / .vmdk 等 | ✅ 有 | 虚拟机（KVM、VMware、Hyper-V、Cloud） | 比容器多很多，包含启动所需的内核、initramfs、systemd 等 |
| Minimal Image / Appliance | Leap-16.0-Minimal-Image.*.raw.xz | ✅ 有 | 直接写盘的镜像（树莓派、裸机、云磁盘） | 和 Minimal VM 类似，是完整可启动系统 |
| OEM 镜像 | Leap-16.0-OEM.*.raw.xz（GNOME/KDE） | ✅ 有 | 预装桌面的完整镜像 | 最大，带桌面环境 |

| 类型 | 本质 | 运行方式 | 典型格式 | 为什么适合 / 不适合 OCI |
|------|------|----------|----------|-------------------------|
| **用户态最小系统**（opensuse-leap-image-*-docker / networkd.tar.xz） | 纯用户态 rootfs | 容器运行时（Podman/Docker），共享宿主机内核 | OCI 分层 blob | 天然匹配。分层、去重、增量拉取、registry 生态全是为它设计的 |
| **Minimal VM / Cloud / Appliance / OEM** | 完整可启动操作系统 | 直接被 hypervisor / 云平台 / 硬件启动 | qcow2、raw、vmdk、vhdx、raw.xz 等 | 需要完整的分区表、bootloader（GRUB 等）、内核、initrd、文件系统布局。OCI 本身不是可启动的磁盘镜像格式 |

容器镜像只需要 `/` 下的用户空间内容就够了，kernel 和硬件抽象由宿主机提供。  
VM / Appliance 镜像必须自己带齐启动链路，否则云厂商、QEMU、VMware、Hyper-V、裸机 `dd` 都无法直接使用。


# 构建产物

(1) OCI镜像

(2) 分片LiveCD



# 推送方式

本地的各个Layer Blob，直接推送到GHCR。
