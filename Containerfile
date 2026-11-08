# syntax=docker/dockerfile:1
ARG OS_IMAGE=registry.opensuse.org/opensuse/leap
ARG OS_VERSION=16.0

# 直接以目标操作系统为基础镜像，不再需要 ghcr 的 toolkit 阶段
FROM ${OS_IMAGE}:${OS_VERSION}

ARG REPO=ghcr.io/edwardwoodhub/my-opensuse-lxqt-cloud-plus
ARG VERSION=latest

ENV REPO=${REPO}
ENV VERSION=${VERSION}

# 1. 补充 openSUSE Leap 16.0 官方与 M17N 字体社区源
RUN zypper --non-interactive ar -cf -p 90 https://download.opensuse.org/distribution/leap/16.0/repo/oss/ oss || true && \
    zypper --non-interactive ar -cf -p 90 https://download.opensuse.org/distribution/leap/16.0/repo/non-oss/ non-oss || true && \
    zypper --non-interactive ar -cf -p 90 https://download.opensuse.org/repositories/M17N:/fonts/16.0/ M17N-fonts || true

# 2. 自动信任导入 GPG 密钥并刷新源缓存
RUN zypper --non-interactive --gpg-auto-import-keys refresh

# 3. 安装核心软件，直接包含官方源最新版的 elemental-toolkit
RUN ARCH=$(uname -m); \
    ADD_PKGS=""; \
    if [ "${ARCH}" != "riscv64" ]; then \
        ADD_PKGS+=" shim"; \
        [ "${ARCH}" = "aarch64" ] && ARCH="arm64"; \
    fi; \
    zypper --non-interactive --gpg-auto-import-keys install --no-recommends -- \
        ${ADD_PKGS} \
        7zip \
        at-spi2-core \
        audit \
        btop \
        btrfsmaintenance \
        btrfsprogs \
        chromium \
        curl \
        dbus-1-tools \
        device-mapper \
        distrobox \
        dosfstools \
        dracut \
        e2fsprogs \
        elemental-toolkit \
        fastfetch \
        featherpad \
        findutils \
        filelight \
        fontconfig \
        gedit \
        glib2-tools \
        gptfdisk \
        grim \
        grub2 \
        grub2-${ARCH}-efi \
        gsettings-desktop-schemas \
        gzip \
        haveged \
        htop \
        i3lock \
        iproute2 \
        kanshi \
        kate \
        kernel-default \
        konsole \
        labwc \
        less \
        lvm2 \
        lximage-qt \
        lxqt-labwc-session \
        lxqt-session \
        lxqt-wayland-session \
        meld \
        Mesa \
        Mesa-dri \
        MozillaFirefox \
        mtools \
        nano \
        NetworkManager \
        nextcloud \
        noto-sans-cjk-fonts \
        openbox \
        openssh-clients \
        openssh-server \
        parted \
        patterns-lxqt-lxqt \
        pcmanfm-qt \
        podman \
        python3 \
        qt6-wayland \
        qterminal \
        rsync \
        screengrab \
        sddm \
        sed \
        slurp \
        snapper \
        spectacle \
        squashfs \
        sudo \
        swaybg \
        swaylock \
        syncthing \
        systemd \
        tar \
        tilix \
        timezone \
        uv \
        vim \
        wayvnc \
        wdisplays \
        which \
        wl-clipboard \
        wlr-randr \
        wqy-microhei-fonts \
        xautolock \
        xdg-utils \
        xorriso \
        xscreensaver \
        xterm-resize \
        xwayland && \
    fc-cache -f && \
    zypper clean --all

# ----------------------------------------------------
# 4. 基础用户与免密 sudo 配置
# ----------------------------------------------------
RUN groupadd -f wheel && \
    useradd -m -G wheel -s /bin/bash liveuser && \
    usermod -p '$6$3HzcniSmLcqcdDAD$XaGco3Esx69ux6SgsKCac/TWld3/L8ADC1I7eZRtaMvsPfNeb0cb6doyXP2qeyw6DOjVK.BluxZfQcAD/qR6e.' liveuser && \
    useradd -m -G wheel -s /bin/bash peter && \
    usermod -p '$6$3HzcniSmLcqcdDAD$XaGco3Esx69ux6SgsKCac/TWld3/L8ADC1I7eZRtaMvsPfNeb0cb6doyXP2qeyw6DOjVK.BluxZfQcAD/qR6e.' peter && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    echo 'Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' >> /etc/sudoers

# ----------------------------------------------------
# 4c. 彻底锁死 root 密码
# ----------------------------------------------------
RUN mkdir -p /system/oem && \
printf 'name: "Root Password Enforcer"\n\
stages:\n\
fs.after:\n\
- name: "Set root password hash"\n\
commands:\n\
- usermod -p '\''$6$3HzcniSmLcqcdDAD$XaGco3Esx69ux6SgsKCac/TWld3/L8ADC1I7eZRtaMvsPfNeb0cb6doyXP2qeyw6DOjVK.BluxZfQcAD/qR6e.'\'' root\n' > /system/oem/01_root_pw.yaml

