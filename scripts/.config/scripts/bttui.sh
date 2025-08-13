#!/usr/bin/env bash

# Ensure bluetoothctl is available
if ! command -v bluetoothctl &>/dev/null; then
    echo "bluetoothctl not found. Install bluez-utils first."
    exit 1
fi

# Turn on Bluetooth if it's off
bluetoothctl show | grep -q "Powered: no" && bluetoothctl power on

main_menu() {
    while true; do
        choice=$(printf "Scan for devices\nList paired devices\nExit" | fzf --prompt="Bluetooth > ")

        case "$choice" in
            "Scan for devices") scan_devices ;;
            "List paired devices") paired_devices ;;
            "Exit") exit 0 ;;
        esac
    done
}

scan_devices() {
    echo "Scanning for 5 seconds..."
    bluetoothctl scan on &>/dev/null &
    scan_pid=$!
    sleep 5
    kill $scan_pid 2>/dev/null
    bluetoothctl scan off &>/dev/null

    devices=$(bluetoothctl devices | awk '{print $2 " " substr($0, index($0,$3))}')
    [[ -z "$devices" ]] && echo "No devices found" && return

    dev=$(echo "$devices" | fzf --prompt="Select device > ") || return
    mac=$(echo "$dev" | awk '{print $1}')
    device_menu "$mac"
}

paired_devices() {
    devices=$(bluetoothctl paired-devices | awk '{print $2 " " substr($0, index($0,$3))}')
    [[ -z "$devices" ]] && echo "No paired devices" && return

    dev=$(echo "$devices" | fzf --prompt="Select paired device > ") || return
    mac=$(echo "$dev" | awk '{print $1}')
    device_menu "$mac"
}

device_menu() {
    mac=$1
    while true; do
        choice=$(printf "Connect\nDisconnect\nPair\nRemove\nBack" | fzf --prompt="$mac > ")

        case "$choice" in
            "Connect") bluetoothctl connect "$mac" ;;
            "Disconnect") bluetoothctl disconnect "$mac" ;;
            "Pair") bluetoothctl pair "$mac" ;;
            "Remove") bluetoothctl remove "$mac" ;;
            "Back") return ;;
        esac
    done
}

main_menu