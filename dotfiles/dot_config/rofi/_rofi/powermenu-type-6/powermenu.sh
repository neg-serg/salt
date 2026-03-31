#!/usr/bin/env zsh

## Author : Aditya Shakya (adi1090x)
## Github : @adi1090x
#
## Rofi   : Power Menu
#
## Available Styles
#
## style-1   style-2   style-3   style-4   style-5

# Current Theme — accepts theme dir name as $1
theme_dir="${1:-powermenu-type-6}"
dir="$HOME/.config/rofi/_rofi/$theme_dir"
theme='style-1'

# CMDs
uptime="${$(uptime -p)#up }"
host=$(hostname)

# Build mesg and mainbox style based on theme
if [[ "$theme_dir" == "type-5" ]]; then
  local _ll; last $USER | read -r _ll
  local -a _lf=(${=_ll}); lastlogin="${_lf[5]} ${_lf[6]} ${_lf[7]}"
  mesg=" Last Login: $lastlogin |  Uptime: $uptime"
  mainbox_style='mainbox {children: [ "message", "listview" ];}'
else
  mesg=" Uptime: $uptime"
  mainbox_style='mainbox {orientation: vertical; children: [ "message", "listview" ];}'
fi

# Options
hibernate=''
shutdown=''
reboot=''
lock=''
suspend=''
logout=''
yes=''
no=''

# Rofi CMD
rofi_cmd() {
  rofi -dmenu \
    -p " $USER@$host" \
    -mesg "$mesg" \
    -theme ${dir}/${theme}.rasi
}

# Confirmation CMD
confirm_cmd() {
  rofi -theme-str 'window {location: center; anchor: center; fullscreen: false; width: 350px;}' \
    -theme-str "$mainbox_style" \
    -theme-str 'listview {columns: 2; lines: 1;}' \
    -theme-str 'element-text {horizontal-align: 0.5;}' \
    -theme-str 'textbox {horizontal-align: 0.5;}' \
    -dmenu \
    -p 'Confirmation' \
    -mesg 'Are you Sure?' \
    -theme ${dir}/${theme}.rasi
}

# Ask for confirmation
confirm_exit() {
  echo -e "$yes\n$no" | confirm_cmd
}

# Pass variables to rofi dmenu
run_rofi() {
  echo -e "$lock\n$suspend\n$logout\n$hibernate\n$reboot\n$shutdown" | rofi_cmd
}

# Execute Command
run_cmd() {
  selected="$(confirm_exit)"
  if [[ "$selected" == "$yes" ]]; then
    if [[ $1 == '--shutdown' ]]; then
      systemctl poweroff
    elif [[ $1 == '--reboot' ]]; then
      systemctl reboot
    elif [[ $1 == '--hibernate' ]]; then
      systemctl hibernate
    elif [[ $1 == '--suspend' ]]; then
      mpc -q pause
      amixer set Master mute
      systemctl suspend
    elif [[ $1 == '--logout' ]]; then
      hyprctl dispatch exit
    fi
  else
    exit 0
  fi
}

# Actions
chosen="$(run_rofi)"
case ${chosen} in
  "$shutdown")
    run_cmd --shutdown
    ;;
  "$reboot")
    run_cmd --reboot
    ;;
  "$hibernate")
    run_cmd --hibernate
    ;;
  "$lock")
    hyprlock
    ;;
  "$suspend")
    run_cmd --suspend
    ;;
  "$logout")
    run_cmd --logout
    ;;
esac
