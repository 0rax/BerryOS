# syntax=docker/dockerfile:1.2
FROM debian:bullseye

RUN apt-get update -y -qq \
 && apt-get install -y -qq --no-install-recommends \
            make debootstrap qemu-user-static binfmt-support file \
            parted kpartx dosfstools zerofree xxd \
            rsync wget ca-certificates gpg \
            bc xz-utils
