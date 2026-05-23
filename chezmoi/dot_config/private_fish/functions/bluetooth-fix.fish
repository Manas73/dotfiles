function bluetooth-fix --description "Fix Bluetooth connectivity issues"
    argparse h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: bluetooth-fix [OPTIONS]"
        echo ""
        echo "Fix Bluetooth connectivity issues by reloading modules and restarting services."
        echo ""
        echo "Options:"
        echo "  --help, -h      Show this help message"
        echo ""
        echo "Note: This command requires sudo privileges."
        return 0
    end

    sudo rfkill block wlan && sudo modprobe -r btusb && sleep 10 && sudo modprobe btusb && systemctl --user restart pulseaudio && sudo systemctl restart bluetooth
end
