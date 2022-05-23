#!/bin/bash
set -euxo pipefail

if ! test -f /.dockerenv; then
    echo "Running this script outside a Docker container is unsupported" 1>&2
    exit 1
fi

## Build config
OS_NAME="${OS_NAME:-"BerryOS"}"
OS_VERSION="${OS_VERSION:-$(date "+%Y.%m.%d")}"
BUILD_ARCH="${BUILD_ARCH:-armhf}"

## Debian base
DEBIAN_VARIANT="Debian GNU/Linux"
DEBIAN_VERSION="${DEBIAN_VERSION:-"11"}"
DEBIAN_RELEASE="${DEBIAN_RELEASE:-"bullseye"}"

## Build path
BUILD_DIR="${BUILD_DIR:-/opt/bootstrap}"
FILES_DIR="${BUILD_DIR}/rootfs"
OUTPUT_DIR="${BUILD_DIR}/out"
ROOTFS_TAR="${OUTPUT_DIR}/${OS_NAME,,}-${BUILD_ARCH}-${DEBIAN_RELEASE}-${OS_VERSION//.}-rootfs.tar.xz"
ROOTFS_PKGS="${OUTPUT_DIR}/${OS_NAME,,}-${BUILD_ARCH}-${DEBIAN_RELEASE}-${OS_VERSION//.}-packages.txt"

## Debootstrap config
DEFAULT_PACKAGES_INCLUDE="apt-transport-https,binutils,ca-certificates,gpg,gpgv,locales,net-tools,wireless-tools,wpasupplicant,openssh-server,parted,sudo,usbutils,wget,libpam-systemd,systemd-timesyncd,resolvconf,lsb-release,gettext"
DEFAULT_PACKAGES_EXCLUDE="debfoster,ntp,vim,vim-tiny,vim-common,info,man-db"

setup_debootstrap () {
    # Configure debootstrap based on DEBIAN_RELEASE
    DEBOOTSTRAP_URL="http://ftp.debian.org/debian/"
    GPG_KEYRING="/usr/share/keyrings/debian-${DEBIAN_RELEASE}-archive-keyring.gpg"
    GPG_KEY_URL="https://ftp-master.debian.org/keys/archive-key-${DEBIAN_VERSION}.asc"

    # Verify BUILD_ARCH is supported and use Raspbian when armhf
    case "${BUILD_ARCH}" in
        armhf)
            DEBIAN_VARIANT="Raspbian GNU/Linux"
            DEBOOTSTRAP_URL="http://raspbian.raspberrypi.org/raspbian/"
            GPG_KEY_URL="http://raspbian.raspberrypi.org/raspbian.public.key"
            GPG_KEYRING="/usr/share/keyrings/raspbian-archive-keyring.gpg"
        ;;
        arm64)
        ;;
        *)
            echo "Unsupported BUILD_ARCH (${BUILD_ARCH})" 1>&2
            exit 1
        ;;
    esac

    # Fetch and configure keyring if needed
    DEBOOTSTRAP_KEYRING_OPTION=""
    if test -n "${GPG_KEYRING}"; then
        wget -qO- "${GPG_KEY_URL}" | gpg --dearmor > "${GPG_KEYRING}"
        DEBOOTSTRAP_KEYRING_OPTION="--keyring=${GPG_KEYRING}"
    fi

    # Export debootstrap config
    export DEBOOTSTRAP_URL
    export DEBOOTSTRAP_KEYRING_OPTION
}

setup_qemu () {
    # Setup binfmts to use qemu when cross-compiling
    case "${BUILD_ARCH}" in
        armhf)
            QEMU_ARCH=arm
        ;;
        arm64)
            QEMU_ARCH=aarch64
        ;;
    esac

    # Enable qemu binary emulation
    if test -n "${QEMU_ARCH}"; then
        update-binfmts --enable "qemu-${QEMU_ARCH}"
    fi
}

bootstrap_rootfs () {
    # Create temporary folder for bootstraping
    ROOTFS_DIR=$(mktemp --tmpdir=/tmp --directory debootstrap.XXXXXXXXXX)
    chmod 0755 "${ROOTFS_DIR}"
    export ROOTFS_DIR

    # Bootstrap system
    mkdir -p "${ROOTFS_DIR}"
    debootstrap \
        ${DEBOOTSTRAP_KEYRING_OPTION} \
        --arch="${BUILD_ARCH}" \
        --include="${DEFAULT_PACKAGES_INCLUDE}" \
        --exclude="${DEFAULT_PACKAGES_EXCLUDE}" \
        "${DEBIAN_RELEASE}" \
        "${ROOTFS_DIR}" \
        "${DEBOOTSTRAP_URL}"
}

