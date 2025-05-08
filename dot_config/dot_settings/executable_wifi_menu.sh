#!/usr/bin/env bash

# Get current WiFi status
wifi_status=$(nmcli -t -f WIFI g)
toggle_icon_enabled="󰖪  Disable Wi-Fi"
toggle_icon_disabled="󰖩  Enable Wi-Fi"
toggle=""
if [[ "$wifi_status" == "enabled" ]]; then
    toggle="$toggle_icon_enabled"
else
    toggle="$toggle_icon_disabled"
fi

# Get currently connected SSID
current_ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)

# Get list of saved connections
saved_connections=$(nmcli -g NAME connection)

# Get all available networks, sort by SSID (first column)
available_networks=$(nmcli --terse --fields SSID,SECURITY,SIGNAL device wifi list | sed 1d)

# Process and categorize networks
connected_list=""
known_array=()
unknown_array=()

IFS=$'\n'
for line in $available_networks; do
    ssid=$(echo "$line" | cut -d: -f1)
	security=$(echo "$line" | cut -d: -f2)
	signal=$(echo "$line" | cut -d: -f3)

    # Skip empty or placeholder SSIDs
    if [[ -z "$ssid" || "$ssid" == "--" ]]; then
        continue
    fi

    icon=""  # open network icon
    [[ "$security" != "--" && -n "$security" ]] && icon=""

    display_line="$ssid"

    if [[ "$ssid" == "$current_ssid" ]]; then
        connected_list="󰖩  $display_line"
    elif echo "$saved_connections" | grep -Fxq "$ssid"; then
        known_array+=("󰤨  $display_line")
    else
        unknown_array+=("$icon  $display_line ($signal%)")
    fi
done

# Safely join arrays into strings with newlines only between elements
known_list=$(printf "%s\n" "${known_array[@]}")
unknown_list=$(printf "%s\n" "${unknown_array[@]}")

# Compose final list for rofi
new_connection_entry="󰏖  New Connection"
rescan_entry="  Rescan Wi-Fi"
menu_list="$toggle"

menu_list+="\n$rescan_entry"
[[ -n "$connected_list" ]] && menu_list+="\n$connected_list"
[[ -n "$known_list" ]]     && menu_list+="\n$known_list"
[[ -n "$unknown_list" ]]   && menu_list+="\n$new_connection_entry"

# Rofi menu
chosen_network=$(echo -e "$menu_list" | rofi -dmenu -i -selected-row 2 -p "Wi-Fi SSID: ")

# Extract SSID
read -r chosen_id <<< "${chosen_network#* }"

# Action handling
if [[ -z "$chosen_network" ]]; then
    exit
elif [[ "$chosen_network" == "$toggle_icon_disabled" ]]; then
    nmcli radio wifi on
elif [[ "$chosen_network" == "$toggle_icon_enabled" ]]; then
    nmcli radio wifi off
elif [[ "$chosen_network" == "$rescan_entry" ]]; then
    notify-send "Wi-Fi" "Scanning for networks..."
    nmcli device wifi rescan
    sleep 1
    exec "$0"
elif [[ "$chosen_network" == "$new_connection_entry" ]]; then
    exec "~/.config/.settings/wifi_new_connection_menu.sh"
fi

