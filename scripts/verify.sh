#!/usr/bin/env zsh
# Verify the generated _claude: syntax, loadability, and real completions.
#
# The last of those needs an interactive zsh, because completion widgets only
# exist inside one. We drive a throwaway shell over a zpty, type a prefix,
# press tab, and read back what it offered.

emulate -L zsh
setopt err_return no_unset pipefail

script=${1:-_claude}
repo=${0:a:h:h}
cd -- $repo

typeset -i failures=0

# Note the pre-increment: `(( failures++ ))` evaluates to the old value, so
# the first failure would return non-zero and trip err_return.
pass() { print -r -- "[OK]   $1" }
fail() { print -r -- "[FAIL] $1"; (( ++failures )) }

# -- 1. syntax -------------------------------------------------------------

if zsh -n $script; then
  pass "parses as zsh"
else
  fail "syntax error"
  exit 1
fi

# -- 2. header -------------------------------------------------------------

if [[ $(head -1 $script) == '#compdef claude' ]]; then
  pass "declares #compdef claude"
else
  fail "missing '#compdef claude' on line 1"
fi

# -- 3. completions --------------------------------------------------------

zmodload zsh/zpty

# A zpty is 80x24 by default, so a long match list would stop at a pager
# prompt. Blanking list-prompt and raising LINES keeps everything on screen
# in one shot. menu/select are off so matches print as a plain list.
setup="
  fpath=($repo \$fpath)
  autoload -Uz compinit && compinit -u -d /tmp/.zcompdump-verify-\$\$
  zstyle ':completion:*' menu no
  zstyle ':completion:*' list-prompt ''
  zstyle ':completion:*' select-prompt ''
  LISTMAX=9999 LINES=1000 COLUMNS=200
  unsetopt always_to_end auto_menu
  setopt no_beep
  PROMPT='' RPROMPT=''
"

# Type $1, press tab, and echo back whatever zsh drew on the pty.
complete_for() {
  local input=$1 out='' line
  zpty -d claude_verify 2>/dev/null || true
  zpty claude_verify "zsh -f -i" || return 1
  zpty -w claude_verify $setup
  # Let compinit finish before the tab lands, or the widget is not yet bound.
  sleep 1
  while zpty -r -t claude_verify line 0.2 2>/dev/null; do :; done  # drain setup echo
  zpty -w -n claude_verify "$input"$'\t'
  sleep 1
  while zpty -r -t claude_verify line 0.5 2>/dev/null; do
    out+=$line
  done
  zpty -d claude_verify 2>/dev/null || true
  # Strip CSI sequences (including bracketed-paste) so greps see plain words.
  print -r -- ${out//$'\e'\[[0-9;?]#[a-zA-Z]/}
}

check() {
  local desc=$1 input=$2 expect=$3 got
  got=$(complete_for $input) || { fail "$desc (zpty failed)"; return }
  if [[ $got == *$expect* ]]; then
    pass "$desc -> offers '$expect'"
  else
    fail "$desc -> '$expect' not offered"
    print -r -- "       got: ${got:0:300}"
  fi
}

check "subcommands"      'claude '                  'mcp'
check "long flags"       'claude --perm'            '--permission-mode'
check "flag values"      'claude --permission-mode ' 'bypassPermissions'
check "model aliases"    'claude --model '          'sonnet'
check "effort levels"    'claude --effort '         'xhigh'
check "nested commands"  'claude mcp '              'add-json'
check "deep nesting"     'claude plugin marketplace ' 'add'

# --------------------------------------------------------------------------

print
if (( failures )); then
  print -r -- "$failures check(s) failed"
  exit 1
fi
print -r -- "all checks passed"
