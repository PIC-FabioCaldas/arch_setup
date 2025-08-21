#!/usr/bin/env bash
# filepath: /home/sozdc/arch_setup/scripts/.config/scripts/bttui.sh

#==============================================================================
# Bluetooth Terminal User Interface (BTTUI)
# A clean, terminal-based UI for managing Bluetooth devices
#==============================================================================

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------
TIMEOUT=10
VERSION="1.0.0"
AUTO_ENABLE=true

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------
show_notification() {
    echo -e "\n$1"
    read -p "Press Enter to continue..."
}

ensure_bluetooth_ready() {
    # Optionally skip automatic enabling
    if [ "$AUTO_ENABLE" != true ]; then
        return
    fi

    # Ensure Bluetooth is powered on
    if bluetoothctl show | grep -q "Powered: no"; then
        bluetoothctl power on
        sleep 1
    fi

    # Ensure Bluetooth is pairable
    if bluetoothctl show | grep -q "Pairable: no"; then
        bluetoothctl pairable on
        sleep 1
    fi
}

restore_bluetooth_state() {
    # Restore Bluetooth power state
    if [ -n "$initial_power_state" ]; then
        if [ "$initial_power_state" = "yes" ]; then
            bluetoothctl power on
        else
            bluetoothctl power off
        fi
    fi

    # Restore Bluetooth pairable state
    if [ -n "$initial_pairable_state" ]; then
        if [ "$initial_pairable_state" = "yes" ]; then
            bluetoothctl pairable on
        else
            bluetoothctl pairable off
        fi
    fi
}

execute_bluetooth_command() {
    local cmd="$1"
    local mac="$2"
    local desc="$3"
    
    echo "$desc..."
    
    # For connect command, add timeout equal to TIMEOUT
    if [ "$cmd" = "connect" ]; then
        echo "Attempting to connect (timeout: ${TIMEOUT}s)..."
        
        # Use timeout command to limit the connection attempt duration
        result=$(timeout "$TIMEOUT" bluetoothctl "$cmd" "$mac" 2>&1)
        
        # Check if connection timed out
        if [ $? -eq 124 ]; then
            result="Connection attempt timed out after ${TIMEOUT} seconds."
        fi
    else
        # For other commands, execute normally
        result=$(bluetoothctl "$cmd" "$mac" 2>&1)
    fi
    
    echo -e "\n$result"
    read -p "Press Enter to continue..."
}

#------------------------------------------------------------------------------
# Device Management Functions
#------------------------------------------------------------------------------
scan_for_devices() {
    ensure_bluetooth_ready
    
    echo -e "\nScanning for Bluetooth devices..."
    
    # Clear any previous device list
    bluetoothctl devices Clear &>/dev/null
    
    # Start scanning with countdown
    bluetoothctl --timeout $TIMEOUT scan on &>/dev/null &
    scan_pid=$!
    
    for ((i=TIMEOUT; i>0; i--)); do
        # Clear the line completely before printing
        echo -ne "\033[2K\r"
        
        # Print the appropriate message
        if [ $i -eq 1 ]; then
            echo -ne "Scanning... $i second remaining"
        else
            echo -ne "Scanning... $i seconds remaining"
        fi
        
        # Move cursor to beginning of line for next iteration
        echo -ne "\r"
        sleep 1
    done
    echo -e "\nScan complete"
    
    # Ensure scan is stopped
    kill $scan_pid 2>/dev/null
    bluetoothctl scan off &>/dev/null
    
    # Get list of discovered devices
    devices=$(bluetoothctl devices | grep "^Device" | awk '{print $2 " " substr($0, index($0,$3))}')
    
    if [[ -z "$devices" ]]; then
        show_notification "No devices found"
        return
    fi
    
    # Enhance device list with better names
    enhanced_devices=""
    while IFS= read -r dev; do
        if [[ -n "$dev" ]]; then
            mac=$(echo "$dev" | awk '{print $1}')
            default_name=$(echo "$dev" | awk '{$1=""; print substr($0,2)}')
            default_name="${default_name# }"  # Trim leading space
            
            # Try to get a better name for the device
            device_info=$(bluetoothctl info "$mac")
            better_name=$(echo "$device_info" | grep -E "Name:|Alias:" | head -n 1 | cut -d':' -f2- | xargs)
            
            if [[ -n "$better_name" && "$better_name" != "$mac" ]]; then
                enhanced_devices+="$mac  $better_name"$'\n'
            else
                enhanced_devices+="$dev"$'\n'
            fi
        fi
    done <<< "$devices"
    
    # Present enhanced device list to user
    dev=$(echo "$enhanced_devices" | fzf --prompt="Select device > ") || return
    
    mac=$(echo "$dev" | awk '{print $1}')
    name=$(echo "$dev" | awk '{$1=""; print substr($0,2)}')
    name="${name# }"  # Trim leading space
    
    device_menu "$mac" "$name"
}

