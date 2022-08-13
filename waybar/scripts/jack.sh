#!/usr/bin/env bash

acpi_listen | while IFS= read -r line;
do
	if [ "$line" = "jack/headphone HEADPHONE plug" ]
	then
		echo "plug" > $HOME/.config/waybar/scripts/jack_monitoring
	elif [ "$line" = "jack/headphone HEADPHONE unplug" ]
	then
		echo "unplug" > $HOME/.config/waybar/scripts/jack_monitoring
	fi
done
