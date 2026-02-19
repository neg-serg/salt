# Spaceship prompt configuration — ported from neg.omp.json
# Must be sourced BEFORE loading Spaceship (vars use ${VAR=default} — only set if unset).
# vim: ft=zsh

# ── Prompt order ───────────────────────────────────────────────────────────────
# Left prompt: path → git → root indicator → prompt char
# Right prompt mirrors OMP rprompt segments (note: 'golang' not 'go'; package ≈ npm)
SPACESHIP_PROMPT_ORDER=(dir neggit root char)
SPACESHIP_RPROMPT_ORDER=(exec_time node package python golang ruby java docker terraform exit_code)

# ── Global ─────────────────────────────────────────────────────────────────────
# Async disabled: Spaceship's zsh-async forks a worker on every precmd and
# registers zle -F fd handlers. This conflicts with F-Sy-H widget wrapping
# and breaks ctrl-l + causes a broken first shell. Sync mode is equivalent
# to OMP without streaming (~5ms small repos, ~94ms linux kernel warm).
SPACESHIP_PROMPT_ASYNC=false
SPACESHIP_PROMPT_ADD_NEWLINE=false
SPACESHIP_PROMPT_DEFAULT_PREFIX=' '
SPACESHIP_PROMPT_DEFAULT_SUFFIX=''

# ── Dir (path) ─────────────────────────────────────────────────────────────────
# OMP template: <#005faf></> /home/neg/.../path with colored '/' separators.
# Spaceship doesn't support per-character coloring; we approximate with a
# prefix glyph and use the full path without truncation.
SPACESHIP_DIR_COLOR='#95a7bc'
SPACESHIP_DIR_PREFIX='%F{#005faf}%f '   # leading  glyph in blue (NF \ue285)
SPACESHIP_DIR_SUFFIX=''
SPACESHIP_DIR_TRUNC=0                   # full path, no truncation
SPACESHIP_DIR_TRUNC_REPO=false
SPACESHIP_DIR_LOCK_SYMBOL=''

# ── Git ────────────────────────────────────────────────────────────────────────
# OMP: ' ⟮<bold branch><#367CB0>←N →N</> ●WN ●SN⟯'
# Spaceship: single status color (can't split working vs staging color)
#
# IMPORTANT: spaceship_git() in git.zsh hardcodes --color 'white' and has no
# SPACESHIP_GIT_COLOR variable. We override with a custom section 'neggit'
# that replicates git.zsh behavior but with correct #005faf bracket color.
# SPACESHIP_PROMPT_ORDER must use 'neggit' not 'git'.

SPACESHIP_GIT_BRANCH_PREFIX=''
SPACESHIP_GIT_BRANCH_SUFFIX=''
SPACESHIP_GIT_BRANCH_COLOR='#6C7E96'

SPACESHIP_GIT_STATUS_PREFIX=' '
SPACESHIP_GIT_STATUS_SUFFIX=''
SPACESHIP_GIT_STATUS_COLOR='#367CB0'
SPACESHIP_GIT_STATUS_AHEAD='←'
SPACESHIP_GIT_STATUS_BEHIND='→'
SPACESHIP_GIT_STATUS_MODIFIED='●'
SPACESHIP_GIT_STATUS_ADDED='+'
SPACESHIP_GIT_STATUS_DELETED='✘'
SPACESHIP_GIT_STATUS_UNTRACKED='?'
SPACESHIP_GIT_STATUS_STASHED='$'
SPACESHIP_GIT_STATUS_UNMERGED='='
SPACESHIP_GIT_STATUS_DIVERGED='⇕'
SPACESHIP_GIT_STATUS_SHOW=true

# Custom git section wrapper — identical to spaceship_git() but with colored brackets.
# Both ⟮ and ⟯ use #005faf; ⟯ is in GIT_SUFFIX so it always renders (clean or dirty).
spaceship_neggit() {
  [[ $SPACESHIP_GIT_SHOW == false ]] && return

  # git_branch and git_status are loaded transitively via sections/git.zsh.
  # Since 'git' is not in SPACESHIP_PROMPT_ORDER, load their parent on first use.
  if ! spaceship::defined "spaceship_git_branch"; then
    builtin source "$SPACESHIP_ROOT/sections/git.zsh" 2>/dev/null || return
  fi

  # Force sync refresh of sub-sections (same as spaceship_git does internally)
  for _ss in git_branch git_status; do
    spaceship::core::refresh_section --sync "$_ss"
  done
  unset _ss

  local git_branch
  git_branch="$(spaceship::cache::get git_branch)"
  [[ -z $git_branch ]] && return

  local git_data
  git_data="$(spaceship::core::compose_order git_branch git_status)"

  spaceship::section \
    --color '#005faf' \
    --prefix ' ⟮' \
    --suffix '⟯' \
    "$git_data"
}

