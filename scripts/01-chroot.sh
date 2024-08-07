#!/bin/bash
set -euxo pipefail

if ! [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
  echo "Running this script outside a chroot is unsupported" 1>&2
  exit 1
fi

## Build config
OS_NAME="${OS_NAME?}"
OS_VERSION="${OS_VERSION?}"
BUILD_ARCH="${BUILD_ARCH:-$(dpkg --print-architecture)}"

## Debian base
DEBIAN_VARIANT="${DEBIAN_VARIANT?}"
DEBIAN_RELEASE="${DEBIAN_RELEASE?}"
DEBOOTSTRAP_URL="${DEBOOTSTRAP_URL?}"

## System config
DEFAULT_HOSTNAME="${DEFAULT_HOSTNAME:-"berry"}"

## Configure Base system

# Set default locale to "C.UTF-8"
echo 'locales locales/default_environment_locale select C.UTF-8' | debconf-set-selections
dpkg-reconfigure -f noninteractive locales

# Configure default hostname
echo "${DEFAULT_HOSTNAME}" > /etc/hostname
echo "127.0.1.1       ${DEFAULT_HOSTNAME}" >> /etc/hosts

# Update source.list to include extra pools
if [ "${DEBIAN_VARIANT}" == "Raspbian GNU/Linux" ]; then
    DEBIAN_POOLS="main contrib non-free rpi"
    (
        echo "deb [arch=armhf] ${DEBOOTSTRAP_URL} ${DEBIAN_RELEASE} ${DEBIAN_POOLS}"
        echo "# Uncomment line below then 'apt-get update' to enable 'apt-get source'"
        echo "#deb-src [arch=armhf] ${DEBOOTSTRAP_URL}-security ${DEBIAN_RELEASE}-security ${DEBIAN_POOLS}"
    ) | tee /etc/apt/sources.list
else
    DEBIAN_POOLS="main contrib non-free non-free-firmware"
    (
        echo "deb ${DEBOOTSTRAP_URL} ${DEBIAN_RELEASE} ${DEBIAN_POOLS}"
        echo "deb ${DEBOOTSTRAP_URL}-security ${DEBIAN_RELEASE}-security ${DEBIAN_POOLS}"
        echo "# Uncomment line below then 'apt-get update' to enable 'apt-get source'"
        echo "#deb-src ${DEBOOTSTRAP_URL}-security ${DEBIAN_RELEASE}-security ${DEBIAN_POOLS}"
        echo "#deb-src ${DEBOOTSTRAP_URL}-security ${DEBIAN_RELEASE}-security ${DEBIAN_POOLS}"
    ) | tee /etc/apt/sources.list
fi

# Set default systemd target to multi-user
systemctl set-default multi-user.target

## Install Raspberry Pi dependencies

# Add Raspberry Pi official repository
RPI_GPG_KEY_URL=http://archive.raspberrypi.com/debian/raspberrypi.gpg.key
RPI_GPG_KEYRING=/etc/apt/trusted.gpg.d/raspberrypi-archive.gpg
wget -qO- "${RPI_GPG_KEY_URL}" | gpg --dearmor > "${RPI_GPG_KEYRING}"
(
    echo "deb http://archive.raspberrypi.com/debian/ ${DEBIAN_RELEASE} main"
    echo "# Uncomment line below then 'apt-get update' to enable 'apt-get source'"
    echo "#deb-src http://archive.raspberrypi.com/debian/ ${DEBIAN_RELEASE} main"
) | tee /etc/apt/sources.list.d/raspberrypi.list

# Enable the other architecture in dpkg (required for various reason)
if [ "${BUILD_ARCH}" = "armhf" ]; then
    dpkg --add-architecture arm64
elif [ "${BUILD_ARCH}" = "arm64" ]; then
    dpkg --add-architecture armhf
fi

# Update lists and upgrade existing package to their RPi specific counterpart
apt-get update
apt-get upgrade -y

# Disable automatic kernel images symlinking
echo "do_symlinks=0" > /etc/kernel-img.conf

# Select correct kernel images for request build architecture
KERNEL_IMAGES=
case "${BUILD_ARCH}" in
    armhf)
        KERNEL_IMAGES="linux-image-rpi-v6 linux-image-rpi-v7 linux-image-rpi-v7l linux-image-rpi-v8"
    ;;
    arm64)
        KERNEL_IMAGES="linux-image-rpi-v8 linux-image-rpi-2712"
    ;;
esac

# Install kernels, firmwares, bootloader and tools
apt-get install -y \
    --no-install-recommends \
    initramfs-tools \
    ${KERNEL_IMAGES} \
    firmware-atheros \
    firmware-brcm80211 \
    firmware-libertas \
    firmware-misc-nonfree \
    firmware-realtek \
    raspi-firmware \
    raspi-config \
    raspberrypi-sys-mods

# Remove /etc/sudoers.d/010_pi-nopasswd installed by `raspberrypi-sys-mods`, user account creation and allowing them to assume root is handled by `clout-init`
rm -f /etc/sudoers.d/010_pi-nopasswd

## Setup OS specifics

# Setup rpi-issue
tee /etc/rpi-issue << EOF
${OS_NAME} ${OS_VERSION}
Generated using berryos-builder, ${OS_REPO}, ${GIT_HASH}, ${BUILD_ARCH}
EOF

install -m 644 /etc/rpi-issue /boot/firmware/issue.txt
if ! [ -L /boot/issue.txt ]; then
	ln -s firmware/issue.txt /boot/issue.txt
fi

# Setup MOTD
DEBIAN_ISSUE=$(cat /etc/issue.net)
tee /etc/motd << EOF

${OS_NAME}/${BUILD_ARCH} ${OS_VERSION} (${DEBIAN_ISSUE})

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
EOF

## Install & configure cloud-init

# Install cloud-init & netplan to handle provisioning
apt-get install -y \
    --no-install-recommends \
    cloud-init \
    ssh-import-id \
    netplan.io

# Mask dhcpcd & systemd-resolved to prevent potential conflicts with with cloud-init network config
systemctl mask dhcpcd
systemctl mask systemd-resolved

# Enable remote access via ssh
systemctl enable ssh

# Enable network time synchronization using systemd-timesyncd
systemctl enable systemd-timesyncd

# Disable wpa_supplicant as it is handled by netplan and started only when needed
systemctl disable wpa_supplicant

## Configure Hardware RNG support

# Install rng-tools
apt-get install -y \
    --no-install-recommends \
    rng-tools5

# Enable hardware rng generation via rng
systemctl enable rngd

## Configure HWClock

# Install and enable fake-hwclock
apt-get install -y \
    --no-install-recommends \
    fake-hwclock

# Store fake-hwlock.data in boot partiton
touch /boot/fake-hwclock.data
ln -sf /boot/fake-hwclock.data /etc/fake-hwclock.data
mkdir -p /etc/systemd/system/fake-hwclock.service.d
systemctl daemon-reload

# Enable fake-hwclock and store current time
systemctl enable fake-hwclock
fake-hwclock save

## Cleanup
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*
