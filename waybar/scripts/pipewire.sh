#!/usr/bin/env bash

theme="selection"
dir="$HOME/.config/rofi/"

rofi_command="rofi -theme $dir/$theme"

jack_process=$(ps aux | grep "[j]ack.sh")

# Execute the jack.sh script to know when the jack is plugged
if [ -z "$jack_process" ]; then
	$HOME/.config/waybar/scripts/jack.sh &
fi

## Get the icons to display in the waybar (icons in waybar correspond to the percentage)
## $1 array with the source informations
## $2 number of different sinks
## $3 percentage to return (icon)
## $4 class (text color)
handle_icons () {
	declare -n source="$1"
	local nb_sinks="$2"
	local sink_built_in="$3"
	class="$4"
	percentage="$5"
	jack_plug=$(cat "$HOME/.config/waybar/scripts/jack_monitoring")
	# If nothing is plugged to the jack, the number of sinks greater than one and the built-in is in use
	# it means that both USB headset and speakers are in use.
	if [ "$jack_plug" == "unplug" ] && [ "$nb_sinks" -gt 1 ] && [ "$sink_built_in" -eq 1 ]; then
		if [ "${source["active"]}" -eq 1 ]; then
			if [ "${source["mute"]}" == "yes" ]; then
				eval $percentage=91
				eval $class="critical"
			else
				eval $percentage=81
				# If the active source is set to built-in it means we use the internal mic so warning
				if [ "${source["built_in"]}" -eq 1 ]; then
					eval $class="warning"
				fi
			fi
		# No active source so just display the headset and speakers icon
		else
			eval $percentage=71
		fi
	# If nothing is plugged to the jack and no built-in is in use it means that only the headset is in use 
	elif [ "$jack_plug" == "unplug" ] && [ "$sink_built_in" -eq 0 ]; then
		if [ "${source["active"]}" -eq 1 ]; then
			if [ "${source["mute"]}" == "yes" ]; then
				eval $percentage=61
				eval $class="critical"
			else
				eval $percentage=51
				# If the active source is set to built-in it means we use the internal mic so warning
				if [ "${source["built_in"]}" -eq 1 ]; then
					eval $class="warning"
				fi
			fi
		# No active source so just display the headset icon
		else
			eval $percentage=41
		fi
	# We consider that a headset with a micro is plugged to the jack. We also suppose that if we use the
	# headset with the jack we don't use an USB headset. It's more logical and otherwise icon handling 
	# is too much complicated
	elif [ "$jack_plug" == "plug" ]; then
		if [ "${source["active"]}" -eq 1 ]; then
			# If the active source is not set to built-in we consider it's an error
			if [ "${source["built_in"]}" -eq 0 ] || [ "${source["mute"]}" == "yes" ]; then
				eval $percentage=61
				eval $class="critical"
			# Here the built-in is in use -> normal case
			else
				eval $percentage=51
				# With the built-in we have two sources : the internal mic and the headset mic
				# Display a warning if it's not the headset mic in use
				if [ ! "${source["active_mic"]}" == "analog-input-headset-mic" ]; then
					eval $class="warning"
				fi
			fi
		# No active source so just display the headset icon
		else
				eval $percentage=41
		fi
	# Here the speakers are in use
	else
		if [ "${source["active"]}" -eq 1 ]; then
			if [ "${source["mute"]}" == "yes" ]; then
				eval $percentage=31
				eval $class="critical"
			else
				eval $percentage=21
			fi
		else
			eval $percentage=11
		fi
	fi
}

## Get all the available sources and fill the array given in the parameter
## $1 the array which will contain the sources index / sources description
get_available_sources_list () {
	declare -n sources_list="$1"
	pactl_list_sources=$(pactl list sources)
	nb_sources=$(echo "$pactl_list_sources" | awk '/Source #/{print $2}' | wc -l)
	for (( x=1; x <= "$((nb_sources))"; x++ )); do
		source_index=$(echo "$pactl_list_sources" | awk '/Source #/{i++} i=='$x'{for (x=1; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/#//g' | awk '{print $2}')
		source_description=$(echo "$pactl_list_sources" | awk '/Description: /{i++} i=='$x'{for (x=2; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/"//g' | sed 's/.$//')
		if [[ ! "$source_description"  =~ "Monitor".* ]]; then
			sources_list[$source_index]="$source_description"
		fi
	done
}

