#!/usr/bin/env bash

# Path to your colors.ini file
colors_file="$HOME/.config/polybar/colors.ini"

# Read colors from the colors.ini file
fg_color=$(grep -oP '(?<=^fg = )#.*' "$colors_file")
green_color=$(grep -oP '(?<=^green = )#.*' "$colors_file")
red_color=$(grep -oP '(?<=^red = )#.*' "$colors_file")

# Get the current default sink
sink=$(pactl info | grep "Default Sink" | cut -d ' ' -f3)

# Get the current volume and mute status
volume=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -1)
mute=$(pactl get-sink-mute @DEFAULT_SINK@ | grep -oP '(yes|no)')

# Set icons based on the current sink
if [[ "$sink" == "alsa_output.usb-SteelSeries_Arctis_7_-00.analog-stereo" ]]; then
    icon=""  # headphone icon
else
    icon=""
fi

# Choose icon color based on mute status
if [ "$mute" == "yes" ]; then
    icon_color="%{F$red_color}"  # Red when muted
else
    icon_color="%{F$green_color}"  # Green when not muted
fi

# Set a separate color for the volume percentage
volume_color="%{F$fg_color}"  # Use foreground color from colors.ini

# Display the output with separate colors for icon and volume percentage
echo "$icon_color%{T0}$icon%{T-} $volume_color$volume%{F-}"