list_paired_devices() {
    ensure_bluetooth_ready
    
    echo -e "\nFetching paired devices..."
    
    # Try multiple approaches to extract device info
    devices=""
    
    # Method 1: Standard method
    devices=$(echo "paired-devices" | bluetoothctl | grep "^Device" | awk '{print $2 " " substr($0, index($0,$3))}')
    
    # Method 2: If that didn't work, try other methods
    if [[ -z "$devices" ]]; then
        devices=$(bluetoothctl devices | grep "^Device" | awk '{print $2 " " substr($0, index($0,$3))}')
        
        # Filter for paired devices only
        if [[ -n "$devices" ]]; then
            temp_devices=""
            while IFS= read -r dev; do
                mac=$(echo "$dev" | awk '{print $1}')
                if bluetoothctl info "$mac" | grep -q "Paired: yes"; then
                    temp_devices+="$dev"$'\n'
                fi
            done <<< "$devices"
            devices="$temp_devices"
        fi
    fi
    
    # Check if any devices were found
    if [[ -z "$devices" ]]; then
        echo -e "\nNo paired devices found."
        echo "Try scanning for devices and pairing first."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Enhance device list with better names
    enhanced_devices=""
    while IFS= read -r dev; do
        if [[ -n "$dev" ]]; then
            mac=$(echo "$dev" | awk '{print $1}')
            
            # Try to get a better name for the device
            device_info=$(bluetoothctl info "$mac")
            better_name=$(echo "$device_info" | grep -E "Name:|Alias:" | head -n 1 | cut -d':' -f2- | xargs)
            
            if [[ -n "$better_name" ]]; then
                enhanced_devices+="$mac  $better_name"$'\n'
            else
                enhanced_devices+="$dev"$'\n'
            fi
        fi
    done <<< "$devices"
    
    # Present enhanced device list to user
    dev=$(echo "$enhanced_devices" | fzf --prompt="Select paired device > ") || return
    
    mac=$(echo "$dev" | awk '{print $1}')
    name=$(echo "$dev" | awk '{$1=""; print substr($0,2)}')
    name="${name# }"  # Trim leading space
    
    device_menu "$mac" "$name"
}

device_menu() {
    local mac="$1"
    local name="$2"
    
    # If name is empty or same as MAC, try to get a better name
    if [[ -z "$name" || "$name" == "$mac" ]]; then
        local info_output=$(bluetoothctl info "$mac")
        local better_name=$(echo "$info_output" | grep -E "Name:|Alias:" | head -n 1 | cut -d':' -f2- | xargs)
        
        if [[ -n "$better_name" ]]; then
            name="$better_name"
        fi
    fi
    
    # Clean up the name
    if [[ -n "$name" ]]; then
        name=$(echo "$name" | xargs)
    fi
    
    # Make sure we have a display name
    local display_name="${name:-$mac}"
    
    while true; do
        choice=$(printf "Connect\nDisconnect\nPair\nTrust\nTrust + Pair + Connect\nInfo\nRemove\nBack" | 
                 fzf --prompt="Device: $display_name > ")
        
        case "$choice" in
            "Connect") 
                # Check if device is already connected before attempting to connect
                if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
                    echo -e "\nDevice is already connected!"
                    read -p "Press Enter to continue..."
                else
                    execute_bluetooth_command "connect" "$mac" "Connecting to device" 
                fi
                ;;
                
            "Disconnect") 
                execute_bluetooth_command "disconnect" "$mac" "Disconnecting from device" ;;
                
            "Pair") 
                echo -e "\nMake sure device is in pairing mode..."
                execute_bluetooth_command "pair" "$mac" "Pairing with device" ;;
                
            "Trust") 
                execute_bluetooth_command "trust" "$mac" "Trusting device" ;;
                
            "Trust + Pair + Connect")
                echo -e "\nStarting comprehensive pairing sequence..."
                
                echo "Step 1: Trusting device"
                bluetoothctl trust "$mac"
                sleep 1
                
                echo -e "\nStep 2: Pairing with device"
                echo "Make sure device is in pairing mode!"
                bluetoothctl pair "$mac"
                sleep 2
                
                echo -e "\nStep 3: Checking connection status"
                if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
                    echo "Device is already connected!"
                else
                    echo "Connecting to device (timeout: ${TIMEOUT}s)..."
                    timeout "$TIMEOUT" bluetoothctl connect "$mac"
                    
                    # Check if connection timed out
                    if [ $? -eq 124 ]; then
                        echo "Connection attempt timed out after ${TIMEOUT} seconds."
                    fi
                fi
                
                read -p "Press Enter to continue..."
                ;;
                
            "Info")
                echo -e "\nDevice Information:"
                bluetoothctl info "$mac" | grep -v "^Controller" | grep -v "^$"
                read -p "Press Enter to continue..."
                ;;
                
            "Remove") 
                execute_bluetooth_command "remove" "$mac" "Removing device" ;;
                
            "Back") 
                return ;;
        esac
    done
}