configure_rootfs () {
    # Mount required filesystems in chroot
    mkdir -p "${ROOTFS_DIR}"/{proc,sys,dev/pts}
    mount -o bind /dev "${ROOTFS_DIR}/dev"
    mount -o bind /dev/pts "${ROOTFS_DIR}/dev/pts"
    mount -t proc none "${ROOTFS_DIR}/proc"
    mount -t sysfs none "${ROOTFS_DIR}/sys"

    # Finish bootstrapping & configuring in chroot
    chroot "${ROOTFS_DIR}" \
        /usr/bin/env \
        BUILD_ARCH="${BUILD_ARCH}" \
        DEBIAN_RELEASE="${DEBIAN_RELEASE}" \
        DEBIAN_VARIANT="${DEBIAN_VARIANT}" \
        DEBIAN_VERSION="${DEBIAN_VERSION}" \
        OS_NAME="${OS_NAME}" \
        OS_VERSION="${OS_VERSION}" \
        DEBOOTSTRAP_URL="${DEBOOTSTRAP_URL}" \
        /bin/bash < "${BUILD_DIR}/scripts/01-chroot.sh"
    chroot "${ROOTFS_DIR}" dpkg --get-selections | awk '{ print $1 }' > "${ROOTFS_PKGS}"

    # Copy static system configuration files
    install -Dm 0644 -t "${ROOTFS_DIR}/boot" \
        "${FILES_DIR}/boot/cmdline.txt" \
        "${FILES_DIR}/boot/config.txt" \
        "${FILES_DIR}/boot/meta-data" \
        "${FILES_DIR}/boot/network-config" \
        "${FILES_DIR}/boot/user-data"
    install -Dm 0644 -t "${ROOTFS_DIR}/etc" \
        "${FILES_DIR}/etc/fstab" \
        "${FILES_DIR}/etc/resolv.conf"
    install -Dm 0644 -t "${ROOTFS_DIR}/etc/cloud" \
        "${FILES_DIR}/etc/cloud/cloud.cfg"
    install -Dm 0644 -t "${ROOTFS_DIR}/etc/cloud/cloud.cfg.d" \
        "${FILES_DIR}/etc/cloud/cloud.cfg.d/90-ntp.cfg" \
        "${FILES_DIR}/etc/cloud/cloud.cfg.d/99-nocloud.cfg"
    install -Dm 0644 -t "${ROOTFS_DIR}/etc/default" \
        "${FILES_DIR}/etc/default/useradd"
    install -Dm 0644 -t "${ROOTFS_DIR}/etc/skel" \
        "${FILES_DIR}/etc/skel/.bashrc" \
        "${FILES_DIR}/etc/skel/.profile"
    install -Dm 0644 -t "${ROOTFS_DIR}/etc/systemd/system/fake-hwclock.service.d" \
        "${FILES_DIR}/etc/systemd/system/fake-hwclock.service.d/override.conf"
    install -Dm 0644 -t "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d" \
        "${FILES_DIR}/etc/systemd/system/getty@tty1.service.d/noclear.conf"
    install -Dm 0644 -t "${ROOTFS_DIR}/etc/wpa_supplicant" \
        "${FILES_DIR}/etc/wpa_supplicant/wpa_supplicant.conf"

    # Unmount chroot filesystems
    umount "${ROOTFS_DIR}/dev/pts"
    umount "${ROOTFS_DIR}/dev"
    umount "${ROOTFS_DIR}/proc"
    umount "${ROOTFS_DIR}/sys"
}

package_rootfs () {
    # Package rootfs in tar
    mkdir -p "${OUTPUT_DIR}"
    tar -c -I 'xz -9 -T0' --file="${ROOTFS_TAR}" --directory="${ROOTFS_DIR}" .
}

cleanup_rootfs () {
    # Cleanup
    rm -rf "${ROOTFS_DIR}"
}

setup_debootstrap
setup_qemu
bootstrap_rootfs
configure_rootfs
package_rootfs
cleanup_rootfs
