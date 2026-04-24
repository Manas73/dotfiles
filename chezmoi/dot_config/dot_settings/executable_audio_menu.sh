#!/usr/bin/env bash

# Functions
get_current_sink_name() {
    pactl info | grep 'Default Sink:' | cut -d' ' -f3
}

get_current_sink_description() {
    local current_sink_name=$(get_current_sink_name)
    pactl list sinks | grep -A10 "Name: $current_sink_name" | grep 'Description:' | cut -d: -f2- | sed 's/^ *//g'
}

get_audio_sinks() {
    pactl list short sinks | awk '{print $1, $2}'
}

get_toggle_option() {
    local current_sink_name=$(get_current_sink_name)
    if [[ -n "$current_sink_name" ]]; then
        local is_muted=$(pactl get-sink-mute "$current_sink_name" | grep -c "yes")
        if [[ "$is_muted" -eq 1 ]]; then
            echo "   Enable Audio"
        else
            echo "󰖁  Disable Audio"
        fi
    else
        echo "  Enable Audio"
    fi
}

# Get lists
audio_sinks=$(get_audio_sinks)
current_device=$(get_current_sink_description)

# Build audio list, excluding the current device
audio_list=$(pactl list sinks | grep -E 'Description:' | cut -d: -f2- | sed 's/^ *//g' | grep -v "^$current_device$")

toggle=$(get_toggle_option)

# Map descriptions to names
declare -A description_to_name
while read -r sink_info; do
    sink_index=$(echo "$sink_info" | awk '{print $1}')
    sink_name=$(echo "$sink_info" | awk '{print $2}')
    sink_description=$(pactl list sinks | grep -A10 "Name: $sink_name" | grep 'Description:' | cut -d: -f2- | sed 's/^ *//g')
    description_to_name["$sink_description"]="$sink_name"
done <<< "$audio_sinks"

# Compile list for rofi, excluding the current device
rofi_list="$current_device\n$toggle\n$audio_list"

# Show using rofi
selection=$(echo -e "$rofi_list" | rofi -dmenu -i -selected-row 1 -p "Audio Device: ")

# If no selection was made, exit
if [ -z "$selection" ]; then
    exit
fi

# Check if the current selection is the toggle
if [[ "$selection" == "$toggle" ]]; then
    current_sink_name=$(get_current_sink_name)
    if [[ -n "$current_sink_name" ]]; then
        pactl set-sink-mute "$current_sink_name" toggle
    fi
    exit 0
fi

# Find and set the new default sink
sink_name="${description_to_name["$selection"]}"
if [ -n "$sink_name" ]; then
    pactl set-default-sink "$sink_name"

    # Move all playing streams to the new sink
    pactl list short sink-inputs | while read -r stream; do
        stream_id=$(echo "$stream" | cut -f1)
        pactl move-sink-input "$stream_id" "$sink_name"
    done
else
    # If the sink isn't set properly, notify the user
    notify-send "Error" "Failed to set the audio sink."
fi
