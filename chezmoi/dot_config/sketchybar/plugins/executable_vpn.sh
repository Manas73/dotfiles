#!/usr/bin/env bash

# Detect an active VPN/utun tunnel with an assigned address.
# Hides the module when no VPN is up (mirrors waybar's empty format).
VPN_UP=$(scutil --nc list 2>/dev/null | grep -c '^\* (Connected)')

if [ "$VPN_UP" = "0" ]; then
  # Fall back to checking utun interfaces with a peer address (WireGuard etc).
  for iface in $(ifconfig -l | tr ' ' '\n' | grep '^utun'); do
    if ifconfig "$iface" 2>/dev/null | grep -q 'inet .* -->'; then
      VPN_UP=1
      break
    fi
  done
fi

if [ "$VPN_UP" = "0" ]; then
  sketchybar --set "$NAME" drawing=off
else
  NAME_STR=$(scutil --nc list 2>/dev/null | awk -F'"' '/\* \(Connected\)/ {print $2; exit}')
  [ -z "$NAME_STR" ] && NAME_STR="VPN"
  sketchybar --set "$NAME" drawing=on label="$NAME_STR"
fi
