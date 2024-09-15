#!/usr/bin/env bash

# Get a list of available audio sinks (output devices)
audio_list=$(pactl list sinks | grep -E 'Description:' | cut -d: -f2- | sed 's/^ *//g')

# Check the current status of PulseAudio
is_enabled=$(pactl info | grep 'Default Sink:' | cut -d' ' -f3)

# Define toggle option based on audio status
if [[ -n "$is_enabled" ]]; then
    toggle="󰖪  Disable Audio"
else
    toggle="󰖩  Enable Audio"
fi

# Use rofi to select an audio output device
chosen_device=$(echo -e "$toggle\n$audio_list" | rofi -dmenu -i -selected-row 1 -p "Audio Device: ")

# Check if the user pressed cancel or made no selection
if [ -z "$chosen_device" ]; then
    exit
fi

# Find the index of the selected device (zero-based)
index=0
chosen_id=""

# Loop through the list of devices to find the index of the chosen device
while read -r line; do
    if [[ "$line" == "$chosen_device" ]]; then
        chosen_id=$index
        break
    fi
    ((index++))
done <<< "$audio_list"

# Set the selected device as the default sink using the index
sink_name=$(pactl list short sinks | awk -v idx="$chosen_id" 'NR==idx+1 {print $2}')

if [ -n "$sink_name" ]; then
    pactl set-default-sink "$sink_name"
fi
