#!/usr/bin/env bash

# CPU usage percentage (100 - idle) from top.
CPU=$(top -l 1 -n 0 | awk -F'[ %]+' '/CPU usage/ {printf "%.0f", $3 + $5}')
[ -z "$CPU" ] && CPU=0

sketchybar --set "$NAME" label="${CPU}%"
