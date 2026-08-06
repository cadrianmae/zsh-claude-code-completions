#!/usr/bin/env bash
# Create the minimum Claude Code state the dynamic-helper checks need.
#
# On a CI runner ~/.claude is empty, so those checks skip -- and skipping is
# exactly wrong here. They exist to catch a helper being shadowed by a
# generated completer, a fault that produces a file which parses cleanly and
# only misbehaves when tab is pressed. Seeding turns them back into real
# assertions.
#
# Safe to run repeatedly. Refuses to touch a directory that already holds
# real state, so it cannot clobber a developer's own agents or transcripts.

set -euo pipefail

agents_dir="$HOME/.claude/agents"
projects_dir="$HOME/.claude/projects/${HOME//\//-}"

if compgen -G "$agents_dir/*.md" >/dev/null 2>&1; then
    echo "[INFO] $agents_dir already populated; leaving it alone"
else
    mkdir -p "$agents_dir"
    cat > "$agents_dir/ci-probe.md" <<'EOF'
---
name: ci-probe
description: Placeholder agent so completion checks have something to offer.
---
EOF
    echo "[OK] seeded $agents_dir/ci-probe.md"
fi

if compgen -G "$projects_dir/*.jsonl" >/dev/null 2>&1; then
    echo "[INFO] $projects_dir already populated; leaving it alone"
else
    mkdir -p "$projects_dir"
    # The name is what gets completed, so it must look like a session id.
    : > "$projects_dir/00000000-0000-4000-8000-000000000000.jsonl"
    echo "[OK] seeded a placeholder transcript in $projects_dir"
fi
