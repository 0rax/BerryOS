#!/bin/bash
set -euxo pipefail

if ! [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
  echo "Running this script outside a chroot is unsupported" 1>&2
  exit 1
fi

OS_NAME="${OS_NAME?}"
OS_VERSION="${OS_VERSION?}"
OS_PREFIX="${OS_PREFIX:-${OS_NAME^^}}"
DEBIAN_VARIANT="${DEBIAN_VARIANT?}"
DEBIAN_RELEASE="${DEBIAN_RELEASE?}"
DEBIAN_VERSION="${DEBIAN_VERSION?}"
DEBOOTSTRAP_URL="${DEBOOTSTRAP_URL?}"

BUILD_ARCH="${BUILD_ARCH:-$(dpkg --print-architecture)}"
DEFAULT_HOSTNAME="${DEFAULT_HOSTNAME:-"berry"}"

## Configure Base system

# Set default locale to "C.UTF-8"
echo 'locales locales/locales_to_be_generated select en_US.UTF-8 UTF-8' | debconf-set-selections
echo 'locales locales/default_environment_locale select C.UTF-8' | debconf-set-selections
dpkg-reconfigure -f noninteractive locales

# Configure default hostname
echo "${DEFAULT_HOSTNAME}" > /etc/hostname
echo "127.0.1.1       ${DEFAULT_HOSTNAME}" >> /etc/hosts

# Disalbe predictable network interface device names (force eth0)
ln -sf /dev/null /etc/systemd/network/99-default.link
ln -sf /dev/null /etc/systemd/network/73-usb-net-by-mac.link

# Update source.list to include extra pools
case "${DEBIAN_VARIANT}" in
    "Debian GNU/Linux")
        echo "deb ${DEBOOTSTRAP_URL} ${DEBIAN_RELEASE} main contrib non-free
# Uncomment line below then 'apt-get update' to enable 'apt-get source'
#deb-src ${DEBOOTSTRAP_URL} ${DEBIAN_RELEASE} main contrib non-free" | tee /etc/apt/sources.list
    ;;
    "Raspbian GNU/Linux")
        echo "deb ${DEBOOTSTRAP_URL} ${DEBIAN_RELEASE} main contrib non-free rpi
# Uncomment line below then 'apt-get update' to enable 'apt-get source'
#deb-src ${DEBOOTSTRAP_URL} ${DEBIAN_RELEASE} main contrib non-free rpi" | tee /etc/apt/sources.list
    ;;
esac

# Set default systemd target to multi-user
systemctl set-default multi-user.target

# Enable network time synchronisation using systemd-timesyncd
systemctl enable systemd-timesyncd

## Install Raspberry Pi dependencies

# Add Raspberry Pi official repository
RPI_GPG_KEY_URL=http://archive.raspberrypi.org/debian/raspberrypi.gpg.key
RPI_GPG_KEYRING=/etc/apt/trusted.gpg.d/raspberrypi-archive.gpg
wget -qO- "${RPI_GPG_KEY_URL}" | gpg --dearmor > "${RPI_GPG_KEYRING}"
echo "deb http://archive.raspberrypi.org/debian/ ${DEBIAN_RELEASE} main
# Uncomment line below then 'apt-get update' to enable 'apt-get source'
#deb-src http://archive.raspberrypi.org/debian/ ${DEBIAN_RELEASE} main" | tee /etc/apt/sources.list.d/raspberrypi.list

# Pin specific dependency to the raspberrypi repository
mkdir -p "/etc/apt/preferences.d"
echo "# Ensure that the correct firmware packages from the Raspberry Pi Foundation get installed

Package: firmware-*
Pin: origin archive.raspberrypi.org
Pin-Priority: 1001

Package: libraspberrypi*
Pin: origin archive.raspberrypi.org
Pin-Priority: 1001

Package: raspberrypi-bootloader
Pin: origin archive.raspberrypi.org
Pin-Priority: 1001" | tee /etc/apt/preferences.d/raspberrypi

# Update lists and upgrade existing package to their RPi specific counterpart
apt-get update
apt-get upgrade -y

# Install firmwares, bootloader, tools and kernel
apt-get install -y \
    --no-install-recommends \
    raspberrypi-bootloader \
    raspberrypi-kernel \
    firmware-atheros \
    firmware-brcm80211 \
    firmware-libertas \
    firmware-misc-nonfree \
    firmware-realtek \
    libraspberrypi0 \
    libraspberrypi-bin \
    raspi-config

## Setup OS specifics

# Setup OS issues
echo "${OS_NAME}/${BUILD_ARCH} ${OS_VERSION} (${DEBIAN_VARIANT} ${DEBIAN_VERSION}) \n \l

eth0 : \4{eth0}
wlan0: \4{wlan0}
" | tee /etc/issue
# TODO: cleanup
echo "${OS_NAME}/${BUILD_ARCH} ${OS_VERSION} (${DEBIAN_VARIANT} ${DEBIAN_VERSION})" | tee /etc/issue.net

# Setup MOTD
echo "
${OS_NAME}/${BUILD_ARCH} ${OS_VERSION} (${DEBIAN_VARIANT} ${DEBIAN_VERSION})

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law." | tee /etc/motd

# Add extra /etc/os-release parameters
printf '%s_NAME="%s/%s"\n' "${OS_PREFIX}" "${OS_NAME}" "${BUILD_ARCH}" >> /etc/os-release
printf '%s_VERSION="%s"\n' "${OS_PREFIX}" "${OS_VERSION}" >> /etc/os-release

## Install & configure cloud-init

# Install cloud-init and dependencies
apt-get install -y \
    --no-install-recommends \
    cloud-init \
    ssh-import-id

# Disable dhcpcd & systemd-resolved (conflicts with cloud-init network config)
systemctl mask dhcpcd
systemctl mask systemd-resolved

# Enable remote access via ssh
systemctl enable ssh

# Disable systemd-timesyncd as it is handled & configured by cloud-init
systemctl disable systemd-timesyncd

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
