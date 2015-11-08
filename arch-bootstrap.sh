#!/usr/bin/env bash

set -e

wget -c -r -nd -l0 --no-parent -A "x86_64.tar.gz" "http://archlinux.mirrors.ovh.net/archlinux/iso/latest/"

tar xzvf $(find `pwd` -iname 'archlinux*.tar.gz')

cd root.x86_64
cp /etc/resolv.conf etc

mount -t proc /proc proc
mount --rbind /sys sys
mount --rbind /dev dev
mount --rbind /run run  # (assuming /run exists on the system)

# Enable OVH mirror
sed -i '/mirrors.ovh.net/s/^#//g' etc/pacman.d/mirrorlist
# sed -i '/.be\//s/^#//g' etc/pacman.d/mirrorlist

# Disable CheckSpace in chroot
sed -i "s/^\s*CheckSpace.*/#CheckSpace/" etc/pacman.conf
# Temporarely set SigLevel to never
sed -i.bak "s/^\s*SigLevel\s*=.*$/SigLevel = Never/" etc/pacman.conf

chroot `pwd` /bin/bash <<EOL
pacman --noconfirm -Sy haveged && haveged
pacman-key --init
pacman-key --populate archlinux
pacman -S --noconfirm --needed gptfdisk mdadm  sed
pacman -Scc --noconfirm
EOL

# Restore SigLevel
mv etc/pacman.conf.bak etc/pacman.conf

cp ../install-arch.sh .
cp -R ../files .


if [ -f ~/.ssh/authorized_keys ]; then
  mkdir root/.ssh
  cp ~/.ssh/authorized_keys root/.ssh/
fi

chroot `pwd` /bin/bash ./install-arch.sh

# TODO
# create gpt partitions with raid:
# - /dev/sd[ab]1 1M GPT
# - /dev/sd[ab]2 20g /root
# - /dev/sd[ab]3 100% -> to be used by LVM, setup done post install by ansible
# - /dev/sd[ab]4 4G swap / leave 100m at the end
#
# - loggly
# - /var/lib/docker on lvm?
