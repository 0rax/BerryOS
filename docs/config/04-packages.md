---
title: Package Management
parent: Configuration
nav_order: 4
permalink: /docs/config/packages/
lastmod: 2022-06-11T16:59:07.081Z
---

# Package Management
{: .no_toc }

---

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Introduction

During first boot, [`cloud-init`](https://cloud-init.io/) can be asked to manage enabled repositories, installed packages or even upgrade your system using the [Package module](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#package-update-upgrade-install) in your [`/boot/firmware/user-data`](https://github.com/0rax/BerryOS/blob/main/rootfs/boot/firmware/user-data) file.

## Installing packages

To install packages during the system provisioning phase you need to configure both the `package_update` & `packages` parameters. `package_update` instruct the system to refresh the local package list from configured repositories and `packages` define the list of package to install.

For example, if you wanted to install the `vim` and `htop` packages during provisioning, it would look like this:

```yaml
#cloud-coufig
package_update: true
packages:
  - vim
  - htop
```

## Updating system packages

It is also possible, and recommended, to upgrade all existing package in the system at first-boot. This will make sure that your newly configured system is up-to-date with the latest security fixes available.

To do we, we will need to use the `package_update` and `package_upgrade` directives, we can also use the `package_reboot_if_required` parameter to define if we want the `cloud-init` to reboot the system if a package requiring it has been updated. This can be important if the kernel is updated though might not be required if you instruct `cloud-init` to reboot the system post-provisioning using the [Power State module](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#power-state-change).

```yaml
#cloud-coufig
package_update: true
package_upgrade: true
package_reboot_if_required: true
```

## Adding extra repositories

There might be cases where you want to set up extra package repositories to install packages not available in the official Debian ones. This can be done quite easily using the [Apt Configure `cloud-init` module](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#apt-configure).

For example, to add the Docker CE repository to your system, you would set it up as follows (replace `<key_data>` with its real data):

```yaml
#cloud-coufig
apt:
  preserve_sources_list: true
  sources:
    docker-ce.list:
      source: "deb [arch=armhf] https://download.docker.com/linux/raspbian bullseye stable"
      key: |
        -----BEGIN PGP PUBLIC KEY BLOCK-----
        <key_data>
        -----END PGP PUBLIC KEY BLOCK-----
```

A complete configuration that also install and configure `docker` is available [here](/docs/examples/docker-ce/).
