#!/usr/bin/env bash

cat << "EOF"
                    _
     /\            | |
    /  \   _ __ ___| |__
   / /\ \ | '__/ __| '_ \
  / ____ \| | | (__| | | |
 /_/    \_\_|  \___|_| |_|

EOF

set -e
LINE="-------------------------------------------"

export PATH="${HOME}/.local/bin:${PATH}"

if ! command -v pacman &>/dev/null; then
  echo "This script is only for Arch based systems. Exiting..."
  echo "${LINE}"
  exit 1
fi

echo "Arch based system found!"

echo "${LINE}"

# Install AUR helpers & Flatpak
sudo pacman -S --noconfirm yay flatpak --needed

echo "${LINE}"