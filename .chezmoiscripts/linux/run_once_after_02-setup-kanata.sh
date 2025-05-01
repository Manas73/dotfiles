#!/usr/bin/env bash

export PATH="${HOME}/.local/bin:${HOME}/bin:${PATH}"

cat << "EOF"

  _  __                 _
 | |/ /                | |
 | ' / __ _ _ __   __ _| |_ __ _
 |  < / _` | '_ \ / _` | __/ _` |
 | . \ (_| | | | | (_| | || (_| |
 |_|\_\__,_|_| |_|\__,_|\__\__,_|

EOF

echo "Setting up Kanata keyboard remapper..."

# 1. Create uinput group if it doesn't exist
if ! getent group uinput > /dev/null; then
  echo "Creating uinput group..."
  sudo groupadd uinput
else
  echo "uinput group already exists."
fi

# 2. Add user to input and uinput groups
if ! groups "${USER}" | grep -q '\binput\b'; then
  echo "Adding ${USER} to input group..."
  sudo usermod -aG input "${USER}"
else
  echo "${USER} is already in input group."
fi

if ! groups "${USER}" | grep -q '\buinput\b'; then
  echo "Adding ${USER} to uinput group..."
  sudo usermod -aG uinput "${USER}"
else
  echo "${USER} is already in uinput group."
fi

# 3. Create udev rules file
UDEV_RULES_FILE="/etc/udev/rules.d/99-input.rules"
if [ ! -f "$UDEV_RULES_FILE" ]; then
  echo "Creating udev rules file for uinput..."
  echo 'KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"' | sudo tee "$UDEV_RULES_FILE" > /dev/null
  sudo udevadm control --reload-rules && sudo udevadm trigger
else
  echo "udev rules file already exists."
fi

# 4. Load uinput module
if ! lsmod | grep -q uinput; then
  echo "Loading uinput kernel module..."
  sudo modprobe uinput
else
  echo "uinput module is already loaded."
fi

# 5. Create systemd user service for kanata
SYSTEMD_USER_DIR="/lib/systemd/system"
KANATA_SERVICE_FILE="${SYSTEMD_USER_DIR}/kanata.service"

# Create systemd user directory if it doesn't exist
sudo mkdir -p "$SYSTEMD_USER_DIR"

# Create kanata service file
if [ ! -f "$KANATA_SERVICE_FILE" ]; then
  echo "Creating kanata systemd service..."
  sudo cat > "$KANATA_SERVICE_FILE" << 'EOF'
[Unit]
Description=Kanata keyboard remapper
Documentation=https://github.com/jtroo/kanata

[Service]
Type=simple
ExecStart=/usr/bin/kanata --cfg $HOME/.config/kanata/config.kbd
Restart=never

[Install]
WantedBy=default.target
EOF
else
  echo "kanata service file already exists."
fi

# Reload systemd, enable and start kanata service
echo "Configuring kanata service..."
sudo systemctl daemon-reload

if ! sudo systemctl is-enabled kanata.service > /dev/null 2>&1; then
  echo "Enabling kanata service..."
  sudo systemctl enable kanata.service
else
  echo "kanata service is already enabled."
fi

if ! sudo systemctl is-active kanata.service > /dev/null 2>&1; then
  echo "Starting kanata service..."
  sudo systemctl start kanata.service
  echo "Kanata setup complete"
  echo "Note: You may need to log out and back in for group changes to take effect."
else
  echo "kanata service is already running."
fi