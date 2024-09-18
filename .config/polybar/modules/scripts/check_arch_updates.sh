#!/bin/bash

# Check for updates
updates=$(yay -Qua | wc -l)

# Only print the number of updates if it's greater than 0
if [ "$updates" -gt 0 ]; then
    echo "%{F#fb4934}""%{F-} $updates"
fi
