#!/bin/bash

wallpaper_engine=$(cat $HOME/.config/.settings/wallpaper_engine.sh)
if [ "$wallpaper_engine" == "swww" ] ;then
    # swww
    echo ":: Using swww"
    swww-daemon --format xrgb
    sleep 0.5
    swww img $HOME/Pictures/Wallpapers/spring_bloom.jpg
else
    echo ":: Wallpaper Engine disabled"
fi
