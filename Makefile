OS_NAME		?= BerryOS
OS_VERSION	?= $(shell date "+%Y.%m.%d")
BUILD_ARCH	?= unknown

rootfs:
	env OS_NAME=$(OS_NAME) OS_VERSION="$(OS_VERSION)" BUILD_ARCH="$(BUILD_ARCH)" ./scripts/00-bootstrap.sh

image:
	env OS_NAME=$(OS_NAME) OS_VERSION="$(OS_VERSION)" BUILD_ARCH="$(BUILD_ARCH)" ./scripts/10-export.sh

arm64: BUILD_ARCH=arm64
arm64: rootfs image

armhf: BUILD_ARCH=armhf
armhf: rootfs image

docker-build:
	docker build -t berryos-bootstraper .

.DEFAULT: armhf
.PHONY: build rootfs image arm64 armhf
