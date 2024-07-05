---
title: System Configuration
parent: Configuration
nav_order: 1
permalink: /docs/config/system/
---

# System Configuration
{: .no_toc }

---

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Introduction

The main goal of using [`cloud-init`](https://cloud-init.io/) in BerryOS is to be able to easily configure your system during its first startup. It provides quite a lot of possibilities out of the box that we will explore here.

Most of the example shown here are related to your [`/boot/firmware/user-data`](https://github.com/0rax/BerryOS/blob/main/rootfs/boot/firmware/user-data) file unless stated otherwise. This file is the main way you interact with `cloud-init`.

## Configuring hostname

Setting the system hostname can be done quite easily using the `hostname` and `manage_etc_hosts` parameters. `hostname` will define which hostname to use while `manage_etc_hosts` will make sure that the `/etc/hosts` files is updated accordingly.

```yaml
#cloud-config
hostname: berry
manage_etc_hosts: true
```

Other options are available in the [Set Hostname `cloud-init` module](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#set-hostname) such as setting a fully qualified domain name using the `fqdn` directive if needed.

## Setting the system timezone

The timezone can be setup easily using the `timezone` directive. If set, it must be a valid file under `/usr/share/zoneinfo`.

```yaml
#cloud-config
timezone: "Europe/London"
```

## Updating the system locale

By default, BerryOS does not ship with any generated locale to save on space. This means that we cannot use the [Locale `cloud-init` module](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#locale) to update it. Instead, it should be configured post-provisioning using `localectl`. We can instruct `cloud-init` to do so using the `runcmd`, which allows us to run arbitrary commands after all other modules have run.

For example, if we wanted to update the system locale to `en_US.UTF-8`, this could be done as follows:

```yaml
#cloud-config
runcmd:
  - localectl set-locale en_US.UTF-8
```

## Using custom NTP pools

BerryOS ships by default with `systemd-timesyncd` installed and activated to handle network time synchronization. This is pretty essential on the Raspberry Pi as it does not have a battery backed hardware clock. If you need to or want to update which NTP pools the system uses to synchronize itself, they can be updated using the [NTP `cloud-init` module](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#ntp).

For example, to use your local pools if you are in the UK, they can be set via:

```yaml
#cloud-config
ntp:
  enabled: true
  pools:
    - 0.uk.pool.ntp.org
    - 1.uk.pool.ntp.org
    - 2.uk.pool.ntp.org
    - 3.uk.pool.ntp.org
```
