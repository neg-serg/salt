# Aliae integration: cross-shell aliases from $XDG_CONFIG_HOME/aliae
if command -v aliae >/dev/null 2>&1; then
  cfg="${XDG_CONFIG_HOME:-$HOME/.config}/aliae/aliae.yaml"
  # Print init script and eval so aliases override earlier definitions
  if [[ -r "$cfg" ]]; then
    eval "$(aliae init zsh --config "$cfg" --print)"
  fi
fi
