#!/usr/bin/env bash

ifname=$(ip link | awk -F: '$2 ~ /wl/{print $2}')
if [ ! -z "$ifname" ]; then
	if ! command -v nmcli &> /dev/null; then
		echo '{"text": "nmcli command not found", "class": "critical", "percentage": 0}'
	else
		# Remove trailing whitespace
		ifname=$(echo "${ifname}" | sed -e 's/^[ \t]*//')
		link=$(cat /sys/class/net/"$ifname"/carrier)
		if (( $link == 0 )); then
			echo '{"text": "No SSID selected", "class": "warning", "percentage": 0}'
		else
			ip=$(ip addr show $ifname | awk '$1 ~ /^inet$/ {printf "%s\n", $2}' | sed 's/\/.*//'| awk '$1 !~ /127.0.0.1$/ {printf "%s\n", $1}')
			if [ ! -z $ip ]; then
				ssid=$(nmcli -t -f active,ssid dev wifi | awk '/yes/ {print $1}' | awk -F ':' '{print $2}')
				ping_cmd=$(ping -I $ifname -c3 8.8.8.8 2> /dev/null)
				if [ $? -ne 0 ]; then
					echo '{"text": "'"$ssid [$ip] (ping error)"'", "class": "warning", "percentage": 100}'
					exit
				fi
				ping=$(echo "$ping_cmd" | awk '/transmitted/' | sed -e 's/.*, \(.*\)packet loss.*/\1/' | tr -d '%')
				# Convert float to int
				ping=${ping%.*}
				if (( $ping == 100 )); then
					# All packets lost
					echo '{"text": "'"$ssid [$ip]"'", "class": "critical", "percentage": 100}'
				elif (( $ping > 0 )); then
					# Some packets lost
					echo '{"text": "'"$ssid [$ip]"'", "class": "warning", "percentage": 100}'
				else
					# All packets received
					echo '{"text": "'"$ssid [$ip]"'", "percentage": 100}'
				fi
			else
				echo "%{u#fb4934}%{+u}睊  No IP%{u-}"
			fi
		fi
	fi
fi
