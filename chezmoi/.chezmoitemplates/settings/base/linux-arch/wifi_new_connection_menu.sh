#!/usr/bin/env bash

# Get all available networks
available_networks=$(nmcli --terse --fields SSID,SECURITY,SIGNAL device wifi list | sed 1d)

unknown_array=()
saved_connections=$(nmcli -g NAME connection)

IFS=$'\n'
for line in $available_networks; do
    ssid=$(echo "$line" | cut -d: -f1)
    security=$(echo "$line" | cut -d: -f2)
    signal=$(echo "$line" | cut -d: -f3)

    [[ -z "$ssid" || "$ssid" == "--" ]] && continue
    echo "$saved_connections" | grep -Fxq "$ssid" && continue

    icon=""
    [[ "$security" != "--" && -n "$security" ]] && icon=""
    unknown_array+=("$icon  $ssid ($signal%)")
done

unknown_list=$(printf "%s\n" "${unknown_array[@]}")
rescan_entry="  Rescan Wi-Fi"

# Show unknown networks in Rofi
chosen_network=$(echo -e "$rescan_entry\n$unknown_list" | rofi -markup-rows -dmenu -i -selected-row 1 -p "New Wi-Fi Network:")
[[ -z "$chosen_network" ]] && exit

if [[ "$chosen_network" == "$rescan_entry" ]]; then
    notify-send "Wi-Fi" "Rescanning..."
    nmcli device wifi rescan
    sleep 1
    exec "$0"
fi

chosen_id=$(echo "$chosen_network" | sed -E 's/^.*?  (.*) \([0-9]+%\)$/\1/')
selected_line=$(nmcli -t -f SSID,SECURITY device wifi list | awk -F: -v ssid="$chosen_id" '$1 == ssid { print; exit }')
security=$(echo "$selected_line" | cut -d: -f2)

if [[ "$security" != "--" && -n "$security" ]]; then
    wifi_password=$(rofi -dmenu -theme ~/.config/rofi/overlays/password.rasi -password -p "$chosen_id: ")
    [[ -z "$wifi_password" ]] && exit
    nmcli device wifi connect "$chosen_id" password "$wifi_password"
else
    nmcli device wifi connect "$chosen_id"
fi