# ----------------------------------------------------
# 5. 固化 Elemental 配置（改用 btrfs 快照）
# ----------------------------------------------------
RUN mkdir -p /etc/elemental/config.d && \
    printf 'snapshotter:\n  type: btrfs\n  max-snaps: 4\n' > /etc/elemental/config.d/01_snapshotter.yaml

# ----------------------------------------------------
# 6. 注入持久化目录初始化脚本与 Systemd 服务
# ----------------------------------------------------
RUN mkdir -p /usr/local/bin && \
printf '#!/bin/bash\n\
PERSISTENT_HOME="/run/elemental/persistent/home/peter"\n\
PERSISTENT_ROOT="/run/elemental/persistent/root"\n\
if [ ! -d "$PERSISTENT_HOME" ]; then\n\
mkdir -p "$PERSISTENT_HOME/.config/lxqt"\n\
mkdir -p "$PERSISTENT_ROOT"\n\
cp -a /etc/skel/. "$PERSISTENT_HOME/" || true\n\
printf "[General]\\n\
window_manager=labwc\\n\
leave_confirmation=true\\n\
\\n\
[Wayland]\\n\
compositor=labwc\\n\
screen_locker=swaylock\\n" > "$PERSISTENT_HOME/.config/lxqt/session.conf"\n\
chown -R peter:peter "$PERSISTENT_HOME"\nfi\n' > /usr/local/bin/init-persistent-home.sh && \
chmod +x /usr/local/bin/init-persistent-home.sh

RUN printf '[Unit]\n\
Description=Initialize Persistent Home Directory structure for Elemental\n\
DefaultDependencies=no\n\
After=run-elemental-persistent.mount\n\
Before=local-fs.target home.mount\n\
\n\
[Service]\n\
Type=oneshot\n\
ExecStart=/usr/local/bin/init-persistent-home.sh\n\
RemainAfterExit=yes\n\n[Install]\nWantedBy=local-fs.target\n' > /etc/systemd/system/init-persistent-home.service

RUN systemctl enable init-persistent-home.service

# 使用 printf 生成 wayvnc.service，完全不包含端口信息
RUN printf '[Unit]\n\
Description=WayVNC VNC Server\n\
After=network.target\n\
\n\
[Service]\n\
Type=simple\n\
User=peter\n\
Environment="WAYLAND_DISPLAY=wayland-0"\n\
Environment="XDG_RUNTIME_DIR=/run/user/1001"\n\
Environment="HOME=/home/peter"\n\
ExecStart=/usr/bin/wayvnc -C /home/peter/.config/wayvnc/config\n\
Restart=on-failure\n\
RestartSec=5\n\
\n\
[Install]\n\
WantedBy=multi-user.target\n' > /etc/systemd/system/wayvnc.service

# 启用wayvnc服务
RUN systemctl enable wayvnc.service



# ------------------------------
# 7. 固化 SDDM 默认显示管理器与系统启动目标软链接
# ------------------------------
RUN mkdir -p /etc/sysconfig /etc/systemd/system/graphical.target.wants && \
    echo 'DISPLAYMANAGER="sddm"' > /etc/sysconfig/displaymanager && \
    systemctl set-default graphical.target && \
    ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service && \
    ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/graphical.target.wants/sddm.service

# ------------------------------
# 8. 启用服务并执行 Elemental 初始化
# ------------------------------
RUN systemctl enable vmtoolsd.service || systemctl enable open-vm-tools.service || true && \
    systemctl enable NetworkManager.service || true && \
    systemctl enable sshd.service || true && \
    systemctl enable sddm.service || true && \
    systemd-sysusers || true && \
    mkdir -p /var/tmp /var/log /run/lock /etc/dracut.conf.d /etc/elemental && \
    echo 'hostonly="no"' > /etc/dracut.conf.d/02-generic.conf && \
    KERNEL_FILE=$(ls -1 /boot/vmlinuz-* 2>/dev/null | grep -v 'rescue' | head -n 1) && \
    if [ -n "${KERNEL_FILE}" ] && [ ! -e /boot/vmlinuz ]; then \
        ln -sf "${KERNEL_FILE}" /boot/vmlinuz; \
    fi && \
    elemental --debug init --force

# 9. 写入元数据至 /etc/os-release
RUN echo "IMAGE_REPO=\"${REPO}\"" >> /etc/os-release && \
    echo "IMAGE_TAG=\"${VERSION}\"" >> /etc/os-release && \
    echo "IMAGE=\"${REPO}:${VERSION}\"" >> /etc/os-release && \
    echo "TIMESTAMP=\"$(date +'%Y%m%d%H%M%S')\"" >> /etc/os-release && \
    echo "GRUB_ENTRY_NAME=\"my-opensuse-lxqt-cloud-plus\"" >> /etc/os-release
