
#!/usr/bin/env bash

# Check if plasma system tray is already running
if pgrep -f "plasmawindowed.*systemtray" > /dev/null; then
    # Kill it if running
    pkill -f "plasmawindowed.*systemtray"
else
    # Launch it if not running
    plasmawindowed org.kde.plasma.systemtray &
fi
