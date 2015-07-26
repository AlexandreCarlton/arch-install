#!/bin/bash

# Complete set up of Arch.
# First use wifi-menu to connect to the internet, then execute:
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
  pvcreate $LVM_PARTITION
  vgcreate $VOL_GROUP $LVM_PARTITION
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
  sed -i "7i Server = $SERVER\n" /etc/pacman.d/mirrorlist
  pacstrap /mnt base base-devel
}

generate_fstab() {
  genfstab -L -p /mnt >> /mnt/etc/fstab
}

configure() {
  # Set locale, timezone, hostname, font
  sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
  locale-gen
  systemd-firstboot --locale="en_US.UTF-8"
  systemd-firstboot --timezone="Australia/Sydney"
  systemd-firstboot --hostname="absol"
  echo -e "KEYMAP=us\nFONT=Lat2-Terminus16\n" > /etc/vconsole.conf

  # Install relevant utilities so that we can do things on next boot
  pacman -S --noconfirm connman wpa_supplicant
  systemctl enable connman

  # configure mkinitpcio
  echo "Replace base and udev with systemd, place sd-lvm2 between block and filesystems and insert sd-vconsole."
  vi /etc/mkinitcpio.conf
  mkinitcpio -p linux

  # Bootloader
  pacman -S --noconfirm syslinux gptfdisk
  syslinux-install_update -i -a -m
  sed -i 's:/dev/sda3:/dev/disk/by-label/root:g' /boot/syslinux/syslinux.cfg

  # Root password
  passwd

  # Add normal user with sudo access
  pacman -S --noconfirm zsh
  useradd -m -G wheel -s /bin/zsh alexandre
  passwd alexandre
  echo "Uncomment the wheel line."
  EDITOR=vi visudo

  pacman -S --noconfirm git
  su - alexandre -c "git clone git://github.com/AlexandreCarlton/arch-install.git .arch-install"

  # Install system files
  # Maybe do this /after/ installing everything? Just copy pacman.conf across then install.
  cd /home/alexandre/.arch-install/system_config
  for dir in $(find . -type d | cut -c2- ); do
    mkdir -p $dir
  done
  for file in $(find . -type f | cut -c2- ); do
    cp .$file $file
  done
  pacman -Syy
  pacman -S --needed --noconfirm $(cat /home/alexandre/.arch-install/*.pacman)
  cd

  # Weird hack for adding keys to unsigned repositories
  dirmngr </dev/null
  # TODO Add keys with -r, verify with -f, locally sign with --lsign-key
  #pacman-key -r <KEY>
  #pacman-key --lsign-key <KEY>

  # TODO: powertop here?

  su - alexandre -c "git clone git://github.com/AlexandreCarlton/dotfiles.git .dotfiles"
  su - alexandre -c "cd .dotfiles && git submodule update --init --remote --recursive"
  su - alexandre -c "cd .dotfiles && stow vim && stow systemd && stow bspwm && stow binaries && stow status && stow zsh"
  #su alexandre -c "build_aur aura-bin"
  #su alexandre -c "aura -A --noconfirm $(cat arch-install/*.aur)"

}

# Execute!
destroy_lvm
partition_filesystem
create_lvm
format_partitions
mount_partitions
pacstrap_system
generate_fstab

export -f configure build_aur
export hostname
export username
arch-chroot /mnt /bin/bash -c "configure"
# Need to install aura-bin but not as root.
