---
name: wexac-dotfiles
description: |
  Cluster shell toolkit for LSF/HPC users. Provides tmux session management
  with automatic logging (tns/tni/tlog/tas/tks), LSF job monitoring and queue
  intelligence (bjm/bqinfo/bsubjup), port inspection (myports/mykill),
  parquet-tools shortcuts, user info, and everyday productivity functions.
  Use when the user is on a cluster (LSF/slurm), asks about tmux logging,
  wants to submit jobs, inspect ports, or needs help with shell productivity.
  Voice triggers: "cluster tools", "tmux toolkit", "LSF helpers", "dotfiles".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# wexac-dotfiles Skill

## Identity

You are a **cluster shell toolkit expert**. You know every function in the
wexac-dotfiles `bash_functions.sh` inside out. Your job is to help users:
1. Install the toolkit on their cluster account
2. Understand and use any function
3. Debug tmux/LSF/port issues
4. Customize or extend the toolkit for their needs

## Repo structure

```
wexac-dotfiles/
├── bash_functions.sh     # main file — source this in .bashrc
├── bin/
│   └── tns-clean         # strips ANSI codes from tmux pipe-pane output
├── lsf/
│   └── bsubct.sh         # VS Code tunnel via dropbear on LSF (separate)
├── install.sh            # one-command installer
├── .agents/
│   ├── AGENTS.md         # agent instructions
│   └── skills/
│       └── wexac-dotfiles/
│           ├── SKILL.md           # this file
│           ├── agents/openai.yaml  # agent interface config
│           └── references/
│               └── FUNCTIONS.md    # detailed function reference
```

## Quick install (for a colleague)

```bash
# From the repo directory — copies bash_functions.sh + tns-clean
./install.sh

# Or manually:
cp bash_functions.sh ~/.bash_functions.sh
mkdir -p ~/.local/bin && cp bin/tns-clean ~/.local/bin/
echo 'export TMUX_LOG_DIR="$HOME/tmux-logs"' >> ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo '[ -f ~/.bash_functions.sh ] && . ~/.bash_functions.sh' >> ~/.bashrc
source ~/.bashrc
```

## Available functions — quick reference

### Tmux session management (auto-logged)

| Function | Usage | Description |
|---|---|---|
| `tls` | `tls` | List tmux sessions |
| `tas` | `tas <session>` | Attach (or switch if inside tmux) |
| `taf` | `taf` | Attach to first/only session |
| `tks` | `tks <session>` | Kill a session |
| `tkas` | `tkas` | Kill ALL sessions |
| `tnd` | `tnd [name] [cmd]` | Send keys to session (create if missing) |
| `tns` | `tns CMD ...` | **Batch**: run command in detached tmux, logs, auto-kills on finish |
| `tni` | `tni [name]` | **Interactive**: attach to logged session, stays alive |
| `tlog` | `tlog [all\|status\|pane]` | Log/report panes |

### LSF cluster helpers

| Function | Usage | Description |
|---|---|---|
| `bp` | `bp [job]` | bpeek shortcut |
| `bjmem` | `bjmem` | Memory summaries |
| `bjm` | `bjm` | Rich job monitor |
| `bqinfo` | `bqinfo [queue]` | Queue intelligence + top users |
| `bsubjup` | `bsubjup [-m MEM] [-t TIME] [-q QUEUE]` | Submit Jupyter Lab |
| `bsubistun` | `bsubistun` | Interactive shell on compute node |
| `bkill_non_is` | `bkill_non_is` | Kill non-interactive jobs |

### Port inspector

| Function | Usage | Description |
|---|---|---|
| `myports` | `myports` | List all listening ports with process info |
| `mykill` | `mykill <port>` | Kill process on a port |

### File/inspection helpers

| Function | Usage | Description |
|---|---|---|
| `xa` | `xa CMD -- args` | xargs wrapper preserving aliases/functions |
| `pt*` | `ptc file.parquet` | parquet-tools shortcuts |
| `bcftools_view` | `bcftools_view file.vcf.gz` | bcftools + less |
| `rsyncwdel` | `rsyncwdel src dest` | rsync + delete origin on success |
| `userinfo` | `userinfo <name\|uid>` | User details + groups + activity |
| `hist_search` | `hist_search <pattern>` | Grep history |
| `osl` | `osl [N]` | List N latest opencode sessions |
| `ocs` | `ocs [id\|num]` | Resume opencode session |
| `osc` | `osc [id]` | Opencode session shortcut |

### Shell enhancements

| Function | Description |
|---|---|
| `cd` (override) | Auto-activates `.venv` on cd, deactivates on leaving |
| `set_prompt` | Colorful PS1 with git branch, venv, exit status |

## Common tasks

### "I want to run a long job and not lose the output"

```bash
tns python train.py --epochs 100
# or with a name:
tns my-training -- python train.py --epochs 100
# logs go to ~/tmux-logs/my-training/0.0.log
# session auto-kills when done
```

### "I want an interactive session that stays alive"

```bash
tni my-work
# run stuff, Ctrl+B d to detach
# come back later:
tas my-work
```

### "What's running on all my open ports?"

```bash
myports
# PORT   PID      PROCESS    TYPE        SINCE        STATUS   DETAILS
# 8080   12345    python3    Streamlit   Jul 24      ACTIVE   app.py
# 3000   67890    node       Unknown     Jul 23      ACTIVE   server.js
```

### "Who's hogging the queue?"

```bash
bqinfo          # overview
bqinfo gsla-cpu # per-queue breakdown with CPU efficiency
```

### "I need to send someone the tmux functions"

```bash
# Tell them to run:
git clone <repo> ~/.wexac-dotfiles
cd ~/.wexac-dotfiles && ./install.sh && source ~/.bashrc
# Then show them: tns, tni, tls, tas, tlog
```

## Troubleshooting

### tmux says "no server running"
Run `tns echo test` to start one. All functions auto-create sessions.

### tns-clean not found
Add `~/.local/bin` to PATH, or run `cp bin/tns-clean ~/.local/bin/`.

### bsub commands not found
You're not on an LSF cluster. Those functions will error gracefully with
"command not found" checks.

### Logs are empty
Check `TMUX_LOG_DIR` (defaults to `~/tmux-logs/`). Use `tlog status` to see
current logging state. Make sure `tns-clean` is in PATH.

## Function details

For complete details on every function, read [references/FUNCTIONS.md](references/FUNCTIONS.md).
