#!/bin/sh

package=$1
tarball=${package}.tar.gz

cd $HOME
wget https://aur.archlinux.org/cgit/aur.git/snapshot/$tarball
tar xzvf $tarball
rm $tarball
cd $package
makepkg -sic --noconfirm

# Clean up
cd $HOME
rm -r $package
