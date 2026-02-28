local THEME_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/f-sy-h/current_theme.zsh"
local INI_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/f-sy-h/neg.ini"
typeset -gA FAST_HIGHLIGHT_STYLES
local FAST_THEME_NAME="neg"

# Skip regeneration if theme file is newer than INI source
if [[ -f "$THEME_FILE" && "$THEME_FILE" -nt "$INI_FILE" ]]; then
    source "$THEME_FILE"
    return 0 2>/dev/null || exit 0
fi

[[ -r "$INI_FILE" ]] || return 0

# Parse INI and build styles in memory
local -A ext_styles
local section="" line key value rest bg_color new_value
local -a parts

while IFS= read -r line; do
    line="${line%%\;*}"
    line="${line%%\#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ '^\[(.*)\]$' ]]; then
        section="${match[1]}"
    elif [[ "$section" == "file-extensions" && "$line" =~ '^([a-zA-Z0-9_+-]+)[[:space:]]*=[[:space:]]*(.*)$' ]]; then
        key="${match[1]}"
        value="${match[2]}"
        value="${value//\"/}"

        if [[ "$value" == bg:* ]]; then
            rest=${value#bg:}
            parts=(${(s:,:)rest})
            bg_color=${parts[1]}
            shift parts
            new_value="bg=$bg_color"
            if [[ -n "$parts[1]" && "$parts[1]" =~ '^[0-9]+$' ]]; then
                new_value+=",fg=$parts[1]"
                shift parts
            fi
            [[ ${#parts} -gt 0 ]] && new_value+=",${(j:,:)parts}"
            value=$new_value
        else
            value="fg=$value"
        fi

        ext_styles[$key]="$value"
    fi
done < "$INI_FILE"

# Set styles in memory and write theme file in a single pass
mkdir -p "${THEME_FILE:h}"
{
    for ext style in "${(@kv)ext_styles}"; do
        [[ -n $ext && -n $style ]] || continue
        FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}file-extensions-${ext}]="$style"
        print -r -- ": \${FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}file-extensions-${ext}]:=$style}"
    done
} > "$THEME_FILE"
