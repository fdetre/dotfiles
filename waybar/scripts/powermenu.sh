#!/usr/bin/env bash

theme="powermenu"
dir="$HOME/.config/rofi/"

rofi_command="rofi -theme $dir/$theme"

# Options
shutdown="⏻"
reboot=""
lock=""
suspend="⏾"
logout=""

# Confirmation
confirm_exit() {
	rofi -dmenu\
		-i\
		-no-fixed-num-lines\
		-p "Are You Sure? [y/n] "\
		-theme $dir/confirm.rasi
}

# Variable passed to rofi
options="$shutdown\n$reboot\n$lock\n$suspend\n$logout"

chosen="$(echo -e "$options" | $rofi_command -p "" -dmenu -selected-row 0)"
case $chosen in
	$shutdown)
		ans=$(confirm_exit &)
		if [ "$ans" == "y" ]; then
			echo "unplug" > $HOME/.config/waybar/scripts/jack_monitoring
			systemctl poweroff
		else
			exit 0
		fi
		;;
	$reboot)
		ans=$(confirm_exit &)
		if [ "$ans" == "y" ]; then
			echo "unplug" > $HOME/.config/waybar/scripts/jack_monitoring
			systemctl reboot
		else
			exit 0
		fi
		;;
	$lock)
		swaylock -t -i $HOME/.config/wallpapers/star_wars.png
		;;
	$suspend)
		ans=$(confirm_exit &)
		if [ "$ans" == "y" ]; then
			systemctl suspend
		else
			exit 0
		fi
		;;
	$logout)
		ans=$(confirm_exit &)
		if [ "$ans" == "y" ]; then
			swaymsg exit
		else
			exit 0
		fi
		;;
esac
