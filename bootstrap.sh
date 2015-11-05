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
sed -i '/.be\//s/^#//g' etc/pacman.d/mirrorlist

# Disable CheckSpace in chroot
sed -i "s/^\s*CheckSpace.*/#CheckSpace/" etc/pacman.conf
# Temporarely set SigLevel to never
sed -i.bak "s/^\s*SigLevel\s*=.*$/SigLevel = Never/" etc/pacman.conf

chroot `pwd` /bin/bash <<EOL
pacman --noconfirm -Sy haveged && haveged
pacman-key --init
pacman-key --populate archlinux
pacman -Suy --noconfirm --needed base gptfdisk
pacman -Scc --noconfirm
EOL

# Restore SigLevel
mv etc/pacman.conf.bak etc/pacman.conf

cp ../install-arch.sh .
chroot `pwd` /bin/bash ./install-arch.sh




# REQUIREMENTS
# create gpt partitions with raid:
# - /dev/sd[ab]1 1M GPT
# - /dev/sd[ab]2 20g /root
# - /dev/sd[ab]3 100% -> to be used by LVM, setup with ansible
# - /dev/sd[ab]4 4G swap
#
