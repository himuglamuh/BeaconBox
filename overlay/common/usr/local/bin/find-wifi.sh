#!/bin/bash
# Finds the first wireless interface and writes it to a known location for other services to use

WIFI_IFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')

if [ -n "$WIFI_IFACE" ]; then
    echo "$WIFI_IFACE" > /run/beaconbox-wifi-interface
    echo "Detected wireless interface: $WIFI_IFACE"
else
    echo "No wireless interface found"
    exit 1
fi
