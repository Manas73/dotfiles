#!/bin/sh

BAR_HEIGHT=36  # polybar height
BORDER_SIZE=1  # border size from your wm settings
YAD_WIDTH=222  # 222 is minimum possible value
YAD_HEIGHT=193 # 193 is minimum possible value

case "$1" in
--popup)
    if [ "$(xdotool getwindowfocus getwindowname)" = "yad-calendar" ]; then
        exit 0
    fi

    eval "$(xdotool getmouselocation --shell)"
    eval "$(xdotool getdisplaygeometry --shell)"

    # Center horizontally on the monitor where the mouse is
    : $((pos_x = WIDTH / 2 - YAD_WIDTH / 2))

    # Position right below the polybar
    : $((pos_y = BAR_HEIGHT + BORDER_SIZE))

    yad --calendar --undecorated --fixed --close-on-unfocus --no-buttons \
        --width="$YAD_WIDTH" --height="$YAD_HEIGHT" --posx="$pos_x" --posy="$pos_y" \
        --title="yad-calendar" --borders=0 \
        --fontname="Sans 20" --text-align=center --padding=20 >/dev/null &
    ;;
*)
esac
