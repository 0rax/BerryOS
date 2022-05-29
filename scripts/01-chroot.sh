#!/bin/bash
set -euxo pipefail

if ! [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
  echo "Running this script outside a chroot is unsupported" 1>&2
  exit 1
fi

## Build config
OS_NAME="${OS_NAME?}"
OS_VERSION="${OS_VERSION?}"
OS_PREFIX="${OS_PREFIX:-${OS_NAME^^}}"
BUILD_ARCH="${BUILD_ARCH:-$(dpkg --print-architecture)}"

## Debian base
DEBIAN_VARIANT="${DEBIAN_VARIANT?}"
DEBIAN_RELEASE="${DEBIAN_RELEASE?}"
DEBIAN_VERSION="${DEBIAN_VERSION?}"
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
DEBIAN_POOLS="main contrib non-free"
if [ "${DEBIAN_VARIANT}" == "Raspbian GNU/Linux" ]; then
    DEBIAN_POOLS="${DEBIAN_POOLS} rpi"
fi
(
    echo "deb ${DEBOOTSTRAP_URL} ${DEBIAN_RELEASE} ${DEBIAN_POOLS}"
    echo "# Uncomment line below then 'apt-get update' to enable 'apt-get source'"
    echo "#deb-src ${DEBOOTSTRAP_URL} ${DEBIAN_RELEASE} ${DEBIAN_POOLS}"
) | tee /etc/apt/sources.list

# Set default systemd target to multi-user
systemctl set-default multi-user.target

## Install Raspberry Pi dependencies

# Add Raspberry Pi official repository
RPI_GPG_KEY_URL=http://archive.raspberrypi.org/debian/raspberrypi.gpg.key
RPI_GPG_KEYRING=/etc/apt/trusted.gpg.d/raspberrypi-archive.gpg
wget -qO- "${RPI_GPG_KEY_URL}" | gpg --dearmor > "${RPI_GPG_KEYRING}"
(
    echo "deb http://archive.raspberrypi.org/debian/ ${DEBIAN_RELEASE} main"
    echo "# Uncomment line below then 'apt-get update' to enable 'apt-get source'"
    echo "#deb-src http://archive.raspberrypi.org/debian/ ${DEBIAN_RELEASE} main"
) | tee /etc/apt/sources.list.d/raspberrypi.list

# Pin specific dependency to the raspberrypi repository
mkdir -p "/etc/apt/preferences.d"
tee /etc/apt/preferences.d/raspberrypi << EOF
# Ensure that the correct firmware packages from the Raspberry Pi Foundation get installed

Package: firmware-*
Pin: origin archive.raspberrypi.org
Pin-Priority: 1001

Package: libraspberrypi*
Pin: origin archive.raspberrypi.org
Pin-Priority: 1001

Package: raspberrypi-bootloader
Pin: origin archive.raspberrypi.org
Pin-Priority: 1001
EOF

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
tee /etc/issue << EOF
${OS_NAME}/${BUILD_ARCH} ${OS_VERSION} (${DEBIAN_VARIANT} ${DEBIAN_VERSION}) \n \l

eth0 : \4{eth0}
wlan0: \4{wlan0}

EOF
tee /etc/issue.net << EOF
echo "${OS_NAME}/${BUILD_ARCH} ${OS_VERSION} (${DEBIAN_VARIANT} ${DEBIAN_VERSION})"
EOF


# Setup MOTD
tee /etc/motd << EOF

${OS_NAME}/${BUILD_ARCH} ${OS_VERSION} (${DEBIAN_VARIANT} ${DEBIAN_VERSION})

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
EOF

# Add extra /etc/os-release parameters
printf '%s_NAME="%s/%s"\n' "${OS_PREFIX}" "${OS_NAME}" "${BUILD_ARCH}" >> /etc/os-release
printf '%s_VERSION="%s"\n' "${OS_PREFIX}" "${OS_VERSION}" >> /etc/os-release

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
