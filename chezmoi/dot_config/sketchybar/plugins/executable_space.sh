#!/usr/bin/env bash

# Switch to workspace $1 using omniwm's Hyper (Ctrl+Option+Cmd) + <n> hotkey.
# omniwm binds switchWorkspace.<n-1> to Hyper+<n> in settings.toml.
WS="$1"
[ -z "$WS" ] && exit 0

# key codes for number row 1-9 on macOS.
case "$WS" in
  1) KEY=18 ;;
  2) KEY=19 ;;
  3) KEY=20 ;;
  4) KEY=21 ;;
  5) KEY=23 ;;
  6) KEY=22 ;;
  7) KEY=26 ;;
  8) KEY=28 ;;
  9) KEY=25 ;;
  *) exit 0 ;;
esac

osascript -e "tell application \"System Events\" to key code $KEY using {control down, option down, command down}"
