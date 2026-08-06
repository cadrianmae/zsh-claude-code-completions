# Plugin entry point for oh-my-zsh, zinit, antidote, and friends.
#
# oh-my-zsh already prepends a plugin's directory to $fpath before running
# compinit, so sourcing this file is usually unnecessary. Other managers vary,
# and adding a directory to fpath twice is harmless, so we do it anyway.

0=${(%):-%N}
fpath=(${0:A:h} $fpath)

# When the manager loads plugins after compinit has already run, _claude would
# never be picked up. Bind it explicitly in that case.
if (( $+functions[compdef] )) && [[ -z ${_comps[claude]:-} ]]; then
  autoload -Uz _claude 2>/dev/null && compdef _claude claude
fi
