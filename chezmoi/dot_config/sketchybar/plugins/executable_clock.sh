#!/usr/bin/env bash

STATE_FILE="/tmp/sketchybar_clock_alt"

if [ "$1" = "toggle" ]; then
  if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"
  else
    touch "$STATE_FILE"
  fi
fi

if [ -f "$STATE_FILE" ]; then
  LABEL="$(date '+%Y-%m-%d %I:%M:%S %p')"
else
  LABEL="$(date '+%I:%M %p')"
fi

sketchybar --set "$NAME" label="$LABEL"
