# BerryOS

Just the berry part of Raspberry Pi OS with a sprinkle of cloud sugar.

## What ?

BerryOS is a lightweight distribution of Raspberry Pi OS, meant to be used as a clean base when configuring a new Raspberry Pi. It focuses mainly on providing a lighter operation than can be configured headlessly at first boot.

This image includes as little as possible with the addition of:

- `cloud-init` to handle headless configuration at first boot
- `rng-tools5` to enable random number generation offloading to the hardware
- `openssh` enabled by default
- `systemd-timesyncd` enabled by default to handle network time synchronization
- Disable predictable network interface name by default (to ease network configuration)

## Why ?

Raspberry Pis are great little computers, though setting one up can take some time especially when you want to optimize CPU and RAM consumption as much as possible. I've found myself writing quite a lot of small scripts to set up a new Pi with some specific scenarios when testing some software just to have a simple base for myself.

One solution I found out was to use the Ubuntu Server image for Raspberry Pi, this image includes `cloud-init`, a nifty tool usually used to configure virtual machines, which allows you to configure your system at first boot (which user you want to create, their SSH keys, a set of scripts to run at first boot or on every startup, ...). This was a great solution, though after some time, I have discovered that there is a lot of things running by default on this image that I do not like such as `unattended-upgrades` which can cripple your Raspberry Pi's performance when doing updates in the background or `snapd` which I never use.

Other base image exists, but I wanted to stay with something loosely Debian related as most of the official tools provided by the Raspberry Pi foundation are built for it. It is also usually the only system supported by drivers for weird Pi hat you can buy online.

This is why I decided to create BerryOS, a slim down version of the Raspberry Pi OS that includes `cloud-init`.

## Details

Extra enabled services:

- `cloud-init` (run at boot)
- `systemd-timesyncd` (when enabled via `cloud-init`, enabled by default)
- `fake-hwclock` (run at boot, shutdown and every hour)
- `rngd`
- `openssh`

Default user (when `default` is specified in `cloud-init` users or if no users are configured in `/boot/user-data`):

- Username: `pi`
- Password: `raspberry`

Compatibility:

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

Tested on:

- Raspberry Pi 2 B (`armhf`)
- Raspberry Pi 3 B (`armhf` & `arm64`)
- Raspberry Pi 3 B+ (`armhf` & `arm64`)

## Benchmark

Benchmarked on a Raspberry Pi 3 B connected via Ethernet using DHCP using the following commands after first-boot:

- RAM usage: `free -th | mawk '/^Total:/{print $3}'`
- Running processes: `pstree -Ta` (removing `sshd` & `systemctl --user` session)
- Disk usage: `findmnt -no USED /`
- Pre-installed packages: `dpkg --get-selections | wc -l`

Download and image sizes have been calculated using `ls -l --block-size=M`.

### `BerryOS/armhf`

| Stat                   | BerryOS Bullseye | RaspiOS Lite Bullseye (2022-04-04) |
| ---------------------- | ---------------- | ---------------------------------- |
| RAM usage              | 39M              | 57M                                |
| Running processes      | 12               | 20                                 |
| Disk usage             | 791.5M           | 1.3G                               |
| Pre-installed packages | 312              | 530                                |
| Download size          | 196M             | 297M                               |
| Image size             | 1308M            | 1924M                              |

### `BerryOS/arm64`

| Stat                   | BerryOS Bullseye | RaspiOS Lite Bullseye (2022-04-04) |
| ---------------------- | ---------------- | ---------------------------------- |
| RAM usage              | 53M              | 72M                                |
| Running processes      | 13               | 20                                 |
| Disk usage             | 606.1M           | 1.3G                               |
| Pre-installed packages | 280              | 521                                |
| Download size          | 151M             | 271M                               |
| Image size             | 1108M            | 1908M                              |
