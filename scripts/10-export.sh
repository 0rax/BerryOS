#!/bin/bash
set -euxo pipefail

if ! test -f /.dockerenv; then
    echo "Running this script outside a Docker container is unsupported" 1>&2
    exit 1
fi

## Build config
OS_NAME="${OS_NAME:-"BerryOS"}"
OS_VERSION="${OS_VERSION?}"
BUILD_ARCH="${BUILD_ARCH?}"
DEBIAN_RELEASE="${DEBIAN_RELEASE:-"bookworm"}"

## Build path
BUILD_DIR="${BUILD_DIR:-/opt/bootstrap}"
OUTPUT_DIR="${BUILD_DIR}/out"
ROOTFS_TAR="${OUTPUT_DIR}/${OS_NAME,,}-${BUILD_ARCH}-${DEBIAN_RELEASE}-${OS_VERSION//.}-rootfs.tar.xz"
IMAGE_PATH="${OUTPUT_DIR}/${OS_NAME,,}-${BUILD_ARCH}-${DEBIAN_RELEASE}-${OS_VERSION//.}.img"

setup_rootfs () {
    ROOTFS_DIR=$(mktemp --tmpdir=/tmp --directory berryos.XXXXXXXXXX)
    mkdir -p "${ROOTFS_DIR}"
    tar -xJ --file="${ROOTFS_TAR}" --directory="${ROOTFS_DIR}"
    export ROOTFS_DIR
}

create_image () {
    # Calculate part size
    MIB="$((1024 * 1024))"
    BOOTFS_SIZE="$((256 * MIB))"
    ROOTFS_SIZE="$(du --apparent-size -s "${ROOTFS_DIR}" --exclude var/cache/apt/archives --exclude boot --block-size=1 | cut -f 1)"
    ROOTFS_MARGIN="$(echo "(${ROOTFS_SIZE} * 0.2 + 200 * 1024 * 1024) / 1" | bc)"

    # Compute part offset and alignment
    ALIGN="$((4 * MIB))"
    BOOT_PART_START="$((ALIGN))"
    BOOT_PART_SIZE="$(((BOOTFS_SIZE + ALIGN - 1) / ALIGN * ALIGN))"
    ROOT_PART_START="$((BOOT_PART_START + BOOT_PART_SIZE))"
    ROOT_PART_SIZE="$(((ROOTFS_SIZE + ROOTFS_MARGIN + ALIGN  - 1) / ALIGN * ALIGN))"
    IMG_SIZE="$((BOOT_PART_START + BOOT_PART_SIZE + ROOT_PART_SIZE))"

    # Generate and partition disk image
    truncate -s "${IMG_SIZE}" "${IMAGE_PATH}"
    parted --script "${IMAGE_PATH}" mklabel msdos
    parted --script "${IMAGE_PATH}" unit B mkpart primary fat32 "${BOOT_PART_START}" "$((BOOT_PART_START + BOOT_PART_SIZE - 1))"
    parted --script "${IMAGE_PATH}" unit B mkpart primary ext4 "${ROOT_PART_START}" "$((ROOT_PART_START + ROOT_PART_SIZE - 1))"

    # Export PARTUUIDs
    IMAGE_PARTUUID_PREFIX="$(dd if="${IMAGE_PATH}" skip=440 bs=1 count=4 2>/dev/null | xxd -e | cut -f 2 -d' ')"
    BOOT_PARTUUID="${IMAGE_PARTUUID_PREFIX}-01"
    ROOT_PARTUUID="${IMAGE_PARTUUID_PREFIX}-02"
    export BOOT_PARTUUID
    export ROOT_PARTUUID
}

mount_image () {
    # Mount each partition with device mapper
    DEVICE=$(kpartx -va "${IMAGE_PATH}" | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1)
    dmsetup --noudevsync mknodes
    BOOT_DEV="/dev/mapper/${DEVICE}p1"
    ROOT_DEV="/dev/mapper/${DEVICE}p2"
    DEVICE="/dev/${DEVICE}"
    export BOOT_DEV
    export ROOT_DEV

    # Give some time to system to refresh
    sleep 3

    # Create file systems
    mkfs.vfat "${BOOT_DEV}" -n "bootfs"
    mkfs.ext4 "${ROOT_DEV}" -L "rootfs" -F -i 4096 # create 1 inode per 4kByte block (maximum ratio is 1 per 1kByte)

    # Mount file systems
    mount -v "${ROOT_DEV}" "/mnt" -t ext4
    mkdir -p "/mnt/boot/firmware"
    mount -v "${BOOT_DEV}" "/mnt/boot/firmware" -t vfat
}

patch_rootfs () {
    # Create mount points
    mkdir -p "${ROOTFS_DIR}"/{proc,sys,dev/pts}

    # Inject PARTUUID in /etc/fstab & /boot/firmware/cmdline.txt
    sed -i "s/BOOTDEV/PARTUUID=${BOOT_PARTUUID}/" "${ROOTFS_DIR}/etc/fstab"
    sed -i "s/ROOTDEV/PARTUUID=${ROOT_PARTUUID}/" "${ROOTFS_DIR}/etc/fstab"
    sed -i "s/ROOTDEV/PARTUUID=${ROOT_PARTUUID}/" "${ROOTFS_DIR}/boot/firmware/cmdline.txt"

    # Reset machine-id
    rm -f "${ROOTFS_DIR}/var/lib/dbus/machine-id"
    true > "${ROOTFS_DIR}/etc/machine-id"

    # Cleanup logs
    find "${ROOTFS_DIR}/var/log/" -type f -exec cp /dev/null {} \;
}

sync_rootfs () {
    # Copy rootfs content to mounted file systems
    rsync -aHAXx --exclude /var/cache/apt/archives --exclude /boot/firmware "${ROOTFS_DIR}/" "/mnt"
    rsync -rtx "${ROOTFS_DIR}/boot/firmware/" "/mnt/boot/firmware/"
}

umount_image () {
    # Unmount filesystems
    umount /mnt/boot/firmware
    umount /mnt

    # Zero unallocated blocks using zerofree to enhance compression
    zerofree "${ROOT_DEV}"

    # Disable loop devices
    kpartx -vds "${DEVICE}" || true
    losetup -d "${DEVICE}" || true
}

cleanup_rootfs () {
    # Cleanup
    rm -rf "${ROOTFS_DIR}"
}

compress_image () {
    # Compress disk image
    xz -T0 -c9 "${IMAGE_PATH}" > "${IMAGE_PATH}.xz"

    # Remove uncompressed image to save space
    rm -f "${IMAGE_PATH}"
}

setup_rootfs
create_image
mount_image
patch_rootfs
sync_rootfs
umount_image
cleanup_rootfs
compress_image
