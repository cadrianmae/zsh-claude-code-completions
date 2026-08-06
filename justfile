default:
    @just --list

# Regenerate _claude from the installed claude binary
generate claude="claude":
    ./bin/gen-completion --claude {{claude}}

# Syntax-check and functionally test the generated completion
verify:
    ./scripts/verify.sh

# Regenerate, then verify
build: generate verify

# Report whether _claude is behind the installed CLI
staleness:
    #!/usr/bin/env bash
    set -euo pipefail
    have=$(cat claude-version 2>/dev/null || echo none)
    want=$(claude --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if [[ $have == "$want" ]]; then
        echo "[OK] _claude matches claude $want"
    else
        echo "[WARN] _claude built for $have, installed claude is $want"
        echo "       run: just build"
    fi

# Symlink _claude into a directory on $fpath
install dir="$HOME/.zsh/completions":
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "{{dir}}"
    ln -sf "$PWD/_claude" "{{dir}}/_claude"
    echo "linked {{dir}}/_claude"
    echo "ensure this is in \$fpath before compinit, then: rm -f ~/.zcompdump*; exec zsh"

# Show what changed in the CLI surface since the committed _claude
diff-cli:
    ./bin/gen-completion --output - --version-file '' 2>/dev/null | diff -u _claude - || true
