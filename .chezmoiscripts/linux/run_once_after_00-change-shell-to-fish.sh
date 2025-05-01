#!/usr/bin/env bash

cat << "EOF"

  ______ _     _        _____ _          _ _
 |  ____(_)   | |      / ____| |        | | |
 | |__   _ ___| |__   | (___ | |__   ___| | |
 |  __| | / __| '_ \   \___ \| '_ \ / _ \ | |
 | |    | \__ \ | | |  ____) | | | |  __/ | |
 |_|    |_|___/_| |_| |_____/|_| |_|\___|_|_|

EOF

# Check if current shell is already fish
if [[ "$SHELL" != *"fish"* ]]; then
  # Change shell to fish
  chsh -s $(which fish)
  echo "Switch to Fish for ${USER}"
  echo "Please reboot once for changes to take effect"
else
  echo "Shell is already set to Fish for ${USER}"
fi

echo