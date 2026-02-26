# FZF widget options (interactive-only, moved from .zshenv)
export FZF_CTRL_R_OPTS="--sort --exact --border=sharp --margin=0 --padding=0 --no-scrollbar --footer='[Enter] Paste  [Ctrl-y] Yank  [?] Preview' --preview 'echo {}' --preview-window down:5:hidden,wrap --bind '?:toggle-preview'"
export FZF_CTRL_T_OPTS="--border=sharp --margin=0 --padding=0 --no-scrollbar --preview 'if [ -d \"{}\" ]; then (eza --tree --icons=auto -L 2 --color=always \"{}\" 2>/dev/null || tree -C -L 2 \"{}\" 2>/dev/null); else (bat --style=plain --color=always --line-range :200 \"{}\" 2>/dev/null || highlight -O ansi -l \"{}\" 2>/dev/null || head -200 \"{}\" 2>/dev/null || file -b \"{}\" 2>/dev/null); fi' --preview-window=right,60%,border-left,wrap"

# Resolve fzf dir (prefer fzf-share)
local _fzf_base
if (( ${+commands[fzf-share]} )); then
  _fzf_base="$(fzf-share 2>/dev/null)"
elif [[ -d /usr/share/fzf ]]; then
  _fzf_base=/usr/share/fzf
else
  return 0
fi

local _fzf_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/fzf"
[[ -d "$_fzf_cache_dir" ]] || mkdir -p -- "$_fzf_cache_dir"

# Sync files if missing/empty or older than source
# Completion is often /usr/share/zsh/site-functions/_fzf
for f in key-bindings.zsh completion.zsh; do
  local src=""
  local search_paths=()
  if [[ "$f" == "completion.zsh" ]]; then
    search_paths=(
      "$_fzf_base/shell"
      "$_fzf_base"
      "/usr/share/zsh/site-functions"
    )
  else
    search_paths=(
      "$_fzf_base/shell"
      "$_fzf_base"
    )
  fi

  for loc in "${search_paths[@]}"; do
    local target="$loc/$f"
    [[ "$f" == "completion.zsh" && ! -r "$target" ]] && target="$loc/_fzf"
    
    if [[ -r "$target" ]]; then
      src="$target"
      break
    fi
  done

  [[ -n "$src" ]] || continue
  local dst="${_fzf_cache_dir}/${f}"
  [[ -s "$dst" && ! "$src" -nt "$dst" ]] || cp -f -- "$src" "$dst"
done

# Load fzf scripts (no compinit needed at source time)
source "${_fzf_cache_dir}/key-bindings.zsh" 2>/dev/null
source "${_fzf_cache_dir}/completion.zsh"   2>/dev/null

# Lazy compinit: defer initialization until first Tab press (fish-style trick)
# This avoids ~15-20ms compinit cost when shell is used for a quick command without Tab
_fzf_tab_lazy_init() {
  _zpcompinit_custom
  bindkey '^I' fzf-on-tab
  zle fzf-on-tab
}
zle -N _fzf_tab_lazy_init
bindkey '^I' _fzf_tab_lazy_init
