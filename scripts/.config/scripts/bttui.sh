#!/usr/bin/env bash

# This is a Bluetooth Terminal User Interface (TUI) script
# It provides a simple menu-driven interface to manage Bluetooth devices

# --- INITIAL CHECKS ---
# Check if bluetoothctl command exists on the system
if ! command -v bluetoothctl &>/dev/null; then
    echo "bluetoothctl not found. Install bluez-utils first."
    exit 1  # Exit with error code 1 if bluetoothctl is not installed
fi

# --- BLUETOOTH POWER CHECK ---
# Turn on Bluetooth if it's currently powered off
# The grep command checks if "Powered: no" exists in the output
# If found, power on Bluetooth
bluetoothctl show | grep -q "Powered: no" && bluetoothctl power on

# --- MAIN MENU FUNCTION ---
# This function displays the main menu options and handles user selection
main_menu() {
    while true; do  # Loop forever until user selects "Exit"
        # Display menu with fzf (fuzzy finder) and store user selection in "choice"
        choice=$(printf "Scan for devices\nList paired devices\nExit" | fzf --prompt="Bluetooth > ")

        # Execute different functions based on user's selection
        case "$choice" in
            "Scan for devices") scan_devices ;;      # Call scan_devices function
            "List paired devices") paired_devices ;; # Call paired_devices function
            "Exit") exit 0 ;;                        # Exit the script with success code 0
        esac
    done
}

# --- SCAN FOR DEVICES FUNCTION ---
# This function scans for available Bluetooth devices
scan_devices() {
    echo "Scanning for 5 seconds..."
    # Start scanning in background (hide output with &>/dev/null)
    # & at the end makes it run in background
    bluetoothctl scan on &>/dev/null &
    scan_pid=$!  # Store the process ID of the background scan
    sleep 5      # Wait for 5 seconds
    kill $scan_pid 2>/dev/null  # Kill the scanning process
    bluetoothctl scan off &>/dev/null  # Turn off scanning

    # Get list of discovered devices, format with awk
    # awk extracts MAC address and device name
    devices=$(bluetoothctl devices | awk '{print $2 " " substr($0, index($0,$3))}')
    
    # Check if no devices were found
    [[ -z "$devices" ]] && echo "No devices found" && return

    # Show list of devices with fzf and let user select one
    dev=$(echo "$devices" | fzf --prompt="Select device > ") || return
    # Extract the MAC address from the selected device
    mac=$(echo "$dev" | awk '{print $1}')
    # Open device-specific menu for the selected device
    device_menu "$mac"
}

# --- PAIRED DEVICES FUNCTION ---
# This function shows already paired Bluetooth devices
paired_devices() {
    # Use echo to send command to bluetoothctl in non-interactive mode
    # grep filters for lines containing "Device"
    # awk formats the output to show MAC address and device name
    devices=$(echo "paired-devices" | bluetoothctl | grep "Device" | awk '{print $2 " " substr($0, index($0,$3))}')
    
    # If no paired devices found, show message and wait for user acknowledgment
    if [[ -z "$devices" ]]; then
        echo "No paired devices" | fzf --prompt="Press Enter to continue > "
        return  # Return to main menu
    fi

    # Show list of paired devices with fzf and let user select one
    dev=$(echo "$devices" | fzf --prompt="Select paired device > ") || return
    # Extract the MAC address from the selected device
    mac=$(echo "$dev" | awk '{print $1}')
    # Open device-specific menu for the selected device
    device_menu "$mac"
}

# --- DEVICE MENU FUNCTION ---
# This function shows actions that can be performed on a specific device
device_menu() {
    mac=$1  # Store the MAC address passed to this function
    while true; do  # Loop until user selects "Back"
        # Display device-specific menu with fzf
        choice=$(printf "Connect\nDisconnect\nPair\nRemove\nBack" | fzf --prompt="$mac > ")

        # Execute different bluetoothctl commands based on user selection
        case "$choice" in
            "Connect") bluetoothctl connect "$mac" ;;      # Connect to device
            "Disconnect") bluetoothctl disconnect "$mac" ;; # Disconnect from device
            "Pair") bluetoothctl pair "$mac" ;;           # Pair with device
            "Remove") bluetoothctl remove "$mac" ;;       # Remove/unpair device
            "Back") return ;;                             # Return to previous menu
        esac
    done
}

# --- SCRIPT EXECUTION STARTS HERE ---
# Call the main menu function to start the script
main_menu