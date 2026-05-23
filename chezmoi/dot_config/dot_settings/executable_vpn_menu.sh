#!/usr/bin/env bash

# Get a list of available VPN and WireGuard connections
vpn_list=$(nmcli -g NAME,TYPE connection show | grep -E "vpn|wireguard" | awk -F: '{if ($2 == "vpn") print "󰒋 " $1; else if ($2 == "wireguard") print "󰒋 " $1}')

# Check the current VPN or WireGuard connection status
vpn_active=$(nmcli -t -f NAME,TYPE connection show --active | grep -E "vpn|wireguard" | awk -F: '{print $1}')

if [[ -n "$vpn_active" ]]; then
	toggle="  Disconnect VPN ($vpn_active)"
else
	toggle="  No VPN Connected"
fi

# Use rofi to select a VPN or WireGuard connection
chosen_vpn=$(echo -e "$toggle\n$vpn_list" | rofi -dmenu -i -selected-row 1 -p "VPN: ")

# Get the name of the chosen VPN
read -r chosen_id <<< "${chosen_vpn:2}"

if [ "$chosen_vpn" = "" ]; then
	exit
elif [[ "$chosen_vpn" == "  Disconnect VPN ($vpn_active)" ]]; then
	# Disconnect the current VPN or WireGuard connection
	nmcli connection down "$vpn_active"
	# notify-send "VPN Disconnected" "You have disconnected from \"$vpn_active\"."
else
	# Connect to the chosen VPN or WireGuard
	nmcli connection up id "$chosen_id"
	# if [ $? -eq 0 ]; then
	# 	notify-send "VPN Connected" "You are now connected to \"$chosen_id\"."
	# else
	# 	notify-send "VPN Connection Failed" "Could not connect to \"$chosen_id\"."
	# fi
fi
