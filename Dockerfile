# syntax=docker/dockerfile:1.8
FROM debian:bookworm

# Copy binfmt/qemu executables to enable building for other architectures
COPY --from=multiarch/qemu-user-static:x86_64-aarch64 \
    /usr/bin/qemu-aarch64-static /usr/bin
COPY --from=multiarch/qemu-user-static:x86_64-arm \
    /usr/bin/qemu-arm-static     /usr/bin

RUN apt-get update -y -qq \
 && apt-get install -y -qq --no-install-recommends \
            make debootstrap binfmt-support file \
            parted kpartx dosfstools zerofree xxd \
            rsync wget ca-certificates gpg \
            bc xz-utils eatmydata
