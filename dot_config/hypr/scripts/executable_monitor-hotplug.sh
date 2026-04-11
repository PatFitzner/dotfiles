#!/bin/bash
# Disable the laptop panel whenever any external monitor is connected;
# re-enable it when none are.

LAPTOP="eDP-2"
LAPTOP_MODE="2560x1600@240,auto,1.25"

apply() {
  # Any monitor that isn't the laptop panel counts as "external"
  if hyprctl monitors -j | grep -q '"name": "[^"]*"' \
     && hyprctl monitors -j | grep '"name":' | grep -qv "\"$LAPTOP\""; then
    hyprctl keyword monitor "$LAPTOP,disable"
  else
    hyprctl keyword monitor "$LAPTOP,$LAPTOP_MODE"
  fi
}

# Initial state on launch
apply

# React to hotplug events from Hyprland's IPC
socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
while read -r line; do
  case $line in
    monitoradded*|monitorremoved*) apply ;;
  esac
done
