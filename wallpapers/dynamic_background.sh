#!/usr/bin/env bash

wallpaper[1]="$HOME/.config/wallpapers/zelda_ww_dawn.jpg"
wallpaper[2]="$HOME/.config/wallpapers/zelda_ww_sunrise.jpg"
wallpaper[3]="$HOME/.config/wallpapers/zelda_ww_sunset.jpg"
wallpaper[4]="$HOME/.config/wallpapers/zelda_ww_dusk.jpg"
tux_wallpaper="$HOME/.config/wallpapers/tux,png"

## Set the wallpaper
## To change wallpaper with swaybg on the fly we have to kill the PID
## of the old process(if other wallpaper has been set before) AFTER running the new process
## $1 the path to the new wallpaper
set_wallpaper() {
	local wallpaper=$1
	# Check if a swaybg process is running and register its PID
	OLD_PID=$(ps aux | grep "swaybg" | grep "fill" | awk '{print $2}')
	# Execute swaybg with the new wallpaper
	swaybg -i $wallpaper -m fill &
	# Kill the old process which contains the previous wallpaper
	if [ ! -z "$OLD_PID" ]; then
		kill $OLD_PID
	fi
}

## Put dawn / sunrise / sunset and dusk hours inside an array
## $1 the array which will contain the hours
get_sun_state_hours () {
	local sun_state_hours
	local sun_state_hours_found=0
	declare -n state_hours_array="$1"
	
	local nb_tries=1
	# Loop until all the sun state hours are found
	while [ "$sun_state_hours_found" -eq 0 ]; do
		# Get the sun state hours
		sun_state_hours=$(curl -s "wttr.in/Paris?format=%D\n%S\n%s\n%d")
		local index=1
		# For each entry we check if the date is in the correct format
		for sun_state_hour in $sun_state_hours; do
			date -d "$sun_state_hour"
			if [ $? -eq 0 ]; then
				state_hours_array[$index]=$(date -d "$sun_state_hour")
				sun_state_hours_found=1
			else
				sun_state_hours_found=0
				break 2
			fi
			((index++))
		done
		sleep 2
		# After 3 tries we set a default wallpaper
		if [ "$nb_tries" -eq 3 ]; then
			set_wallpaper $tux_wallpaper
		fi
		((nb_tries++))
	done
}

## Get the index to set for the wallpaper
## $1 the index to set
get_wallpaper_index_to_set() {
	local index=$1
	local current_time=$(date +%s)
	local found=0
	for (( x=1; x <= 4; x++ )); do
		local next_sun_time=$(date -d "${sun_infos[$x]}" +'%s')
		# If the current time is never minus than the sun hours it means the
		# next hour is the dawn because it's based with the actual day
		# Ex: dawn[Fri Jul 22 05:27:13 AM CEST 2022]
		#     current_time[Fri Jul 22 23:23:15 PM CEST 2022]
		if [ $current_time -lt $next_sun_time ]; then
			eval $index=$(($x-1))
			echo $index
			found=1
			break
		fi
	done
	# Current time never minus so we set the dusk wallpaper
	if [ "$found" -eq 0 ]; then
		eval $index=4
	fi
}

## Get the number of seconds to wait before set the next wallpaper
## $1 the number of seconds to wait
get_seconds_before_switching_wallpaper() {
	local next_wallpaper_time=$1
	# If the current wallpaper is the last one it means the next one is the dawn
	# So we have to set the day of the dawn at day+1 to calculate the seconds to wait
	# otherwise the seconds will be negative
	if [ "$current_wallpaper_index" -eq 4 ]; then
		local index=1
		sun_infos[$index]=$(date -d "${sun_infos[$index]} + 1 day")
		echo "${sun_infos[$index]}"
	else
		local index=$(($current_wallpaper_index+1))
	fi
	local current_time=$(date +%s)
	# Convert the date in seconds
	local next_sun_state_time=$(date -d "${sun_infos[$index]}" +'%s')
	# Time left before changing the wallpaper
	eval $next_wallpaper_time=$(($next_sun_state_time-$current_time))
}


first_set=1
declare -A sun_infos
get_sun_state_hours sun_infos
get_wallpaper_index_to_set current_wallpaper_index

set_wallpaper ${wallpaper[$current_wallpaper_index]}

get_seconds_before_switching_wallpaper next_time_switch

while :; do
	# Sleep until the next wallpaper to set
	sleep $next_time_switch
	# Only get sun state infos when start a new day. When the script starts
	# we get the informations already, so get them the next time the wallpaper
	# is set to dusk : it means the next one is the dawn so it's a new day
	# so new hours
	if [ "$first_set" -ne 1 ] && [ "$current_wallpaper_index" -eq 4 ]; then
		get_sun_state_hours sun_infos
	fi
	get_wallpaper_index_to_set current_wallpaper_index
	set_wallpaper ${wallpaper[$current_wallpaper_index]}
	get_seconds_before_switching_wallpaper next_time_switch
	first_set=0
done
