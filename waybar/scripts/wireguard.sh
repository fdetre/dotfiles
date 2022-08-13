#!/usr/bin/env bash

continue=1

FILE="$HOME/.config/waybar/scripts/wireguard_monitoring"
GATEWAY="192.168.1.254"
## Select the interface to monitor
select_interface() {
	ifnames=$(ip link | awk -F: '$0 !~ "vir|wl|lo|tun|docker|eth|enx|eno|enp"{print $2}')
	count=0
	if [ -e "$FILE" ]; then
		iface_in_file=$(cat "$FILE")
	fi
	while IFS= read -r ifname; do
		if [ "$ifname" = "$iface_in_file" ]; then
			current_selected_interface=$count
		fi
		((count++))
	done <<< "$ifnames"
	echo "$value"
	if [ ! -z "$ifnames" ]; then
		# Display the rofi menu with all the sinks available
		chosen_interface="$(echo -e "$ifnames" | rofi -dmenu -p "[Network] Select the interface to monitor" -lines $count -a $current_selected_interface )"
		# If cancel (escape key) nothing to do
		if [ -z "$chosen_interface" ]; then
			exit 1
		fi
		echo "$chosen_interface" > $FILE
	fi
}

## Display the IP address for the selected interface
monitor_interface() {
	ifnames=$(ip link | awk -F: '$0 !~ "vir|wl|lo|tun|docker|eth|enx|eno|enp"{print $2}')
	if [ -z $ifnames ]; then
		echo '{"text": "No wireguard interface"}'
		exit 1
	fi	
	if [ ! -e "$FILE" ]; then
		echo '{"text": "Select a wireguard interface to monitor", "class": "critical"}'
		exit 1
	fi	

	# Remove trailing whitespace
	ifname=$(cat "$FILE" | sed -e 's/^[ \t]*//')
	if [ -z "$ifname" ]; then
		echo '{"text": "Empty monitoring file", "class": "critical"}'
		exit 1
	else
		# Check if the interface exists
		ip addr show $ifname &> /dev/null
		if [ $? -ne 0 ]; then
			echo '{"text": "'"No $ifname iface found"'", "class": "critical"}'
			exit 1
		fi
	fi
	ip=$(ip addr show $ifname | awk '$1 ~ /^inet$/ {printf "%s\n", $2}' | sed 's/\/.*//'| awk '$1 !~ /127.0.0.1$/ {printf "%s\n", $1}')
	ping_gateway=$(ping -c3 $GATEWAY)
	ping=$(echo $ping_gateway | awk '/transmitted/' | sed -e 's/.*, \(.*\)packet loss.*/\1/' | tr -d '%')
	avg=$(echo $ping_gateway | awk '/rtt/' | sed -e 's/.*mdev = \(.*\)ms/\1/' | awk -F/ '{print $2}')
	# Convert float to int
	ping=${ping%.*}
	avg=${avg%.*}
	if (( $ping == 100 )); then
		# All packets lost
		echo '{"text": "'"$ifname [$ip]"'", "class": "critical"}'
	elif (( $ping > 0 )); then
		# Some packets lost
		echo '{"text": "'"$ifname [$ip] ($avg ms)"'", "class": "warning"}'
	else
		# All packets received
		echo '{"text": "'"$ifname [$ip] ($avg ms)"'", "class": "ok"}'
	fi
}

while getopts "sm" option; do
	case "${option}" in
		s) # Select the interface to monitor
			select_interface
			;;
		m) # Monitor the selected interface
			monitor_interface
			;;
		*) # incorrect option
			echo "Error: Invalid option $option"
			;;
	esac
done

