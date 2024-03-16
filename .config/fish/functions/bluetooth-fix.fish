function bluetooth-fix
    sudo rfkill block wlan && sudo modprobe -r btusb && sleep 10 && sudo modprobe btusb && systemctl --user restart pulseaudio && sudo systemctl restart bluetooth
end