## Get the infos from the running source. We assume that only one source is running
## $1 the array which will contain the running source informations
get_running_source_output_infos () {
	declare -n source_infos="$1"
	source_infos["built_in"]=0
	source_infos["active"]=0
	local pactl_list_source_outputs=$(pactl list source-outputs)
	local pactl_list_sources=$(pactl list sources)
	local nb_source_outputs=$(echo "$pactl_list_source_outputs" | awk '/Source Output/{print $3}' | wc -l)
	# If no source in use there's nothing to do
	if [ "$nb_source_outputs" -ne 0 ]; then
		source_infos["active"]=1
		# Split each list index into an array
		delimiter="State:"
		string=$pactl_list_sources$delimiter
		source_array=()
		while [[ $string ]]; do
			source_array+=( "${string%%"$delimiter"*}" )
			string=${string#*"$delimiter"}
		done
		# For each source when we find the running source, register all needed informations for displaying icons
		for (( x=1; x <= "${#source_array[@]}"; x++ )); do
			source_state=$(echo "${source_array[$x]}" | awk '{print $1; exit}')
			#local source_description=$(echo "$pactl_list_sources" | sed "0,/#$(($source_index))/d" | awk '/Description:/{for (x=2; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/"//g' | sed 's/.$//')
			if [ "$source_state" == "RUNNING" ]; then
				source_infos["description"]=$(echo "${source_array[$x]}" | awk '/Description: /{for (x=2; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/"//g' | sed 's/.$//')
				source_infos["mute"]=$(echo "${source_array[$x]}" | awk '/Mute: /{for (x=2; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/"//g' | sed 's/.$//')
				source_infos["active_mic"]=$(echo "${source_array[$x]}" | awk '/Active Port: /{for (x=3; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/"//g' | sed 's/.$//')
				if [[ "${source_infos["description"]}" =~ "Built-in".* ]]; then
					source_infos["built_in"]=1
				fi
			fi
		done
	fi
}

## Mute/unmute the running source
mute_unmute_source () {
	declare -A running_source
	# Function to get all the running source informations
	get_running_source_output_infos running_source
	local pactl_list_source_outputs=$(pactl list source-outputs)
	local nb_source_outputs=$(echo "$pactl_list_source_outputs" | awk '/Source Output/{print $3}' | wc -l)
	# If no source in use there's nothing to do
	if [ "$nb_source_outputs" -ne 0 ]; then
		# Split each list index into an array
		delimiter="Source Output "
		string=$pactl_list_source_outputs$delimiter
		source_array=()
		while [[ "$string" ]]; do
			str="${string%%"$delimiter"*}"
			source_array+=( "${string%%"$delimiter"*}" )
			string=${string#*"$delimiter"}
		done
		# For each source output toggle mic mute/unmute
		for (( x=1; x <= "${#source_array[@]}"; x++ )); do
			local source_idx=$(echo "${source_array[$x]}" | awk '/Source: /{for (x=2; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/"//g' | sed 's/.$//')
			if [ ! -z "$source_idx" ]; then
				pactl set-source-mute $source_idx toggle
			fi
		done
	fi
}

## Change the micro source for all applications
change_source () {
	local pactl_list_source_outputs=$(pactl list source-outputs)
	local nb_source_outputs=$(echo "$pactl_list_source_outputs" | awk '/Source Output/{print $3}' | wc -l)
	# If no source in use there's nothing to do
	if [ $((nb_source_outputs)) == 0 ]; then
		exit 1
	fi

	jack_plug=$(cat "$HOME/.config/waybar/scripts/jack_monitoring")
	if [ "$jack_plug" == "plug" ]; then
		local pactl_list_sources=$(pactl list sources)
		# Split each list index into an array
		local delimiter="Source:"
		local string=$pactl_list_source_outputs$delimiter
		local source_array=()
		while [[ $string ]]; do
			source_array+=( "${string%%"$delimiter"*}" )
			string=${string#*"$delimiter"}
		done

		# Get the applications list to display in the rofi menu
		# Register the application with its source index
		for (( x=1; x <= "$((nb_source_outputs))"; x++ )); do
			# Get the number after "Source Output#"
			local source_index=$(echo "${source_array[$x]}" | awk '{print $1; exit}' | sed 's/#//g')
			local source_description=$(echo "$pactl_list_sources" | sed "0,/#$(($source_index))/d" | awk '/Description:/{for (x=2; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/"//g' | sed 's/.$//')
			if [[ "$source_description" =~ "Built-in".* ]]; then
				local mics_available=$(echo "$pactl_list_sources" | sed "0,/#$(($source_index))/d" | sed "0,/Ports:/d" | awk '$1 ~ /^analog/{print $1}' | sed 's/.$//') 
				for mic in $mics_available; do
					if [[ "$mic" =~ "headset".* ]]; then
						pactl set-source-port $source_index $mic
					fi
				done
			fi
		done
		exit 1
	fi

	declare -A available_sources_list
	# Function to get all the sources available
	get_available_sources_list available_sources_list
	# If no source or only one there's nothing to do
	if [ "${#available_sources_list[@]}" -lt "2" ]; then
		exit 1
	fi
	
	local count=1
	echo "${#available_sources_list[@]}"
	for index in "${!available_sources_list[@]}"; do
		rofi_sources_list+="${available_sources_list[$index]}"
		# If still have sinks put a new line for the next entry
		if [ $count -ne ${#available_sources_list[@]} ]; then
			rofi_sources_list+="\n"
		fi
		((count++))
	done

	# Display the rofi menu with the available sources
	local chosen_app="$(echo -e "$rofi_sources_list" | $rofi_command -dmenu -p "[Changing audio source] Select the source" -l ${#available_sources_list[@]})"
	# If cancel (escape key) nothing to do
	if [ -z "$chosen_app" ]; then
		exit 1
	fi
	echo "$chosen_app"

	# Get the source number for the chosen application.
	for key in "${!available_sources_list[@]}"; do
		if [ "${available_sources_list[$key]}" == "$chosen_app" ]; then
			new_source_number="$key"
			break
		fi
	done
	echo "$new_source_number"

	# Split each list index into an array
	local delimiter="Source Output"
	local string=$pactl_list_source_outputs$delimiter
	local source_array=()
	while [[ $string ]]; do
		source_array+=( "${string%%"$delimiter"*}" )
		string=${string#*"$delimiter"}
	done

	# Get the applications list to display in the rofi menu
	# Register the application with its source index
	for (( x=1; x <= "$((nb_source_outputs))"; x++ )); do
		# Get the number after "Source Output#"
		local source_index=$(echo "${source_array[$x]}" | awk '{print $1; exit}' | sed 's/#//g')
		pactl move-source-output $source_index $new_source_number
	done
}

## Get all the available sinks and fill the array given in the parameter
## $1 the array which will contain the sink index / sink description
get_available_sinks_list () {
	declare -n sinks_list="$1"
	local pactl_list_sinks=$(pactl list sinks)
	local nb_sinks=$(echo "$pactl_list_sinks" | awk '/Sink #/{print $2}' | wc -l)
	for (( x=1; x <= "$((nb_sinks))"; x++ )); do
		local sink_index=$(echo "$pactl_list_sinks" | awk '/Sink #/{i++} i=='$x'{for (x=1; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/#//g' | awk '{print $2}')
		local sink_description=$(echo "$pactl_list_sinks" | awk '/device.description =/{i++} i=='$x'{for (x=3; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/"//g' | sed 's/.$//')
		sinks_list["$sink_description"]="$sink_index"
	done
}

## Increase/Decrease the volume for the selected sink
## $1 increase or decrease
increase_decrease_volume_sink () {
	local pactl_list_sinks=$(pactl list sinks)
	local pactl_list_sink_inputs=$(pactl list sink-inputs)
	local nb_inputs_sink=$(echo "$pactl_list_sink_inputs" | awk '/Sink Input/{print $3}' | wc -l)
	# If no sink in use there's nothing to do
	if [ $((nb_inputs_sink)) == 0 ]; then
		exit 1
	fi

	# Register the sink description for the current apps with its index
	declare -A sink_index
	for (( x=1; x <= "$((nb_inputs_sink))"; x++ )); do
		local sink=$(echo "$pactl_list_sink_inputs" | awk '/Sink:/{i++} i=='$x'{print $2; exit}')
		local sink_description=$(echo "$pactl_list_sinks" | sed "0,/#$(($sink))/d" | awk '/device.description =/{for (x=3; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/"//g' | sed 's/.$//')
		sink_index[$sink_description]="$sink"
	done

	# Register the current sinks for the rofi menu
	local count=1
	for key in "${!sink_index[@]}"; do
		echo "$key - ${sink_index[$key]}"
		rofi_current_sinks+="$key"
		if [ $count != ${#sink_index[@]} ]; then
			rofi_current_sinks+="\n"
		fi
		((count++))
	done

	# Display the rofi menu with the sinks / If only one sink no need to display the menu selection
	if [ "${#sink_index[@]}" -gt "1" ]; then
		if [ "$1" == "inc" ]; then
			chosen_sink="$(echo -e "$rofi_current_sinks" | $rofi_command -dmenu -p "[Increase volume] Select the sink" -l ${#sink_index[@]})"
		elif [ "$1" == "dec" ]; then
			chosen_sink="$(echo -e "$rofi_current_sinks" | $rofi_command -dmenu -p "[Decrease volume] Select the sink" -l ${#sink_index[@]})"
		fi
		# If cancel (escape key) nothing to do
		if [ -z "$chosen_sink" ]; then
			exit 1
		fi
	fi

	# Register the sink index and the volume for the chosen sink
	for key in "${!sink_index[@]}"; do
		# If only one app save the informations on the first occurence and exit the loop
		if [ ${#sink_index[@]} == 1 ]; then
			index_to_change="${sink_index[$key]}"
			current_volume=$(echo "$pactl_list_sinks" | sed "0,/#$(($index_to_change))/d" | awk '/Volume:/{print $5; exit}' | sed 's/%//g')
			break
		fi
		if [ "$key" == "$chosen_sink" ]; then
			index_to_change="${sink_index[$key]}"
			current_volume=$(echo "$pactl_list_sinks" | sed "0,/#$(($index_to_change))/d" | awk '/Volume:/{print $5; exit}' | sed 's/%//g')
			break
		fi
	done
	echo "$current_volume"
	if [ "$1" == "inc" ]; then
		new_vol_level=$(((current_volume + 10)*65536/100))
	elif [ "$1" == "dec" ]; then
		new_vol_level=$(((current_volume - 10)*65536/100))
	fi
	echo "$index_to_change - $current_volume"
	pactl set-sink-volume "$index_to_change" "$new_vol_level"
}

## Change the audio source for the application selected in the rofi menu
change_sinks () {
	local pactl_list_sink_inputs=$(pactl list sink-inputs)
	local pactl_list_sinks=$(pactl list sinks)
	local nb_inputs_sink=$(echo "$pactl_list_sink_inputs" | awk '/Sink Input/{print $3}' | wc -l)
	# If no application in use there's nothing to do
	if [ $((nb_inputs_sink)) == 0 ]; then
		exit 1
	fi

	declare -A available_sinks_list
	# Function to get all the sinks available
	get_available_sinks_list available_sinks_list
	# If no sink or only one there's nothing to do
	if [ "${#available_sinks_list[@]}" -lt "2" ]; then
		exit 1
	fi

	# Split each list index into an array
	local delimiter="Sink Input"
	local string=$pactl_list_sink_inputs$delimiter
	local sink_array=()
	while [[ $string ]]; do
		sink_array+=( "${string%%"$delimiter"*}" )
		string=${string#*"$delimiter"}
	done

	declare -A app_array
	declare -A app_description
	declare -A rofi_index
	# Get the applications list to display in the rofi menu
	# Register the application with its sink index / In case we have several same apps just append
	# the sink index to create a list
	for (( x=1; x <= "$((nb_inputs_sink))"; x++ )); do
		# Get the number after "Sink Input#"
		local sink_index=$(echo "${sink_array[$x]}" | awk '{print $1; exit}' | sed 's/#//g')
		local application=$(echo "${sink_array[$x]}" | awk '/application.name =/{for (x=3; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/"//g' | sed 's/.$//')
		local sink_number=$(echo "${sink_array[$x]}" | awk '/Sink:/{print $2; exit}')
		local sink_description=$(echo "$pactl_list_sinks" | sed "0,/#$(($sink_number))/d" | awk '/device.description/{for (x=3; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/"//g' | sed 's/.$//')
		app_description["$application"]+="$sink_description "
		echo "$application - $sink_description"
		app_array["$application"]+="$sink_index "
	done

	# Create the rofi menu for the running applications
	local count=1
	for app in "${!app_array[@]}"; do
		# If there is only one app set it to the chose one
		if [ ${#app_array[@]} -eq 1 ]; then
			chosen_app="$app"
			break
		fi
		rofi_selection+="$app"
		# If still have an application put a new line for the next entry
		if [ $count != ${#app_array[@]} ]; then
			rofi_selection+="\n"
		fi
	done

	# Create the rofi menu for the available sinks
	local count=1
	for sink in "${!available_sinks_list[@]}"; do
		rofi_sinks_list+="$sink"
		rofi_index[$sink]=$count
		# If still have sinks put a new line for the next entry
		if [ $count != ${#available_sinks_list[@]} ]; then
			rofi_sinks_list+="\n"
		fi
		((count++))
	done

	# Display the rofi menu with the applications / If only one app no need to display the menu selection
	if [ "${#app_array[@]}" -gt 1 ]; then
		chosen_app="$(echo -e "$rofi_selection" | $rofi_command -dmenu -p "[Changing audio sink] Select the application" -l ${#app_array[@]})"
		# If cancel (escape key) nothing to do
		if [ -z "$chosen_app" ]; then
			exit 1
		fi
	fi
	
	# Set the current sink index to display in the rofi menu
	local tmp=app_description["$application"]
	local current_sink=rofi_index["$tmp"];

	# Display the rofi menu with all the sinks available
	local chosen_sink="$(echo -e "$rofi_sinks_list" | $rofi_command -dmenu -p "[Changing audio sink] Select the sink for $chosen_app" -l ${#available_sinks_list[@]} -a $current_sink )"
	# If cancel (escape key) nothing to do
	if [ -z "$chosen_sink" ]; then
		exit 1
	fi
	for sink_index in ${app_array[$chosen_app]}; do
		pactl move-sink-input $sink_index ${available_sinks_list[$chosen_sink]}
	done
}

## Display the applications with their sink and volume in waybar
## Ex : Firefox - Built-in Audio Analog Stereo [71%] | Plex Media Player - Razer USB Sound Card Analog Stereo [86%]
## If the apps have the same sink :
## Plex Media Player/Firefox - Built-in Audio Analog Stereo [71%]
display_sinks () {
	# Set the apps volume to 100% so only the hardware volume to control
	pactl list sink-inputs | awk '/Sink Input/{print $3}' | sed 's/#//g' | while read line; do
		pactl set-sink-input-volume $line 100%
	done
	local pactl_list_sinks=$(pactl list sinks)
	local pactl_list_sink_inputs=$(pactl list sink-inputs)
	local nb_inputs_sink=$(echo "$pactl_list_sink_inputs" | awk '/Sink Input/{print $3}' | wc -l)

	if [[ "$nb_inputs_sink" -eq 0 ]] || [ -z "$nb_inputs_sink" ]; then
		echo '{"text": "No input(s) sink available", "percentage": 0}'
		exit 1
	fi

	# Split each list index into an array
	local delimiter="Sink Input"
	local string=$pactl_list_sink_inputs$delimiter
	local sink_array=()
	local sink_built_in=0
	while [[ $string ]]; do
		sink_array+=( "${string%%"$delimiter"*}" )
		string=${string#*"$delimiter"}
	done
		
	declare -A sink_vol_app
	declare -A app_and_sink_array
	declare -A number_of_app

	# For each input sink get the application name, the device used and the volume associated
	for (( x=1; x <= "$((nb_inputs_sink))"; x++ )); do
		local sink=$(echo "${sink_array[$x]}" | awk '/Sink: /{print $2; exit}')
		local application=$(echo "${sink_array[$x]}" | awk '/application.name =/{for (x=3; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/"//g' | sed 's/.$//')
		local sink_description=$(echo "$pactl_list_sinks" | sed "0,/#$(($sink))/d" | awk '/device.description =/{for (x=3; x<=NF; x++) printf("%s ",$x); exit}' | sed 's/"//g' | sed 's/.$//')
		volume=$(echo "$pactl_list_sinks" | sed "0,/#$(($sink))/d" | awk '/Volume:/{print $5; exit}' | sed 's/"//g')
		# Register how many times we reach an application for its dedicated sink
		(( app_and_sink_array[$sink_description [$volume],$application]++ ))
		# Special treatment later if the sink is Built-in Audio
		if [ "$sink_description" == "Built-in Audio" ]; then
			sink_built_in=1
		fi
		# End of the for loop
		if [ "$x" -eq "$nb_inputs_sink" ]; then
			for app_and_sink in "${!app_and_sink_array[@]}"; do
				# Split the app and the sink and set how many apps have the sink
				sink=$(echo "$app_and_sink" | cut -d "," -f 1)
				app=$(echo "$app_and_sink" | cut -d "," -f 2)
				(( number_of_app[$sink]++ ))
			done
				
			declare -A nb_app
			for app_and_sink in "${!app_and_sink_array[@]}"; do
				sink=$(echo "$app_and_sink" | cut -d "," -f 1)
				app=$(echo "$app_and_sink" | cut -d "," -f 2)
				# If the app is only running once just add the app name
				if [ "${app_and_sink_array[$sink,$app]}" -eq 1 ]; then
					sink_vol_app[$sink]+="$app"
				else
					# If the app is running more than once (eg multiple firefox tabs with audio)
					# add the app name and the number of times it is executed
					sink_vol_app[$sink]+="$app(${app_and_sink_array[$sink,$app]})"
				fi
				(( nb_app[$sink]++ ))
				# If we have several apps within the same sink add a / separator
				if [ ${nb_app[$sink]} != "${number_of_app[$sink]}" ]; then
					sink_vol_app[$sink]+="/"
				fi
			done
		fi
	done

	count=1
	# Format the output : '-' between the app(s) and the sink and a '|' between the app(s) from different sinks
	for key in "${!sink_vol_app[@]}"; do
		output+="${sink_vol_app[$key]} - $key"
		if [ $count != ${#sink_vol_app[@]} ]; then
			output+=" | "
		fi
		((count++))
	done

	declare -A running_source
	# Function to get all the running source informations
	get_running_source_output_infos running_source

	handle_icons running_source ${#sink_vol_app[@]} $sink_built_in class percentage

	if [ ! -z "$class" ]; then
		echo '{"text": "'"$output"'", "class": "'"$class"'", "percentage": '$percentage'}'
	else
		echo '{"text": "'"$output"'", "percentage": '$percentage'}'
	fi
}

while getopts "qwerty" option; do
	case "${option}" in
		q) # display the sink informations in waybar
			display_sinks
			;;
		w) # change the sink for the specified application
			change_sinks
			;;
		e) # Increase the volume for the specified sink
			increase_decrease_volume_sink inc
			;;
		r) # Decrease the volume for the specified sink
			increase_decrease_volume_sink dec
			;;
		t) # Change the source for all applications
			change_source
			;;
		y) # Mute/unmute the running source
			mute_unmute_source
			;;
		*) # incorrect option
            echo "Error: Invalid option $option"
            ;;
    esac
done
