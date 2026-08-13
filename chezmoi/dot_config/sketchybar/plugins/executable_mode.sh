#!/usr/bin/env bash

# Reads the current omniwm default layout type as a "mode" indicator,
# analogous to waybar's hyprland/submap module.
SETTINGS="$HOME/.config/omniwm/settings.toml"

LAYOUT="dwindle"
if [ -f "$SETTINGS" ]; then
  VAL=$(awk -F' = ' '/^defaultLayoutType/ {gsub(/"/,"",$2); print $2; exit}' "$SETTINGS")
  [ -n "$VAL" ] && LAYOUT="$VAL"
fi

sketchybar --set "$NAME" label="$LAYOUT"