# ── Root indicator ─────────────────────────────────────────────────────────────
# OMP: shows ⚡ (\uf0e7) in #ce162b when EUID=0. Custom Spaceship section below.
spaceship_root() {
  [[ $EUID -eq 0 ]] || return
  spaceship::section --color '#ce162b' $'\uf0e7 '
}

# ── Prompt char ────────────────────────────────────────────────────────────────
SPACESHIP_CHAR_SYMBOL='❯'
SPACESHIP_CHAR_SYMBOL_ROOT='❯'
SPACESHIP_CHAR_SYMBOL_SUCCESS='❯'
SPACESHIP_CHAR_SYMBOL_FAILURE='❯'
SPACESHIP_CHAR_COLOR_SUCCESS='#005faf'
SPACESHIP_CHAR_COLOR_FAILURE='#ce162b'
SPACESHIP_CHAR_PREFIX=' '
SPACESHIP_CHAR_SUFFIX=' '

# ── Execution time ─────────────────────────────────────────────────────────────
SPACESHIP_EXEC_TIME_SHOW=true
SPACESHIP_EXEC_TIME_COLOR='#45bf17'
SPACESHIP_EXEC_TIME_ELAPSED=0.05       # 50ms threshold (OMP: threshold: 50ms)
SPACESHIP_EXEC_TIME_PRECISION=1
SPACESHIP_EXEC_TIME_PREFIX=''
SPACESHIP_EXEC_TIME_SUFFIX=' '

# ── Exit code ──────────────────────────────────────────────────────────────────
# OMP: shows ×N only on error. Spaceship default is off — we enable it.
SPACESHIP_EXIT_CODE_SHOW=true
SPACESHIP_EXIT_CODE_COLOR='#ce162b'
SPACESHIP_EXIT_CODE_SYMBOL='×'
SPACESHIP_EXIT_CODE_PREFIX=' '
SPACESHIP_EXIT_CODE_SUFFIX=''

# ── Node.js ────────────────────────────────────────────────────────────────────
SPACESHIP_NODE_COLOR='#42E66C'
SPACESHIP_NODE_SYMBOL=$'\ue718 '       # OMP uses \ue718 (node icon)
SPACESHIP_NODE_PREFIX=''
SPACESHIP_NODE_SUFFIX=' '

# ── Package (≈ OMP npm segment) ────────────────────────────────────────────────
# Note: OMP 'npm' shows npm binary version; Spaceship 'package' shows package.json
# project version. Different data, closest available analog.
SPACESHIP_PACKAGE_COLOR='#ce162b'
SPACESHIP_PACKAGE_SYMBOL=$'\ue71e '    # OMP uses \ue71e (npm icon)
SPACESHIP_PACKAGE_PREFIX=''
SPACESHIP_PACKAGE_SUFFIX=' '
SPACESHIP_PACKAGE_SHOW_PRIVATE=true

# ── Python ─────────────────────────────────────────────────────────────────────
SPACESHIP_PYTHON_COLOR='#E4F34A'
SPACESHIP_PYTHON_SYMBOL=$'\ue235 '     # python icon
SPACESHIP_PYTHON_PREFIX=''
SPACESHIP_PYTHON_SUFFIX=' '

# ── Go ─────────────────────────────────────────────────────────────────────────
# Section name in Spaceship is 'golang', not 'go'
SPACESHIP_GOLANG_COLOR='#7FD5EA'
SPACESHIP_GOLANG_SYMBOL=$'\ue626 '     # go icon
SPACESHIP_GOLANG_PREFIX=''
SPACESHIP_GOLANG_SUFFIX=' '

# ── Ruby ───────────────────────────────────────────────────────────────────────
SPACESHIP_RUBY_COLOR='#CC342D'
SPACESHIP_RUBY_SYMBOL=$'\ue791 '       # ruby gem icon
SPACESHIP_RUBY_PREFIX=''
SPACESHIP_RUBY_SUFFIX=' '

# ── Java ───────────────────────────────────────────────────────────────────────
SPACESHIP_JAVA_COLOR='#b07219'
SPACESHIP_JAVA_SYMBOL=$'\ue738 '       # java icon
SPACESHIP_JAVA_PREFIX=''
SPACESHIP_JAVA_SUFFIX=' '

# ── Docker ─────────────────────────────────────────────────────────────────────
SPACESHIP_DOCKER_COLOR='#0db7ed'
SPACESHIP_DOCKER_SYMBOL=$'\uf308 '     # docker whale icon
SPACESHIP_DOCKER_PREFIX=''
SPACESHIP_DOCKER_SUFFIX=' '

# ── Terraform ──────────────────────────────────────────────────────────────────
SPACESHIP_TERRAFORM_COLOR='#5f43e9'
SPACESHIP_TERRAFORM_SYMBOL='TF '
SPACESHIP_TERRAFORM_PREFIX=''
SPACESHIP_TERRAFORM_SUFFIX=' '
