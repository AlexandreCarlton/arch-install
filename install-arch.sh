#!/usr/bin/env bash


## TODO:
## Switch to btrfs and use LUKS
## Boot partition is BIOS/UEFI, the rest is LUKS/btrfs.

# Complete set up of Arch.
# First use wifi-menu to connect to the internet, then:
# sh <(curl -L http://goo.gl/<keys>)

# Constants {{{
DEVICE=/dev/sda
BOOT_PARTITION="${DEVICE}1"
LVM_PARTITION="${DEVICE}2"

VOL_GROUP=VolGroup00
LVM_ROOT=lvm_root
LVM_VAR=lvm_var
LVM_SWAP=lvm_swap
LVM_HOME=lvm_home

ROOT_PARTITION="/dev/$VOL_GROUP/$LVM_ROOT"
HOME_PARTITION="/dev/$VOL_GROUP/$LVM_HOME"
VAR_PARTITION="/dev/$VOL_GROUP/$LVM_VAR"
SWAP_PARTITION="/dev/$VOL_GROUP/$LVM_SWAP"

SERVER=http://ftp.iinet.net.au/pub/archlinux/\$repo/os/\$arch

hostname=absol
username=alexandre # Our regular user
#}}}

## Start

destroy_lvm() {
  [ -n "$(vgs)" ] && vgremove --force $(vgs --option vg_name --noheadings)
  [ -n "$(pvs)" ] && pvremove --force $(pvs --option pv_name --noheadings)
}

partition_filesystem() {
  # If we were using UEFI we'd have ESP fat32 instead for /dev/sda1 (boot).
  parted $DEVICE --script mklabel gpt
  parted $DEVICE --script --align=optimal mkpart primary ext2 1MiB 513MiB
  parted $DEVICE --script set 1 boot on
  parted $DEVICE --script --align=optimal mkpart primary ext4 513MiB 100%
}

# LVM
create_lvm() {
  lvm_partition=$1
  pvcreate $lvm_partition
  vgcreate $VOL_GROUP $lvm_partition
  lvcreate -L 20G $VOL_GROUP -n $LVM_ROOT
  lvcreate -L 12G $VOL_GROUP -n $LVM_VAR
  lvcreate -L 2G $VOL_GROUP -n $LVM_SWAP
  lvcreate -l +100%FREE $VOL_GROUP -n $LVM_HOME
}

# Formatting
format_partitions() {
  mkfs.ext2 -L boot $BOOT_PARTITION
  mkfs.ext4 -L root $ROOT_PARTITION
  mkfs.ext4 -L home $HOME_PARTITION
  mkfs.ext4 -L var $VAR_PARTITION
  mkswap -L swap $SWAP_PARTITION
  swapon $SWAP_PARTITION
}

# Mounting
mount_partitions() {
  mount /dev/disk/by-label/root /mnt
  mkdir -p /mnt/boot
  mkdir -p /mnt/home
  mkdir -p /mnt/var
  mount /dev/disk/by-label/boot /mnt/boot
  mount /dev/disk/by-label/home /mnt/home
  mount /dev/disk/by-label/var /mnt/var
}

pacstrap_system() {
  sed -i "1i Server = $SERVER\n" /etc/pacman.d/mirrorlist
  pacstrap /mnt base base-devel btrfs-progs
}

generate_fstab() {
  genfstab -L -p /mnt >> /mnt/etc/fstab
}

# Execute!
destroy_lvm
partition_filesystem
create_lvm "$LVM_PARTITION"
format_partitions
mount_partitions
pacstrap_system
generate_fstab


# OR: Just have another script, and do arch-crhoot /mnt /bin/bash < chroot.sh
arch-chroot /mnt /bin/bash < chroot.sh
