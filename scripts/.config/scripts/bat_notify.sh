#!/bin/bash

# RUN > systemctl --user enable --now .config/systemd/user/bat_notify.service
# WHEN CHANGES WERE MADE

BATTERY="/org/freedesktop/UPower/devices/battery_BAT0"
LOW_THRESHOLD=25
CRIT_THRESHOLD=10

while true; do
    PERCENT=$(upower -i "$BATTERY" | awk '/percentage:/ {gsub(/%/, "", $2); print $2}')
    STATE=$(upower -i "$BATTERY" | awk '/state:/ {print $2}')

    if [ "$STATE" = "discharging" ]; then
        if [ "$PERCENT" -le "$CRIT_THRESHOLD" ]; then
            notify-send -u critical "Battery Critical" "Battery at $PERCENT%! Plug in now!"
        elif [ "$PERCENT" -le "$LOW_THRESHOLD" ]; then
            notify-send -u normal "Battery Low" "Battery at $PERCENT%. You can  plug in the charger."
        fi
    fi

    sleep 300  # check every minute
done
