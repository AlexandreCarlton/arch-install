#!/bin/sh

# vim:foldmethod=marker:

username='alexandre'
hostname='absol'
system_folder="/home/${username}/.arch-install/system_config"
freezone_server='http://ftp.iinet.net.au/pub/archlinux/\$repo/os/\$arch'

install_file() { # {{{
  # We abstract this away to allow error-checking.
  local system_file=$1
  if [ -e "${system_folder}${system_file}" ]; then
    mkdir -p $(dirname "${system_file}")
    cp "${system_folder}${system_file}" "${system_file}"
  else
    echo "WARNING:\t${sustem_file} not found in git repo."
  fi
} # }}}

# systemd locale etc. {{{
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen
systemd-firstboot --locale='en_US.UTF-8'
systemd-firstboot --timezone='Australia/Sydney'
systemd-firstboot --hostname="${hostname}"
echo -e "KEYMAP=us\nFONT=Lat2-Terminus16\n" > /etc/vconsole.conf
# }}}

# Set freezone server {{{
sed -i "1i Server = ${freezone_server}\n" /etc/pacman.d/mirrorlist
# }}}

# Add user {{{
pacman -S --noconfirm zsh
useradd -m -G wheel -s /bin/zsh "${username}"
passwd "${username}"
# Probably shouldn't edit sudoers with sed...
# DOUBLE CHECK THIS.
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/'
# Autologin
install_file /etc/systemd/system/getty@tty1.service.d/override.conf
# }}}

# Dotfiles / Archlinux files {{{
pacman -S --noconfirm git
su - alexandre -c 'git clone git://github.com/AlexandreCarlton/arch-install.git .arch-install'
su - alexandre -c 'git clone --recursive git://github.com/AlexandreCarlton/dotfiles.git .dotfiles'
su - alexandre -c 'cd .dotfiles && git submodule update --init --remote --recursive'
su - alexandre -c 'cd .dotfiles && stow vim && stow systemd && stow bspwm && stow binaries && stow status && stow zsh'
# }}}

# Initramfs image {{{
install_file /etc/mkinitcpio.conf
mkinitcpio -p linux
# }}}

# Boot (BIOS) {{{
pacman -S --noconfirm needed syslinux gptfdisk
syslinux-install_update -i -a -m
install_file /boot/syslinux/syslinux.cfg
# }}}

# Wi-Fi {{{
pacman -S --noconfirm connman wpa_supplicant
systemctl enable connman
install_file /etc/connman/main.conf
install_file /var/lib/connman/wifi_rugby.config
install_file /var/lib/connman/wifi_rugby_EXT.config
install_file /var/lib/connman/wifi_UniSydney.config
install_file /var/lib/connman/wifi_eduroam.config
# }}}

# Xorg {{{
# TODO Identify which packages are needed
pacman -S xorg
install_file /etc/X11/Xwrapper.config
install_file /etc/X11/xorg.conf.d/50-synaptics.conf
# }}}

# General systemd {{{
install_file /etc/systemd/journald.conf
install_file /etc/systemd/user.conf
# }}}

# Power Management {{{
pacman -S --noconfirm tlp
instal_file /etc/systemd/system/tlp.service
systemctl enable tlp.service
systemctl enable tlp-sleep.service
# }}}

# Make dash /bin/sh {{{
pacman -S --noconfirm dash
ln -sf dash /bin/sh
# }}}

# Start user processes before logging in {{{
loginctl enable-linger "${username}"
# }}}

# Enable overlayfs for profile-sync-daemon {{{
overlay_permissions="${username} ALL=NOPASSWD: /usr/bin/psd-overlay-helper"
echo "$overlay_permissions" >> /etc/sudoers
# }}}

# Third-party repos {{{
dirmngr </dev/null # Weird hack for adding keys to unsigned repositories
infinality_key_id='962DDE58'
arch_haskell_key_id='4209170B'
ck_key_id='5EE46C4C'
keys="$infinality_key_id $arch_haskell_key_id $ck_key_id"
for key in "$keys"; do
  pacman-key -r "$key"
  pacman-key --lsign-key "$key"
done
pacman -Syy
# }}}

# Infinality {{{
pacman -S --noconfirm {lib32-,}{freetype2,fontconfig,cairo}-infinality-ultimate
# xinitrc.d isn't sourced anymore since we don't use xinit.
ln -s /etc/X11/xinit/xinitrc.d/infinality-settings.sh /etc/profile.d/infinality-settings.sh
# }}}

# Install whatever's left {{{
pacman -S --needed --noconfirm $(cat "/home/${username}/.arch-install/*.pacman")
# }}}


passwd

echo "All done! You can reboot now, and run 'post-install.sh' to finalise the rest of th configuration."
# echo "Rebooting..."
# sleep 5
# reboot
