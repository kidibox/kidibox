#!/usr/bin/env bash

set -e

ARRAY_DISK_1=/dev/sda
ARRAY_DISK_2=/dev/sdb

dd if=/dev/zero of=$ARRAY_DISK_1 bs=512  count=1
dd if=/dev/zero of=$ARRAY_DISK_2 bs=512  count=1

# Write new partition to first disk
sgdisk \
  --clear \
  --set-alignment=1 \
  --new=1:34:2047 \
  --typecode=1:ef02 \
  --change-name=1:bios \
  --new=2:0:+20G \
  --typecode=2:8300 \
  --change-name=2:root \
  --new=3:0:-4G \
  --typecode=3:8e00 \
  --change-name=3:data \
  --new=4:0:0 \
  --typecode=4:8200 \
  --change-name=4:swap \
  --print \
  $ARRAY_DISK_1

# Copy partition to second disk, then randomize uuid
sgdisk -b - $ARRAY_DISK_1 | sgdisk -l - -Gg $ARRAY_DISK_2

partx /dev/sda
partx /dev/sdb

mdadm \
  --create \
  --verbose \
  --level=1 \
  --metadata=1.2 \
  --raid-devices=2 \
  --name=kidibox:root \
  /dev/md0 \
  "${ARRAY_DISK_1}2" \
  "${ARRAY_DISK_2}2"

mdadm \
  --create \
  --verbose \
  --level=1 \
  --metadata=1.2 \
  --raid-devices=2 \
  --name=kidibox:data \
  /dev/md1 \
  "${ARRAY_DISK_1}3" \
  "${ARRAY_DISK_2}3"

mdadm \
  --create \
  --verbose \
  --level=1 \
  --metadata=1.2 \
  --raid-devices=2 \
  --name=kidibox:swap \
  /dev/md2 \
  "${ARRAY_DISK_1}4" \
  "${ARRAY_DISK_2}4"

mkfs.ext4 /dev/md0

mkswap /dev/md2
swapon /dev/md2

mount "/dev/md0" "/mnt"

# pacstrap /mnt base base-devel openssh grub gptfdisk haveged vim
newroot=/mnt
mkdir -m 0755 -p "$newroot"/var/{cache/pacman/pkg,lib/pacman,log} "$newroot"/{dev,run,etc}
mkdir -m 1777 -p "$newroot"/tmp
mkdir -m 0555 -p "$newroot"/{sys,proc}
mount -t proc /proc "$newroot/proc"
mount --rbind /sys "$newroot/sys"
mount --rbind /run "$newroot/run"
mount --rbind /dev "$newroot/dev"
pacman -r "$newroot" --cachedir="$newroot/var/cache/pacman/pkg" -Sy base base-devel openssh grub gptfdisk haveged vim
cp -a /etc/pacman.d/gnupg "$newroot/etc/pacman.d/"
cp -a /etc/pacman.d/mirrorlist "$newroot/etc/pacman.d/"

genfstab -U -p /mnt >> /mnt/etc/fstab
mdadm --examine --scan > /mnt/etc/mdadm.conf

sed -i 's/^HOOKS="\(.*block\)\s*\(filesystems.*\)"/HOOKS="\1 mdadm_udev \2"/' /mnt/etc/mkinitcpio.conf
sed -i "s/^#Color/Color/" /mnt/etc/pacman.conf
sed -i "s/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /mnt/etc/locale.gen

if [ -f ~/.ssh/authorized_keys ]; then
  mkdir /mnt/root/.ssh
  cp ~/.ssh/authorized_keys /mnt/root/.ssh/
fi

cp -R files/* /mnt/

chroot $newroot /bin/bash <<EOL
echo kidibox > /etc/hostname
echo LANG=en_US.UTF-8 > /etc/locale.conf
ln -s /usr/share/zoneinfo/Europe/Brussels /etc/localtime

locale-gen

echo -e "root:C0mplexPwd" | chpasswd

mkinitcpio -p linux

grub-install --target=i386-pc --recheck --debug /dev/sda
grub-install --target=i386-pc --recheck --debug /dev/sdb
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable sshd.service
if [ -f /etc/netctl/ovh_net_enp0s25 ]; then
  netctl enable ovh_net_enp0s25
fi
EOL