#------------------------------------------------------------------------------
# Information Display Functions
#------------------------------------------------------------------------------
show_bluetooth_status() {
    echo -e "\nBluetooth Adapter Status"
    echo "=========================="
    bluetoothctl show | grep -E "Name|Powered|Discoverable|Pairable|Controller" 
    
    echo -e "\nConnected Devices"
    echo "================="
    if ! bluetoothctl info | grep -q "Device"; then
        echo "No connected devices"
    else
        bluetoothctl info
    fi
    
    read -p "Press Enter to continue..."
}

#------------------------------------------------------------------------------
# Bluetooth State Management Submenu
#------------------------------------------------------------------------------
bsm_submenu() {
    while true; do
        choice=$(printf "Show Bluetooth status\nRestart Bluetooth service\nToggle Bluetooth power\nToggle Bluetooth discoverable\nBack to main menu" | 
                fzf --prompt="Bluetooth State Management > ")
        
        case "$choice" in
            "Show Bluetooth status")
                show_bluetooth_status ;;
                
            "Restart Bluetooth service")
                echo -e "\nRestarting Bluetooth service..."
                sudo systemctl restart bluetooth
                sleep 2
                echo "Bluetooth service restarted"
                read -p "Press Enter to continue..." ;;
                
            "Toggle Bluetooth power")
                if bluetoothctl show | grep -q "Powered: no"; then
                    echo -e "\nTurning Bluetooth on..."
                    bluetoothctl power on
                    echo "Bluetooth powered on"
                else
                    echo -e "\nTurning Bluetooth off..."
                    bluetoothctl power off
                    echo "Bluetooth powered off"
                fi
                read -p "Press Enter to continue..." ;;
                
            "Toggle Bluetooth discoverable")
                if bluetoothctl show | grep -q "Discoverable: no"; then
                    echo -e "\nMaking Bluetooth discoverable..."
                    bluetoothctl discoverable on
                    echo "Bluetooth is now discoverable"
                else
                    echo -e "\nMaking Bluetooth non-discoverable..."
                    bluetoothctl discoverable off
                    echo "Bluetooth is now hidden"
                fi
                read -p "Press Enter to continue..." ;;
                
            "Back to main menu")
                return ;;
                
            *)
                echo "Invalid selection" ;;
        esac
    done
}

#------------------------------------------------------------------------------
# Main Program
#------------------------------------------------------------------------------
main() {
    # Parse command-line flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-enable|-s)
                AUTO_ENABLE=false
                shift ;;
            *)
                echo "Usage: $(basename "$0") [--skip-enable]" >&2
                exit 1 ;;
        esac
    done

    # Check dependencies
    if ! command -v bluetoothctl &>/dev/null; then
        echo "Error: bluetoothctl not found. Install bluez-utils first."
        exit 1
    fi

    if ! command -v fzf &>/dev/null; then
        echo "Error: fzf not found. Install fzf first."
        exit 1
    fi

    # Store initial Bluetooth states
    initial_power_state=$(bluetoothctl show | awk '/Powered:/ {print $2}')
    initial_pairable_state=$(bluetoothctl show | awk '/Pairable:/ {print $2}')
    trap restore_bluetooth_state EXIT

    # Ensure Bluetooth is ready
    ensure_bluetooth_ready

    # Main menu loop
    while true; do
        # Build menu options
        menu_options="Scan for devices\nList paired devices\nBSM (Bluetooth State Management)\nExit"
        
        choice=$(printf "$menu_options" | fzf --prompt="Bluetooth TUI > ")
        
        case "$choice" in
            "Scan for devices")
                scan_for_devices ;;
                
            "List paired devices")
                list_paired_devices ;;
                
            "BSM (Bluetooth State Management)")
                bsm_submenu ;;
                
            "Exit")
                echo -e "\nThank you for using BTTUI!"
                exit 0 ;;
                
            *)
                echo "Invalid selection" ;;
        esac
    done
}

# Start the program
main "$@"
