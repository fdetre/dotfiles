#!/usr/bin/env bash
for partition in "$@"; do
    infos=$(df -h $partition --output=size,used,pcent | awk 'NR==2{printf "%s/%s (%s)\n", $2,$1,$3 }')
    hdd_percent=$(echo "$infos" | awk '{print $2}' | tr -d '(%)')
	if (( $hdd_percent >= 70 && $hdd_percent < 90 )); then
		class="warning"
	elif (( $hdd_percent >= 90 )); then
		class="critical"
    fi
    output="$output [$partition] $infos"
done
if [ -z $class ]; then
    echo '{"text": "'"$output"'"}'
else
    echo '{"text": "'"$output"'", "class": '"$class"'}'
fi
