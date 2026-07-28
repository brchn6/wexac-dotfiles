# wexac-dotfiles — Agent instructions

This repo is a cluster shell toolkit for HPC/LSF users, originally from WEXAC.
It provides bash functions for tmux session management with logging, LSF job
monitoring, port inspection, and everyday productivity.

## Working on this repo

- `bash_functions.sh` is the main file. Keep it POSIX-ish (bash, but avoid
  bashisms that break under `set -euo pipefail`).
- Functions are organized by section with clear headers. Add new functions in
  the appropriate section.
- Export (via `export -f`) any function that might be passed to `xargs` or
  `bash -c`.
- The `install.sh` script copies files to `~/.bash_functions.sh` and
  `~/.local/bin/tns-clean`. Update it if you add new files.
- Keep the repo **free of personal info, secrets, and institution-internal
  paths**. Everything should work on any LSF cluster, not just WEXAC.

## Sanitization rules

- No hardcoded `/home/labs/...` or `/users/...` paths
- No hardcoded tool versions (`/usr/share/lsf/10.1/...`)
- No credentials, tokens, API keys, or auth headers
- No personal usernames or email addresses
- No internal cluster hostnames (login nodes are fine as examples)
- When in doubt, use `$PATH` lookup or make paths configurable via env vars

## Skill

This repo includes a pi skill at `.agents/skills/wexac-dotfiles/`. It teaches
the agent how to install, use, and explain every function in the toolkit.
When a user asks about tmux, LSF, or cluster workflows, the agent should
load and follow the skill.
