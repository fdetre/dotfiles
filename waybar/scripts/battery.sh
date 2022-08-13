#!/usr/bin/env bash

ls /sys/class/power_supply/BAT0/capacity &> /dev/null
if (( $? == 0 )); then
	battery_capacity=$(cat /sys/class/power_supply/BAT0/capacity)
	if [ $battery_capacity -lt 40 ]; then
		class="warning"
	elif [ $battery_capacity -lt 20 ]; then
		class="critical"
	fi
	battery_icon=$((battery_capacity-11))
	battery_status=$(cat /sys/class/power_supply/BAT0/status)
	if [ $battery_status == "Full" ]; then
		echo '{"text": '"$battery_capacity"', "percentage": '"$battery_icon"'}'
	elif [ $battery_status == "Discharging" ]; then
		echo '{"text": '"$battery_capacity"', "class": "'"$class"'", "percentage": '"$battery_icon"'}'
	else
		echo '{"text": '"$battery_capacity"', "percentage": 100}'
	fi
fi
