#!/bin/bash
#                    __
#  _    _____ ___ __/ /  ___ _____
# | |/|/ / _ `/ // / _ \/ _ `/ __/
# |__,__/\_,_/\_, /_.__/\_,_/_/
#            /___/
#
# -----------------------------------------------------
# Quit all running waybar instances
# -----------------------------------------------------
killall waybar
pkill waybar
sleep 0.5

# -----------------------------------------------------
# Default theme: /THEMEFOLDER;/VARIATION
# -----------------------------------------------------
themestyle="/ml4w-modern;/ml4w-modern/light"
IFS=';' read -ra arrThemes <<<"$themestyle"
echo ":: Theme: ${arrThemes[0]}"

# -----------------------------------------------------
# Loading the configuration
# -----------------------------------------------------
config_file="config"
style_file="style.css"

waybar -c ~/.config/waybar/themes${arrThemes[0]}/$config_file -s ~/.config/waybar/themes${arrThemes[1]}/$style_file &