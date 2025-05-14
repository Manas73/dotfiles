#!/usr/bin/env bash

# Function to format a single device with an icon
format_device() {
    local device="$1"
    local icon="$2"

    if [ -n "$device" ]; then
        local device_mac=$(echo "$device" | awk '{print $2}')
        # Extract everything after the MAC address as the device name
        local device_name=$(echo "$device" | awk '{$1=""; $2=""; sub(/^ */, ""); print}')
        echo "$icon  $device_name ($device_mac)"
    fi
}

# Function to format a list of devices with an icon
format_device_list() {
    local device_list="$1"
    local icon="$2"
    local formatted_list=""

    while IFS= read -r device; do
        if [ -n "$device" ]; then
            formatted_device=$(format_device "$device" "$icon")
            if [ -n "$formatted_device" ]; then
                formatted_list+="$formatted_device"$'\n'
            fi
        fi
    done <<< "$device_list"

    echo "$formatted_list"
}

# Check if bluetooth is enabled
bluetooth_status=$(bluetoothctl show | grep "Powered" | awk '{print $2}')

if [[ "$bluetooth_status" == "yes" ]]; then
    toggle="󰂲  Disable Bluetooth"
else
    toggle="󰂯  Enable Bluetooth"
fi

# Get list of paired devices
paired_devices=$(bluetoothctl devices)

# Get list of connected devices
connected_devices=$(bluetoothctl devices Connected)

# Create a list of paired but not connected devices
disconnected_devices=""
while IFS= read -r device; do
    device_mac=$(echo "$device" | awk '{print $2}')
    if ! echo "$connected_devices" | grep -q "$device_mac"; then
        disconnected_devices+="$device"$'\n'
    fi
done <<< "$paired_devices"

# Format the connected and disconnected devices
formatted_connected=$(format_device_list "$connected_devices" "󰂱")
formatted_disconnected=$(format_device_list "$disconnected_devices" "󰂲")

# Combine all options
options="$formatted_connected\n$toggle\n$formatted_disconnected"

# Use rofi to select a device with the calculated selected row
chosen_option=$(echo -e "$options" | awk NF | rofi -dmenu -i -p "Bluetooth: ")

if [ -z "$chosen_option" ]; then
    exit 0
elif [ "$chosen_option" = "󰂯  Enable Bluetooth" ]; then
    bluetoothctl power on
    notify-send "Bluetooth" "Bluetooth has been enabled"
elif [ "$chosen_option" = "󰂲  Disable Bluetooth" ]; then
    bluetoothctl power off
    notify-send "Bluetooth" "Bluetooth has been disabled"
else
    # Extract the MAC address from the chosen option
    device_mac=$(echo "$chosen_option" | grep -o -E '([0-9A-F]{2}:){5}[0-9A-F]{2}')
    device_name=$(echo "$chosen_option" | sed -E 's/^.{2} (.*) \([0-9A-F:]+\)$/\1/')

    if [[ "$chosen_option" == 󰂱* ]]; then
        # Disconnect from the device
        bluetoothctl disconnect "$device_mac"
        notify-send "Bluetooth" "Disconnected from $device_name"
    else
        # Connect to the device
        bluetoothctl connect "$device_mac"

        # Check if connection was successful
        if bluetoothctl info "$device_mac" | grep -q "Connected: yes"; then
            notify-send "Bluetooth" "Connected to $device_name"
        else
            notify-send "Bluetooth" "Failed to connect to $device_name"

            # Try to fix common Bluetooth issues
            notify-send "Bluetooth" "Attempting to fix Bluetooth connection..."
            sudo rfkill block wlan && sudo modprobe -r btusb && sleep 5 && sudo modprobe btusb && systemctl --user restart pulseaudio && sudo systemctl restart bluetooth
            sleep 2

            # Try connecting again
            bluetoothctl connect "$device_mac"
            if bluetoothctl info "$device_mac" | grep -q "Connected: yes"; then
                notify-send "Bluetooth" "Connected to $device_name after fix"
            else
                notify-send "Bluetooth" "Still unable to connect to $device_name"
            fi
        fi
    fi
fi
