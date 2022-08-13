#!/usr/bin/env bash

theme="selection"
dir="$HOME/.config/rofi/"

rofi_command="rofi -theme $dir/$theme"

FILE="$HOME/.config/waybar/scripts/eth_monitoring"
## Select the interface to monitor
select_interface() {
	ifnames=$(ip link | awk -F: '$2 ~ /eno|enp|enx|eth/{print $2}')
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
		chosen_interface="$(echo -e "$ifnames" | $rofi_command -dmenu -p "[Network] Select the interface to monitor" -l $count -a $current_selected_interface )"
		# If cancel (escape key) nothing to do
		if [ -z "$chosen_interface" ]; then
			exit 1
		fi
		echo "$chosen_interface" > $FILE
	fi
}

## Display the IP address for the selected interface
monitor_interface() {
	ifnames=$(ip link | awk -F: '$2 ~ /eno|enp|enx|eth/{print $2}')
	if [ -z "$ifnames" ]; then
		echo '{"text": "No eth interface", "percentage": 0}'
		exit 1
	fi	
	if [ ! -e "$FILE" ]; then
		echo '{"text": "Select an eth interface to monitor", "class": "critical", "percentage": 0}'
		exit 1
	fi
	# Remove trailing whitespace
	ifname=$(cat "$FILE" | sed -e 's/^[ \t]*//')
	ip addr show $ifname &> /dev/null
	if [ $? -ne 0 ]; then
		echo '{"text": "'"No $ifname iface found"'", "class": "critical", "percentage": 0}'
		exit 1
	fi

	link=$(cat /sys/class/net/"$ifname"/carrier)
	if (( $link == 0 )); then
		echo '{"text": "cable unplugged", "class": "warning", "percentage": 40}'
		exit 1
	else
		eth_ip=$(ip addr show $ifname | awk '$1 ~ /^inet$/ {printf "%s\n", $2}' | sed 's/\/.*//'| awk '$1 !~ /127.0.0.1$/ {printf "%s\n", $1}')
		if [ -z $eth_ip ]; then
			echo '{"text": "No IP", "class": "critical", "percentage": 80}'
			exit 1
		fi
	fi

	ping_cmd=$(ping -I $ifname -c3 8.8.8.8 2> /dev/null)
	if [ $? -ne 0 ]; then
		echo '{"text": "'"$eth_ip [ping error]"'", "class": "warning", "percentage": 80}'
		exit 1
	fi
	ping=$(echo "$ping_cmd" | awk '/transmitted/' | sed -e 's/.*, \(.*\)packet loss.*/\1/' | tr -d '%')
	# Convert float to int
	ping=${ping%.*}
	if (( $ping == 100 )); then
		# All packets lost
		echo '{"text": "'"$eth_ip"'", "class": "critical", "percentage": 80}'
	elif (( $ping > 0 )); then
		# Some packets lost
		echo '{"text": "'"$eth_ip"'", "class": "warning", "percentage": 80}'
	else
		# All packets received
		echo '{"text": "'"$eth_ip"'", "percentage": 80}'
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
