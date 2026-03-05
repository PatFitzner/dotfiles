#!/bin/bash
# For Chrome: fake fullscreen (compositor keeps window tiled, client thinks it's fullscreen)
# For everything else: real Hyprland fullscreen
class=$(hyprctl activewindow -j | python3 -c "import json,sys; print(json.load(sys.stdin).get('class',''))")
if [[ "$class" == "google-chrome" ]]; then
    hyprctl dispatch fullscreenstate 0 2 toggle
else
    hyprctl dispatch fullscreen 0
fi
