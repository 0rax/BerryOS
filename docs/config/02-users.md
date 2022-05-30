---
title: User Configuration
parent: Configuration
nav_order: 2
permalink: /docs/config/users/
---

# User Configuration
{: .no_toc }

---

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Introduction

BerryOS comes by default with a single accessible user created on first boot by [`cloud-init`](https://cloud-init.io/). This default user can be configured or overwritten quite easily in your [`/boot/user-data`](https://github.com/0rax/BerryOS/blob/main/rootfs/boot/user-data) file.

## Default User

The default user created on first boot if not configured is set up as follows:

- Username: `pi`
- Password: `raspberry`

You can log in with these credentials on any TTY, but you will not be able to SSH to your system using them. For security reason and to follow [the decision made by the Raspberry Pi OS team in April 2022](https://www.raspberrypi.com/news/raspberry-pi-bullseye-update-april-2022/), password based SSH access to any user must be explicitly enabled.

### Updating user password & enabling password access

To configure our user, update its password and allow password authentication when using SSH to log in, we will rely on the [Set passwords `cloud-init` module](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#set-passwords).

This module exposes 3 parameters: `ssh_pwauth`, `password` and `chpasswd` which control SSH password access, the password itself and the password expiration respectively.

Let's first update our user password using `password` and `chpasswd`.

```yaml
#cloud-config
password: "mypassword"
chpasswd: { expire: false }
```

The `password` field can either be a plaintext password or a hashed version of it. On *NIX system, a password can be hashed easily using the `openssl passwd -6` command. On the other hand, here we just set the `chpasswd` parameter to `{ expire: false }` to disable password expiration.

Finally, to enable password SSH access, we just need to set the `ssh_pwauth` parameter to true. With a hashed password, your `user-data` file would look like:

```yaml
#cloud-config
password: $6$kEE0sV/2tz/jWBtQ$tRpM0XqKhl3xEroj837u6VCQadIoSL......nSY48unRmtsZv0
chpasswd: { expire: false }
ssh_pwauth: true
```

Be careful when enabling SSH password authentication as it is inherently less secure than using SSH key based authentication. If this is an option, you should always prefer keeping it off and import your SSH keys instead

### Importing SSH keys

Another option available to enable SSH access is to import your SSH public keys as `authorized_keys` for the default user. This can be done quite easily using the [`ssh_authorized_keys`](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#authorized-keys) and [`ssh_import_id`](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#ssh-import-id) directives.

You can set up your public keys explicitly using:

```yaml
#cloud-config
ssh_authorized_keys:
  - ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAGEA3FSyQwBI6Z+nCSjUU ...
  - ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA3I7VUf2l5gSn5uavROsc5HRDpZ ...
```

Another option is to use `ssh-import-id` which can import your public keys from GitHub or Launchpad by specifying your username of the platform prefixed by `gh` or `lp` respectively:

```yaml
#cloud-config
ssh_import_id:
 - gh:user
 - lp:user
```

## Creating custom users

Another option available it to create your own users instead of using the default user, all the options available for the default user can also be used for your custom users and can be used in combination. User creation is handled using the [User and Groups module](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#users-and-groups) under the `users` directive.

By default, this directive is configured as follows:

```yaml
#cloud-config
users:
  - default
```

This instructs `cloud-init` to create the and configure the default user as configured by the system, you can disable this behavior by removing `default` in the list. In that case you will need to add your own user instead.

As an example, let's create a new user named `0rax` and see what each option allows us to configure:

```yaml
#cloud-config
users:
  - name: 0rax                          # User name
    gecos: "JP Roemer"                  # User description
    sudo: ALL=(ALL) NOPASSWD:ALL        # Allow passwordless sudo
    shell: /bin/bash                    # Default shell
    groups:                             # User groups
      [adm, dialout, cdrom, sudo, audio, video, plugdev, games, users, input, render, netdev]
    passwd: berryos                     # User password
    chpasswd: { expire: false }         # Do not expire user password
    ssh_pwauth: false                   # Disabble SSH password auth
    ssh_authorized_keys: []             # List of ssh authorized keys
    ssh_import_id:
      - gh:0rax                         # Import authorized keys from GitHub
```

You can also use this directive to create `system` users if the application you will be setting up requires it:

```yaml
#cloud-config
users:
- default
- name: myapplication
  shell: /usr/sbin/nologin
  system: true
  lock_passwd: true
```
