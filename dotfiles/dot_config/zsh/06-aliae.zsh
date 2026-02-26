# Aliae integration: cross-shell aliases from $XDG_CONFIG_HOME/aliae — cached by config mtime
if (( $+commands[aliae] )); then
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/aliae/aliae.yaml"
  if [[ -r "$cfg" ]]; then
    local _aliae_cache="${ZSH_CACHE_DIR}/aliae-init.zsh"
    if [[ ! -r "$_aliae_cache" || "$cfg" -nt "$_aliae_cache" ]]; then
      aliae init zsh --config "$cfg" --print > "$_aliae_cache"
    fi
    source "$_aliae_cache"
  fi
fi
