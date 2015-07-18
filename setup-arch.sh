#!/bin/bash

EDITOR=vi
AUR_HELPER_PACKAGE="aura-bin"
AUR_INSTALL="aura -A"

function build_aur () {
    package=$1
    index=${package:0:2}
    tarball=${package}.tar.gz

    cd "$HOME"
    wget "https://aur.archlinux.org/packages/$index/$package/$tarball"
    tar -xzvf "$tarball"
    cd "$package"
    makepkg -si

    # Clean up
    cd "$HOME"
    rm "$tarball"
    rm -r "$package"
}


cd $HOME

# Install official packages (removing comments)
sudo pacman -S *.pacman

# Install precompiled aura (no hellish haskell dependencies)
build_aur "$AUR_HELPER_PACKAGE"

$AUR_INSTALL *.aur

# Set zsh as default shell
sudo chsh -s /bin/zsh
