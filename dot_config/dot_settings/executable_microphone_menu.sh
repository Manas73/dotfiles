#!/usr/bin/env bash

# Functions
get_current_source_name() {
    pactl info | grep 'Default Source:' | cut -d' ' -f3
}

get_current_source_description() {
    local current_source_name=$(get_current_source_name)
    pactl list sources | grep -A10 "Name: $current_source_name" | grep 'Description:' | cut -d: -f2- | sed 's/^ *//g'
}

get_audio_sources() {
    pactl list short sources | grep -v '\.monitor' | grep 'alsa_input.*analog' | awk '{print $1, $2}'
}

get_toggle_option() {
    local current_source_name=$(get_current_source_name)
    if [[ -n "$current_source_name" ]]; then
        local is_muted=$(pactl get-source-mute "$current_source_name" | grep -c "yes")
        if [[ "$is_muted" -eq 1 ]]; then
            echo "   Enable Microphone"
        else
            echo "󰍭  Disable Microphone"
        fi
    else
        echo "  Enable Microphone"
    fi
}

# Get lists
audio_sources=$(get_audio_sources)
current_device=$(get_current_source_description)

# Build audio list, excluding the current device and filtering for analog inputs only
audio_list=$(
    while read -r source_info; do
        source_name=$(echo "$source_info" | awk '{print $2}')
        source_description=$(pactl list sources | grep -A10 "Name: $source_name" | grep 'Description:' | cut -d: -f2- | sed 's/^ *//g')
        if [[ "$source_description" != "$current_device" ]]; then
            echo "$source_description"
        fi
    done <<< "$audio_sources"
)

toggle=$(get_toggle_option)

# Map descriptions to names
declare -A description_to_name
while read -r source_info; do
    source_index=$(echo "$source_info" | awk '{print $1}')
    source_name=$(echo "$source_info" | awk '{print $2}')
    source_description=$(pactl list sources | grep -A10 "Name: $source_name" | grep 'Description:' | cut -d: -f2- | sed 's/^ *//g')
    description_to_name["$source_description"]="$source_name"
done <<< "$audio_sources"

# Compile list for rofi, excluding the current device
rofi_list="$current_device\n$toggle\n$audio_list"

# Show using rofi
selection=$(echo -e "$rofi_list" | rofi -dmenu -i -selected-row 1 -p "Microphone Device: ")

# If no selection was made, exit
if [ -z "$selection" ]; then
    exit
fi

# Check if the current selection is the toggle
if [[ "$selection" == "$toggle" ]]; then
    current_source_name=$(get_current_source_name)
    if [[ -n "$current_source_name" ]]; then
        pactl set-source-mute "$current_source_name" toggle
    fi
    exit 0
fi

# Find and set the new default source
source_name="${description_to_name["$selection"]}"
if [ -n "$source_name" ]; then
    pactl set-default-source "$source_name"

    # Move all recording streams to the new source
    pactl list short source-outputs | while read -r stream; do
        stream_id=$(echo "$stream" | cut -f1)
        pactl move-source-output "$stream_id" "$source_name"
    done
else
    # If the source isn't set properly, notify the user
    notify-send "Error" "Failed to set the microphone source."
fi
