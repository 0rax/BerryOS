# ![BerryOS](docs/assets/berryos-banner.png)

## What is BerryOS ?

BerryOS is a lightweight distribution of Raspberry Pi OS, meant to be used as a clean base when configuring a new Raspberry Pi. It focuses on providing a lighter operating system than can be configured headlessly at first boot.

It was born out of the frustration of not being able to configure Raspberry Pi OS Lite using [`cloud-init`](https://cloud-init.io/) easily and the fact that alternatives such as Ubuntu includes way too many pieces of software by default (such as `snapd` or `unattended-upgrades` which can chew RAM and CPU cycles).

## Overview

### Compatible hardware

BerryOS is available in two variant, a 32-bit version called `BerryOS/armhf` and a 64-bit version called `BerryOS/arm64`. Each image should have the same compatibility as their Raspberry Pi OS counterpart meaning:

- `BerryOS/armhf` should be compatible with ALL Raspberry Pi models
- `BerryOS/arm64` should be compatible with:
  - Raspberry Pi 3 B
  - Raspberry Pi 3 B+
  - Raspberry Pi 4
  - Raspberry Pi 400
  - Raspberry Compute Module 3
  - Raspberry Compute Module 3 +
  - Raspberry Compute Module 4
  - Raspberry Pi Zero 2 W

Each release is tested on the following hardware:

- Raspberry Pi 2 B (`armhf`)
- Raspberry Pi 3 B (`armhf` & `arm64`)
- Raspberry Pi 3 B+ (`armhf` & `arm64`)

Due to its nature, it should also provide the same level of compatibility with 3rd party software and hardware as Raspberry Pi OS.

### Similarities and differences with Raspberry Pi OS Lite

The goal of the images provided by BerryOS is to provide a similar user experience to Raspberry Pi OS Lite while including as little pre-installed packages as possible and making unattended provisioning possible.

To do so, BerryOS is bootstrapped from the same base as Raspberry Pi OS Lite with a reduced list of package installed by default and the following changes to the default configuration:

- Addition of [`cloud-init`](https://cloud-init.io/) to handle unattended provisioning at first boot
- Addition of [`netplan`](https://netplan.io/) to handle Wi-Fi configuration using `cloud-init`
- `openssh` enabled by default
- Serial console disabled by default
- Bluetooth support not configured by default
- No swapfile configured by default
- `wpa_supplicant` installed and configured by disabled by default

On the other hand, some services have been kept as is from Raspberry Pi such as:

- `fake-hwclock` to emulate a hardware clock by committing current date to disk periodically
- `rngd` to enable random number generation offloading to the hardware (provided by `rng-tools5`)
- `systemd-timesyncd` to handle network time synchronization (configurable via `cloud-init`)

In the end, BerryOS is just a stripped down version of [Raspberry Pi OS Lite (Stage 2)](https://github.com/RPi-Distro/pi-gen/blob/master/README.md#stage-anatomy) with the addition of `cloud-init` & `netplan`, making it the perfect base to self-host any application your Raspberry Pi.

### Default environment

If not configured using `/boot/user-data`, BerryOS will be provisioned using its default configuration, this default environment will include the default user accessible via:

- Username: `pi`
- Password: `raspberry`

To follow [the decision made by the Raspberry Pi OS team in April 2022](https://www.raspberrypi.com/news/raspberry-pi-bullseye-update-april-2022/), access to this default user via SSH will be DISABLED by default. In order to access your system headlessly and configure SSH access, follow the ["Getting started" guide](#getting-started) down below.

This default environment will also try to:

- Enable and configure `eth0` using DHCP
- Synchronize time with the default NTP pool (`debian.pool.ntp.org`)

## Getting Started

- Download the latest version of BerryOS for your targeted architecture from the [latest release](https://github.com/0rax/BerryOS/releases/latest) and flash it on your SD card using your tool of choice
- Unplug and re-plug your SD card from your computer to discover newly created partition
- Open the `user-data` file from the `boot` partition of your SD card with your favorite editor
- Uncomment `Configure default user access` section and update it to your need
- We suggest reading through the whole file to see all the possible configuration available before continuing
- Unmount your SD card, insert it in your Raspberry Pi, plug your Ethernet cable and provide it with power
- Congratulation, you are now running BerryOS !

A more detailed explanation of most of what can be configured using `cloud-init` is available in [this project documentation](https://0rax.github.io/BerryOS/docs/config/). A set of [example `user-data` file](https://0rax.github.io/BerryOS/docs/examples/) is also available.

## Benchmark

Benchmarked on a Raspberry Pi 3 B connected via Ethernet using DHCP with the following commands after first-boot:

- RAM usage: `free -th | mawk '/^Total:/{print $3}'`
- Running processes: `pstree -Ta` (removing `sshd` & `systemctl --user` session)
- Disk usage: `findmnt -no USED /`
- Pre-installed packages: `dpkg --get-selections | wc -l`

Download and image sizes have been calculated using `ls -l --block-size=M`.

### `BerryOS/armhf`

| Stat                   | BerryOS Bullseye (2022.05.30) | RaspiOS Lite Bullseye (2022.04.04) |
| ---------------------- | ----------------------------- | ---------------------------------- |
| RAM usage              | 37M                           | 57M                                |
| Running processes      | 12                            | 18                                 |
| Disk usage             | 807.1M                        | 1.3G                               |
| Pre-installed packages | 312                           | 530                                |
| Download size          | 201M                          | 297M                               |
| Image size             | 1312M                         | 1924M                              |

### `BerryOS/arm64`

| Stat                   | BerryOS Bullseye (2022.05.30) | RaspiOS Lite Bullseye (2022.04.04) |
| ---------------------- | ----------------------------- | ---------------------------------- |
| RAM usage              | 52M                           | 72M                                |
| Running processes      | 12                            | 20                                 |
| Disk usage             | 611.7M                        | 1.3G                               |
| Pre-installed packages | 285                           | 521                                |
| Download size          | 153M                          | 271M                               |
| Image size             | 1112M                         | 1908M                              |

## Acknowledgements

This project has been heavily inspired by the work previously done by the team at [Hypriot](https://github.com/hypriot) for their HypriotOS. It was the starting point of this project and this project wouldn't exist without it.

The [RPi-Distro/pi-gen](https://github.com/RPi-Distro/pi-gen) & [RPi-Distro/raspi-config](https://github.com/RPi-Distro/raspi-config) projects have also been very helpful when tackling some hardware specific issues and optimizing image creation.

To the team responsible for those great pieces of software, thank you !
