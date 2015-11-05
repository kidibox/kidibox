#!/usr/bin/env bash

set -e

ARRAY_DISK_1=/dev/sda
ARRAY_DISK_2=/dev/sdb

dd if=/dev/zero of=$ARRAY_DISK_1 bs=512  count=1
dd if=/dev/zero of=$ARRAY_DISK_2 bs=512  count=1

# Write new partition to first disk
echo -e "o\ny\nn\n\n\n+1M\nef02\nn\n\n\n+100M\n8300\nn\n\n\n-4G\n8e00\n\nn\n\n\n\n8200\n\nw\ny" | gdisk $ARRAY_DISK_1

# Copy partition to second disk, then randomize uuid
sgdisk -R="${ARRAY_DISK_2}" "${ARRAY_DISK_1}"
sgdisk -G "${ARRAY_DISK_2}"

partx /dev/sda
partx /dev/sdb

sleep 5

dd if=/dev/zero bs=512 of="${$ARRAY_DISK_1}3" count=1000
dd if=/dev/zero bs=512 of="${$ARRAY_DISK_2}3" count=1000

mdadm --zero-superblock "${ARRAY_DISK_1}2" || true
mdadm --zero-superblock "${ARRAY_DISK_1}3" || true
mdadm --zero-superblock "${ARRAY_DISK_1}4" || true

mdadm --zero-superblock "${ARRAY_DISK_2}2" || true
mdadm --zero-superblock "${ARRAY_DISK_2}3" || true
mdadm --zero-superblock "${ARRAY_DISK_2}4" || true

sleep 5

mdadm \
  --create \
  --verbose \
  --level=1 \
  --metadata=1.2 \
  --raid-devices=2 \
  --name=kidibox:boot \
  /dev/md0 \
  "${ARRAY_DISK_1}2" \
  "${ARRAY_DISK_2}2"

mdadm \
  --create \
  --verbose \
  --level=1 \
  --metadata=1.2 \
  --raid-devices=2 \
  --name=kidibox:root \
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

VG_NAME=vg
LV_NAME_ROOT=root
LV_NAME_HOME=home

vgcreate --yes --force $VG_NAME /dev/md1
lvcreate $VG_NAME -n $LV_NAME_ROOT -L 10G
lvcreate $VG_NAME -n $LV_NAME_HOME -L 10G

mkfs.ext4 /dev/md0

mkfs.ext4 "/dev/mapper/${VG_NAME}-${LV_NAME_ROOT}"
mkfs.ext4 "/dev/mapper/${VG_NAME}-${LV_NAME_HOME}"

mkswap /dev/md2
swapon /dev/md2

mount "/dev/mapper/${VG_NAME}-${LV_NAME_ROOT}" "/mnt"
mkdir "/mnt/boot"
mount "/dev/md0" "/mnt/boot"
mkdir "/mnt/home"
mount "/dev/mapper/${VG_NAME}-${LV_NAME_HOME}" "/mnt/home"

pacstrap /mnt base base-devel openssh grub gptfdisk haveged

genfstab -U -p /mnt >> /mnt/etc/fstab
mdadm --examine --scan > /mnt/etc/mdadm.conf

sed -i 's/^MODULES=""/MODULES="dm_mod"/' /mnt/etc/mkinitcpio.conf
sed -i 's/^MODULES="\(((?!dm_mod)\w*\s*)*\)"/MODULES="\1dm_mod"/' /mnt/etc/mkinitcpio.conf
sed -i 's/^HOOKS="\(.*block\)\s*\(filesystems.*\)"/HOOKS="\1 mdadm_udev lvm2 \2"/' /mnt/etc/mkinitcpio.conf

arch-chroot /mnt <<EOL
echo kidibox.net > /etc/hostname
echo LANG=en_US.UTF-8 > /etc/locale.conf
ln -s /usr/share/zoneinfo/Europe/Brussels /etc/localtime
systemctl enable sshd.service
mkinitcpio -p linux
echo -e "root:C0mplexPwd" | chpasswd
syslinux-install_update -iam
grub-install --target=i386-pc --recheck --debug /dev/sda
grub-install --target=i386-pc --recheck --debug /dev/sdb
grub-mkconfig -o /boot/grub/grub.cfg
EOL
