#!/usr/bin/env bash

# Show Wi-Fi SSID or Ethernet, mirroring waybar's network module.
SERVICE=$(route get default 2>/dev/null | awk '/interface: / {print $2}')

if [ -z "$SERVICE" ]; then
  sketchybar --set "$NAME" icon="󰤮" label="N/A"
  exit 0
fi

# Determine hardware type for the interface.
HW=$(networksetup -listallhardwareports 2>/dev/null | awk -v dev="$SERVICE" '
  /Hardware Port/ {port=$0}
  $0 ~ "Device: "dev"$" {sub(/^Hardware Port: /, "", port); print port}
')

case "$HW" in
  *Wi-Fi*|*AirPort*)
    SSID=$(ipconfig getsummary "$SERVICE" 2>/dev/null | awk -F' SSID : ' '/ SSID : / {print $2; exit}')
    [ -z "$SSID" ] && SSID="Wi-Fi"
    sketchybar --set "$NAME" icon="" label="$SSID"
    ;;
  *)
    sketchybar --set "$NAME" icon="" label="Ethernet"
    ;;
esac
