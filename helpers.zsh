# Dynamic completion helpers, inlined into the generated _claude.
#
# These read the user's own Claude Code state, so they cannot be derived from
# --help. Each returns non-zero when the state it reads is absent, which is
# the normal case on a fresh install, and zsh then falls back to no candidates
# rather than showing an error.

_claude_agents() {
  local -a agents
  local dir file

  for dir in "$PWD/.claude/agents" "$HOME/.claude/agents"; do
    [[ -d $dir ]] || continue
    for file in $dir/*.md(N); do
      agents+=("${file:t:r}")
    done
  done

  (( $#agents )) || return 1
  _describe -t agents 'agent' agents
}

_claude_sessions() {
  # Transcripts are stored per project directory, with the path slugified:
  # every '/' becomes '-', including the leading one.
  local dir="$HOME/.claude/projects/${PWD//\//-}"
  local -a sessions
  local file

  [[ -d $dir ]] || return 1
  # (Nom) sorts newest first, so the session you just left leads the list.
  for file in $dir/*.jsonl(Nom); do
    sessions+=("${file:t:r}")
  done

  (( $#sessions )) || return 1
  _describe -t sessions 'session' sessions
}

_claude_marketplaces() {
  local dir="$HOME/.claude/plugins/marketplaces"
  local -a marketplaces
  local entry

  [[ -d $dir ]] || return 1
  for entry in $dir/*(N/); do
    marketplaces+=("${entry:t}")
  done

  (( $#marketplaces )) || return 1
  _describe -t marketplaces 'marketplace' marketplaces
}

_claude_plugins() {
  local config="$HOME/.claude/plugins/installed_plugins.json"
  local -a plugins

  [[ -r $config ]] || return 1
  (( $+commands[jq] )) || return 1
  plugins=(${(f)"$(jq -r '.plugins? // {} | keys[]' -- $config 2>/dev/null)"})

  (( $#plugins )) || return 1
  _describe -t plugins 'plugin' plugins
}
