# Aliae integration: cross-shell aliases from $XDG_CONFIG_HOME/aliae — cached by config hash
if command -v aliae >/dev/null 2>&1; then
  cfg="${XDG_CONFIG_HOME:-$HOME/.config}/aliae/aliae.yaml"
  if [[ -r "$cfg" ]]; then
    local _aliae_cache="${ZSH_CACHE_DIR}/aliae-init.zsh"
    local _aliae_hash_file="${_aliae_cache}.md5"
    local _aliae_hash
    _aliae_hash=$(md5sum < "$cfg")
    _aliae_hash=${_aliae_hash%% *}
    if [[ ! -r "$_aliae_cache" || "$_aliae_hash" != "$(<"$_aliae_hash_file" 2>/dev/null)" ]]; then
      aliae init zsh --config "$cfg" --print > "$_aliae_cache"
      echo "$_aliae_hash" > "$_aliae_hash_file"
    fi
    source "$_aliae_cache"
  fi
fi
