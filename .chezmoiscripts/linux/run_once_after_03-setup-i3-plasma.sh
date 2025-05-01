#!/usr/bin/env bash

export PATH="${HOME}/.local/bin:${HOME}/bin:${PATH}"

cat << "EOF"
  _ ____            _____  _
 (_)___ \     _    |  __ \| |
  _  __) |  _| |_  | |__) | | __ _ ___ _ __ ___   __ _
 | ||__ <  |_   _| |  ___/| |/ _` / __| '_ ` _ \ / _` |
 | |___) |   |_|   | |    | | (_| \__ \ | | | | | (_| |
 |_|____/          |_|    |_|\__,_|___/_| |_| |_|\__,_|

EOF

echo "Setting up i3 with KDE Plasma integration..."

# Create systemd user directory if it doesn't exist
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"

# Create plasma-i3 service file
PLASMA_I3_SERVICE_FILE="${SYSTEMD_USER_DIR}/plasma-i3.service"

if [ ! -f "$PLASMA_I3_SERVICE_FILE" ]; then
  echo "Creating plasma-i3 systemd service..."
  cat > "$PLASMA_I3_SERVICE_FILE" << 'EOF'
[Unit]
Description=Launch Plasma with i3
Before=plasma-workspace.target

[Service]
ExecStart=/usr/bin/i3
Restart=on-failure

[Install]
WantedBy=plasma-workspace.target
EOF
  echo "plasma-i3 service file created."
else
  echo "plasma-i3 service file already exists."
fi

# Mask the KWin service
if ! systemctl --user is-masked plasma-kwin_x11.service > /dev/null 2>&1; then
  echo "Masking plasma-kwin_x11 service..."
  systemctl mask plasma-kwin_x11.service --user
else
  echo "plasma-kwin_x11 service is already masked."
fi

# Enable the plasma-i3 service
if ! systemctl --user is-enabled plasma-i3.service > /dev/null 2>&1; then
  echo "Enabling plasma-i3 service..."
  systemctl enable plasma-i3.service --user
  echo "i3 + Plasma setup complete!"
  echo "Please log out and log back in for changes to take effect."
else
  echo "plasma-i3 service is already enabled."
fi