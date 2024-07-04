OS_NAME		?= BerryOS
OS_VERSION	?= $(shell date "+%Y.%m.%d")
OS_REPO		?= https://github.com/0rax/BerryOS
GIT_HASH	?= $(shell git rev-parse HEAD)
DEBIAN_VERSION	?= 12
DEBIAN_RELEASE	?= bookworm

.DEFAULT: armhf

## Builder rules

all: armhf arm64

builder:
	$(info [BerryOS] Prepare builder)
	docker compose build builder

armhf: builder
	$(info [BerryOS] Build for armhf)
	docker compose run builder make rootfs image \
	    OS_NAME="$(OS_NAME)" \
	    OS_VERSION="$(OS_VERSION)" \
	    OS_REPO="$(OS_REPO)" \
	    GIT_HASH="$(GIT_HASH)" \
	    DEBIAN_VERSION="$(DEBIAN_VERSION)" \
	    DEBIAN_RELEASE="$(DEBIAN_RELEASE)" \
	    BUILD_ARCH=armhf

arm64: builder
	$(info [BerryOS] Build for arm64)
	docker compose run builder make rootfs image \
	    OS_NAME="$(OS_NAME)" \
	    OS_VERSION="$(OS_VERSION)" \
	    OS_REPO="$(OS_REPO)" \
	    GIT_HASH="$(GIT_HASH)" \
	    DEBIAN_VERSION="$(DEBIAN_VERSION)" \
	    DEBIAN_RELEASE="$(DEBIAN_RELEASE)" \
	    BUILD_ARCH=arm64

.PHONY: all builder armhf arm64

## OS rules

rootfs: BUILD_ARCH ?= armhf
rootfs:
	$(info [BerryOS/$(BUILD_ARCH)] Bootstrap rootfs)
	env OS_NAME=$(OS_NAME) \
	    OS_VERSION="$(OS_VERSION)" \
	    OS_REPO="$(OS_REPO)" \
	    GIT_HASH="$(GIT_HASH)" \
	    DEBIAN_VERSION="$(DEBIAN_VERSION)" \
	    DEBIAN_RELEASE="$(DEBIAN_RELEASE)" \
	    BUILD_ARCH="$(BUILD_ARCH)" \
	    ./scripts/00-bootstrap.sh

image: BUILD_ARCH ?= armhf
image:
	$(info [BerryOS/$(BUILD_ARCH)] Export image)
	env OS_NAME=$(OS_NAME) \
	    OS_VERSION="$(OS_VERSION)" \
	    DEBIAN_RELEASE="$(DEBIAN_RELEASE)" \
	    BUILD_ARCH="$(BUILD_ARCH)" \
	    ./scripts/10-export.sh

.PHONY: rootfs image

## Release rules

release: armhf arm64 checksums

checksums:
	$(info [BerryOS] Generate checksums)
	cd out/ \
	&& sha256sum \
	    berryos-arm64-$(DEBIAN_RELEASE)-$(subst .,,$(OS_VERSION))-rootfs.tar.xz \
	    berryos-arm64-$(DEBIAN_RELEASE)-$(subst .,,$(OS_VERSION))-packages.txt \
	    berryos-arm64-$(DEBIAN_RELEASE)-$(subst .,,$(OS_VERSION)).img.xz \
	    > berryos-arm64-$(DEBIAN_RELEASE)-$(subst .,,$(OS_VERSION))-checksums.txt \
	&& sha256sum \
	    berryos-armhf-$(DEBIAN_RELEASE)-$(subst .,,$(OS_VERSION))-rootfs.tar.xz \
	    berryos-armhf-$(DEBIAN_RELEASE)-$(subst .,,$(OS_VERSION))-packages.txt \
	    berryos-armhf-$(DEBIAN_RELEASE)-$(subst .,,$(OS_VERSION)).img.xz \
	    > berryos-armhf-$(DEBIAN_RELEASE)-$(subst .,,$(OS_VERSION))-checksums.txt

.PHONY: release checksums
