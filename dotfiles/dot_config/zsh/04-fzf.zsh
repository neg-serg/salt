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

# Make sure completion infra exists before fzf completion
autoload -Uz compinit
(( ${+_comps} )) || compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"

# Load (zsh will prefer compiled .zwc if present)
source "${_fzf_cache_dir}/key-bindings.zsh" 2>/dev/null
source "${_fzf_cache_dir}/completion.zsh"   2>/dev/null
bindkey "^I" fzf-on-tab
