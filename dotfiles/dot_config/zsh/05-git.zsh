# Auto-enable git performance optimizations for large repositories.
# Uses .git/index size as O(1) proxy for file count (~100 bytes/file).
# core.untrackedCache is already set globally in ~/.config/git/config.

typeset -gA _git_fsmonitor_checked  # session cache: abs_git_dir → 1

_git_auto_fsmonitor() {
  local git_dir
  git_dir=$(git rev-parse --git-dir 2>/dev/null) || return

  # Absolute path → stable cache key regardless of cwd or symlinks
  git_dir="${git_dir:A}"

  # Skip repos already processed in this session
  [[ -n "${_git_fsmonitor_checked[$git_dir]}" ]] && return
  _git_fsmonitor_checked[$git_dir]=1

  local index="$git_dir/index"
  [[ -f "$index" ]] || return

  # O(1) size check: 5MB ≈ 50k files (nixpkgs ~5MB, linux ~7MB, typical << 1MB)
  local index_size
  index_size=$(stat -c%s "$index" 2>/dev/null) || return
  (( index_size < 5242880 )) && return  # 5MB threshold

  # Enable fsmonitor only if not already configured locally
  [[ -n "$(git config --local core.fsmonitor 2>/dev/null)" ]] && return

  git config core.fsmonitor true 2>/dev/null || return

  local approx=$(( index_size / 100 ))
  local repo_name
  repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  print -P "%F{yellow}⚡ git fsmonitor%f %F{240}enabled for ${repo_name} (~${approx} files)%f"
}

add-zsh-hook chpwd _git_auto_fsmonitor
_git_auto_fsmonitor  # run for the shell's initial directory
