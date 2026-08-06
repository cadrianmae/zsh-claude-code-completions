#!/bin/sh
# Install zsh-claude-code-completions.
#
# POSIX sh on purpose: this may run under sh, dash, or bash long before the
# zsh it is installing for gets a say.
#
# The script clones the repository rather than downloading a loose _claude,
# so that updating is `git pull`, the checkout can be inspected afterwards,
# and `just build` can regenerate against your own CLI version.
#
# It does not edit your shell configuration unless you pass --modify-rc. The
# default is to print the two lines you need and let you place them.
#
#   curl -fsSL https://raw.githubusercontent.com/cadrianmae/zsh-claude-code-completions/main/install.sh | sh
#
# If you are reading this because you are about to pipe it into a shell:
# don't take my word for it, read the rest of the file first. It is short.

set -eu

REPO_URL="${REPO_URL:-https://github.com/cadrianmae/zsh-claude-code-completions}"
# Pinned by default. The scheduled workflow commits to main automatically, so
# tracking main means running whatever the bot last produced. A tag is a
# human-published point. Override with --ref main if that is what you want.
REF="${REF:-v1}"

dir=""
modify_rc=0
dry_run=0
uninstall=0

info()  { printf '[INFO] %s\n' "$*"; }
ok()    { printf '[OK]   %s\n' "$*"; }
warn()  { printf '[WARN] %s\n' "$*" >&2; }
fatal() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

run() {
    if [ "$dry_run" -eq 1 ]; then
        printf '[DRY]  %s\n' "$*"
    else
        "$@"
    fi
}

usage() {
    cat <<'EOF'
Usage: install.sh [options]

  --dir PATH      Install to PATH instead of the auto-detected location
  --ref REF       Git ref to check out (default: v1; use "main" to track HEAD)
  --modify-rc     Append the fpath lines to ~/.zshrc (default: print them)
  --uninstall     Remove a previous installation
  --dry-run       Print what would happen, change nothing
  -h, --help      This message

Environment: REPO_URL, REF
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dir)        dir="${2:?--dir needs a path}"; shift 2 ;;
        --ref)        REF="${2:?--ref needs a ref}"; shift 2 ;;
        --modify-rc)  modify_rc=1; shift ;;
        --uninstall)  uninstall=1; shift ;;
        --dry-run)    dry_run=1; shift ;;
        -h|--help)    usage; exit 0 ;;
        *)            fatal "unknown option: $1 (try --help)" ;;
    esac
done

# -- preflight -------------------------------------------------------------

command -v git >/dev/null 2>&1 || fatal "git is required"
command -v zsh >/dev/null 2>&1 || warn "zsh not found on PATH; installing anyway"

# -- where does this go ----------------------------------------------------

# oh-my-zsh puts every enabled plugin's directory on fpath before running
# compinit, so installing there needs no fpath edit at all -- just a name in
# plugins=(). That is the least invasive outcome, so prefer it when present.
omz_dir="${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins"
plugin_name="zsh-claude-code-completions"

if [ -n "$dir" ]; then
    target="$dir"
    style="manual"
elif [ -d "$omz_dir" ]; then
    target="$omz_dir/$plugin_name"
    style="oh-my-zsh"
else
    target="${XDG_DATA_HOME:-$HOME/.local/share}/$plugin_name"
    style="manual"
fi

# -- uninstall -------------------------------------------------------------

if [ "$uninstall" -eq 1 ]; then
    if [ -d "$target" ]; then
        run rm -rf "$target"
        ok "removed $target"
    else
        info "nothing installed at $target"
    fi
    [ -L "$HOME/.zsh/completions/_claude" ] && run rm -f "$HOME/.zsh/completions/_claude"
    info "any lines you added to ~/.zshrc were left alone; remove them by hand"
    exit 0
fi

# -- fetch -----------------------------------------------------------------

if [ -d "$target/.git" ]; then
    info "updating existing checkout at $target"
    run git -C "$target" fetch --quiet --tags origin
    # Discard local changes to generated files rather than failing on a
    # conflict; anything the user cares about should live in a fork.
    run git -C "$target" checkout --quiet --force "$REF" 2>/dev/null \
        || run git -C "$target" checkout --quiet --force "origin/$REF"
    run git -C "$target" reset --quiet --hard "@{upstream}" 2>/dev/null || true
else
    info "cloning $REPO_URL ($REF) into $target"
    run mkdir -p "$(dirname "$target")"
    if ! run git clone --quiet --depth 1 --branch "$REF" "$REPO_URL" "$target" 2>/dev/null; then
        # --branch fails on a bare commit sha, and the default ref may not
        # exist yet on a young repository.
        run git clone --quiet "$REPO_URL" "$target"
        run git -C "$target" checkout --quiet "$REF"
    fi
fi

if [ "$dry_run" -eq 1 ]; then
    info "dry run: nothing was installed (target would be $target)"
else
    [ -f "$target/_claude" ] || fatal "no _claude in $target; the checkout looks wrong"
    ok "installed to $target"
fi

# -- wire it up ------------------------------------------------------------

if [ "$style" = "oh-my-zsh" ]; then
    cat <<EOF

Add it to your plugin list in ~/.zshrc:

    plugins=(... $plugin_name)

Then: exec zsh
EOF
else
    rc_lines="fpath=($target \$fpath)
autoload -Uz compinit && compinit"

    if [ "$modify_rc" -eq 1 ]; then
        if grep -qF "$target" "$HOME/.zshrc" 2>/dev/null; then
            # shellcheck disable=SC2088  # display text, not a path to expand
            info "~/.zshrc already references $target; leaving it alone"
        else
            run cp "$HOME/.zshrc" "$HOME/.zshrc.bak-claude-completions" 2>/dev/null || true
            if [ "$dry_run" -eq 1 ]; then
                printf '[DRY]  append fpath lines to ~/.zshrc\n'
            else
                # shellcheck disable=SC2016  # $fpath must land in .zshrc literally
                printf '\n# zsh-claude-code-completions\nfpath=(%s $fpath)\n' "$target" >> "$HOME/.zshrc"
            fi
            ok "appended to ~/.zshrc (backup: ~/.zshrc.bak-claude-completions)"
            warn "the fpath line must run BEFORE compinit; if your framework"
            warn "calls compinit for you, move the line above that call"
        fi
    else
        cat <<EOF

Add to ~/.zshrc, before compinit runs:

    $rc_lines

Then: exec zsh
EOF
    fi
fi

cat <<'EOF'

If tab does nothing afterwards, the completion cache is stale:

    rm -f ~/.zcompdump*; exec zsh
EOF
