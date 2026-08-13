#!/usr/bin/env bash

# Uses the volume_change event payload ($INFO) when available, else polls.
if [ -n "$INFO" ]; then
  VOLUME="$INFO"
else
  VOLUME=$(osascript -e 'output volume of (get volume settings)')
fi

MUTED=$(osascript -e 'output muted of (get volume settings)')

if [ "$MUTED" = "true" ]; then
  ICON="󰓄"
elif [ "$VOLUME" -eq 0 ]; then
  ICON="󰓄"
elif [ "$VOLUME" -lt 34 ]; then
  ICON="󰕿"
elif [ "$VOLUME" -lt 67 ]; then
  ICON="󰖀"
else
  ICON="󰓃"
fi

sketchybar --set "$NAME" icon="$ICON" label="${VOLUME}%"
