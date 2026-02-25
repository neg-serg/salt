#!/usr/bin/env zsh
set -euo pipefail
rofi_bin="rofi"
jq_bin="jq"
hyprctl_bin="${ROFI_WRAPPER_HYPRCTL:-hyprctl}"
xdg_data="${XDG_DATA_HOME:-$HOME/.local/share}"
xdg_conf="${XDG_CONFIG_HOME:-$HOME/.config}"
themes_dir="$xdg_data/rofi/themes"
# Default to config dir to make @import in config.rasi resolve relative files
cd_dir="$xdg_conf/rofi"
prev_is_theme=0
theme_name=""
have_cfg=0
have_kb_cancel=0
have_kb_secondary_copy=0
have_auto_select=0
have_no_auto_select=0
want_offsets=1
have_xoff=0
have_yoff=0
have_loc=0
for arg in "$@"; do
  if [ "$prev_is_theme" -eq 1 ]; then
    val="$arg"
    prev_is_theme=0
    case "$val" in
      /* | */*) : ;; # absolute or contains path component -> leave as-is
      *)
        case "$val" in *.rasi | *.rasi:*) cd_dir="$themes_dir" ;; esac
        ;;
    esac
    # remember base theme name for per-theme placement tweaks
    base=${val:t}; base=${base%.rasi*}
    [ -n "$base" ] && theme_name="$base"
  fi
  case "$arg" in
    -theme) prev_is_theme=1 ;;
    -theme=*)
      val=${arg#-theme=}
      case "$val" in
        /* | */*) : ;;
        *) case "$val" in *.rasi | *.rasi:*) cd_dir="$themes_dir" ;; esac ;;
      esac
      base=${val:t}; base=${base%.rasi*}
      [ -n "$base" ] && theme_name="$base"
      ;;
    -no-config | -config | -config=*) have_cfg=1 ;;
    -xoffset | -xoffset=*) have_xoff=1 ;;
    -yoffset | -yoffset=*) have_yoff=1 ;;
    -location | -location=*) have_loc=1 ;;
    -kb-cancel | -kb-cancel=*) have_kb_cancel=1 ;;
    -kb-secondary-copy | -kb-secondary-copy=*) have_kb_secondary_copy=1 ;;
    -auto-select) have_auto_select=1 ;;
    -no-auto-select) have_no_auto_select=1 ;;
  esac
done
[ -d "$cd_dir" ] && cd "$cd_dir"

# If the caller explicitly picked the pass or askpass theme, let the theme position it
# (pass uses a top-anchored window, askpass uses south); skip wrapper offsets in that case.
if [[ "$theme_name" == "pass" || "$theme_name" == askpass* ]]; then
  want_offsets=0
fi

# Compute offsets from Quickshell Theme + Hyprland scale to align with panel
# Only when caller did not specify offsets explicitly
if [ "$want_offsets" -eq 1 ] && [ "$have_xoff" -eq 0 ] && [ "$have_yoff" -eq 0 ]; then
  theme_json="$xdg_conf/quickshell/Theme/.theme.json"
  # Defaults if quickshell or jq/hyprctl unavailable
  sm=18
  ay=4
  scale=1
  extra=""
  if [ -f "$theme_json" ]; then
    local jq_out
    jq_out=$("$jq_bin" -r '"\(try .panel.sideMargin // 18)\t\(try .panel.menuYOffset // 8)\t\(try .panel.menuYOffsetAdjust // "")"' "$theme_json" 2>/dev/null) || jq_out=$'18\t8\t'
    IFS=$'\t' read -r sm ay extra <<< "$jq_out"
    : ${sm:=18} ${ay:=8}
  fi
  if ! [[ "$extra" =~ '^[0-9]+(\.[0-9]+)?$' ]]; then
    # Default: subtract full menuYOffset so the menu sits flush to panel
    extra=$ay
  fi
  # Monitor scale: try Hyprland first, fall back to wlr-randr
  scale=$("$hyprctl_bin" -j monitors 2> /dev/null | "$jq_bin" -r 'try (.[] | select(.focused==true) | .scale) // 1' 2> /dev/null || \
         wlr-randr --json 2> /dev/null | "$jq_bin" -r 'try ([.[] | select(.enabled) | .scale] | first) // 1' 2> /dev/null || \
         echo 1)
  # reduce y-offset by adjustment (clamp >=0)
  (( ay = ay - extra ))
  (( ay < 0 )) && ay=0
  # Round offsets to ints
  local _tmp
  (( _tmp = sm * scale )); xoff=${_tmp%.*}
  (( _tmp = -(ay * scale) )); yoff=${_tmp%.*}
  set -- "$@" -xoffset "$xoff" -yoffset "$yoff"
  # Ensure bottom-left if not specified
  if [ "$have_loc" -eq 0 ]; then
    set -- "$@" -location 7
  fi
fi

# Avoid parsing user/system config if not explicitly requested (rofi 2.0 parser is strict)
if [ "$have_cfg" -eq 0 ]; then
  set -- -no-config "$@"
fi

# Enable auto-accept by default (can be disabled with -no-auto-select)
if [ "$have_auto_select" -eq 0 ] && [ "$have_no_auto_select" -eq 0 ]; then
  set -- -auto-select "$@"
fi

# Only inject keybindings when not loading a config (avoid duplicate "already bound")
if [ "$have_cfg" -eq 0 ]; then
  # Free Control+c from default secondary-copy mapping, unless caller sets it
  if [ "$have_kb_secondary_copy" -eq 0 ]; then
    set -- -kb-secondary-copy "" "$@"
  fi
  # Ensure Ctrl+C always cancels, unless caller specified their own mapping
  if [ "$have_kb_cancel" -eq 0 ]; then
    set -- -kb-cancel "Control+c,Escape" "$@"
  fi
fi
exec "$rofi_bin" "$@"
