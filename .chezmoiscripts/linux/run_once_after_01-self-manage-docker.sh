#!/usr/bin/env bash

export PATH="${HOME}/.local/bin:${HOME}/bin:${PATH}"


cat << "EOF"

  _____             _
 |  __ \           | |
 | |  | | ___   ___| | _____ _ __
 | |  | |/ _ \ / __| |/ / _ \ '__|
 | |__| | (_) | (__|   <  __/ |
 |_____/ \___/ \___|_|\_\___|_|

EOF

# Check if docker group exists
if ! getent group docker > /dev/null; then
  echo "Creating docker group..."
  sudo groupadd docker -f
else
  echo "Docker group already exists."
fi

# Check if user is already in the docker group
if ! groups "${USER}" | grep -q '\bdocker\b'; then
  echo "Adding ${USER} to docker group..."
  sudo usermod -aG docker "${USER}"
else
  echo "${USER} is already in the docker group."
fi

# Enable docker socket
if ! systemctl is-enabled docker.socket > /dev/null 2>&1; then
  echo "Enabling docker.socket..."
  sudo systemctl enable docker.socket
else
  echo "docker.socket is already enabled."
fi

echo "Docker is now manageable by ${USER}"
echo "Note: You may need to log out and back in for group changes to take effect."