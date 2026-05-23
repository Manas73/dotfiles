#!/usr/bin/env bash

# All "custom" vpns, including WireGuard, are prefixed with "vpn-" or "wireguard-" as the tunnel name
VPN_NAME=$(nmcli -t -f NAME,TYPE,STATE con show --active | awk -F: '$2=="vpn" || $2=="wireguard" {print $1}')

if [[ "${VPN_NAME}" != "" ]]; then
  echo "%{F#5af78e}""%{F-} ${VPN_NAME} "
else
  echo "%{F#ff5c57}""%{F-}"
  echo "%{F#5af78e}""%{F-}"
fi
