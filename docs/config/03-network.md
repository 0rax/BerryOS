---
title: Network Configuration
parent: Configuration
nav_order: 3
permalink: /docs/config/network/
---

# Network Configuration
{: .no_toc }

---

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Introduction

Network configuration in BerryOS is handle by [`cloud-init`](https://cloudinit.readthedocs.io/en/latest/topics/network-config.html) with the help of [`netplan`](https://netplan.io/) inside the [`/boot/network-config`](https://github.com/0rax/BerryOS/blob/main/rootfs/boot/network-config) file.

We decided to use the [version 2 networking config format](https://cloudinit.readthedocs.io/en/latest/topics/network-config-format-v2.html) as it is capable of configuring both the `eth0` and `wlan0` interface on the Raspberry Pi easily thanks to `netplan`'s ability to configure `systemd-networkd` renderer.

## Default configuration

By default, BerryOS is configured to configure the `eth0` interface using DHCP for IPv4 assignation by using the following configuration:

```yaml
version: 2
ethernets:
  eth0:
    dhcp4: true
```

## Connecting to a Wi-Fi network

To connect to a Wi-Fi network, we will need to update our `network-config` file to include the necessary directive to enable the `wlan0` interface.

```yaml
version: 2
ethernets:
  eth0:
    dhcp4: true
wifis:
  wlan0:
    dhcp4: true
    optional: true
    access-points:
      "My Access Point":
        password: "AP Password"
```

From there you can specify the access point you want to by replacing `"My Acess Point"` with the SSID of your Wi-Fi network. Be careful, the SSID must be enclosed in quotation marks. You should also replace `"AP Password"` with the password of your network.

Password do not need to be set in plain text, they can also be set directly as WPA PSK. The PSK form of a password can be generated using the [`wpa_passphrase`](https://linux.die.net/man/8/wpa_passphrase) utility on any system with `wpa_supplicant` installed. This would look like this:

```yaml
version: 2
ethernets:
  eth0:
    dhcp4: true
wifis:
  wlan0:
    dhcp4: true
    optional: true
    access-points:
      "My Access Point":
        password: 046ea35be8d6bd70480d233602146ff58aded1c2892d3aa67c5f6be635e8163f
```

## Using a static IPv4

To use a static IPv4 instead of using DHCP for an interface, we need to disable the `dhcp4` parameter and add the static network configuration we want using `addresses` to set up the IP / netmask combo and `routes` to set up the default route:

```yaml
version: 2
ethernets:
  eth0:
    dhcp4: false
    addresses:
      - 192.168.1.128/24
    routes:
      - to: 0.0.0.0/0
        via: 192.168.1.1
```

## Enabling IPv6 support

In order to enable IPv6 support via DHCP for an interface, the `dhcp6` parameter of said interface should be added and set to true. For example, to enable it for the `eth0` interface, your configuration should look like:

```yaml
version: 2
ethernets:
  eth0:
    dhcp4: true
    dhcp6: true
```

Manual configuration can also be done by using the `addresses` & `routes` parameters:

```yaml
version: 2
ethernets:
  eth0:
    dhcp4: false
    dhcp6: false
    addresses:
      - 192.168.1.128/24
      - 2001:cafe:face:beef::dead:dead/64
    routes:
      - to: 0.0.0.0/0
        via: 192.168.1.1
      - to: ::/0
        via: 2001:cafe:face::1
```

## References

- [`cloud-init` Networking Config Version 2](https://cloudinit.readthedocs.io/en/latest/topics/network-config-format-v2.html)
- [`netplan` Reference Manual](https://netplan.io/reference/)
- [`netplan` Configuration Examples](https://netplan.io/examples/)

> **Note**
>
> The [`netplan` documentation](https://netplan.io/examples/#using-dhcp-and-static-addressing) shows that a default route can be configured with the `default` alias as the `to` target in `routes`. This **does not work** on BerryOS as it is not currently supported by the `networkd` renderer, you **must** use the `0.0.0.0/0` or `::/0` form instead.
>
