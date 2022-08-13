#!/usr/bin/env bash

# Get all displays connected
displays=$(swaymsg -t get_outputs | jq -r '.[] | .name')

count=1
# For each display connected: take a screenshot, add the blur effect and build the string for swaylock
for display in $displays; do
	grim -o "$display" "$HOME/.config/wallpapers/lock_$count.png"
	convert "$HOME/.config/wallpapers/lock_$count.png" -filter Gaussian -blur 0x6 "$HOME/.config/wallpapers/lock_$count.png"
	swaylock_arg+="-i $display:$HOME/.config/wallpapers/lock_$count.png "
	((count++))
done

#Lock all the connected displays
swaylock $swaylock_arg
