# wexac-dotfiles

**Cluster shell toolkit** — tmux logging, LSF helpers, port inspector, and everyday bash functions for HPC users.

Originally extracted from a WEXAC user's `~/.bash_functions.sh` and sanitized for sharing. Works on any Linux system with LSF, but especially tuned for WEXAC/Weizmann cluster workflows.

## Quick install

```bash
git clone <repo-url> ~/.wexac-dotfiles
cd ~/.wexac-dotfiles
./install.sh
source ~/.bashrc
```

Or just copy the bits you want:

```bash
cp bash_functions.sh ~/.bash_functions.sh
mkdir -p ~/.local/bin && cp bin/tns-clean ~/.local/bin/
# Then add to ~/.bashrc:
echo '[ -f ~/.bash_functions.sh ] && . ~/.bash_functions.sh' >> ~/.bashrc
```

## What's in it

### 📦 Tmux toolkit (`tns`, `tni`, `tlog`, `tas`, `tks`, `tkas`, `taf`)

| Command | What it does |
|---|---|
| `tls` | List all tmux sessions |
| `tas <session>` | Attach (or switch if inside tmux) |
| `taf` | Attach to first/only session |
| `tns CMD ...` | Run a command in a detached tmux session with **full logging** + auto-kill on finish |
| `tns NAME -- CMD ...` | Same with a custom session name |
| `tni [NAME]` | Interactive tmux session with logging (stays alive after exit) |
| `tlog [all\|status\|pane]` | Log/report on all tmux panes |
| `tks <session>` | Kill a session |
| `tkas` | Kill **all** sessions |
| `tnd [name] [cmd]` | Send keys to a session (create if missing) |

**Key feature:** All session output is automatically logged to `$TMUX_LOG_DIR/<session>/` (default: `~/tmux-logs/`). ANSI escape codes are stripped via `tns-clean`. Session events (pane died, session closed) are also recorded.

### 📊 LSF helpers (`bp`, `bjmem`, `bjm`, `bqinfo`, `bsubjup`, `bsubistun`, `bkill_non_is`)

| Command | What it does |
|---|---|
| `bp [job]` | `bpeek` shortcut |
| `bjmem` | Memory summaries for jobs |
| `bjm` | Rich job monitor |
| `bqinfo` | Queue intelligence — active queues + top users |
| `bqinfo <queue>` | Per-queue user breakdown + CPU efficiency |
| `bsubjup [-m MEM] [-t TIME] [-q QUEUE]` | Submit Jupyter Lab via LSF |
| `bsubistun` | Interactive shell on compute node |
| `bkill_non_is` | Kill non-interactive jobs (skips interactive ones) |

### 🔍 Port inspector (`myports`, `mykill`)

| Command | What it does |
|---|---|
| `myports` | List all listening ports with process name, type, PID, and details |
| `mykill <port>` | Kill the process on a port |

Detects VS Code, Streamlit, and other common services automatically.

### 👤 User info (`userinfo`)

```bash
userinfo <username|uid>
```

Shows UID, groups, member counts, running processes, login status.

### 📂 File & code helpers

| Command | What it does |
|---|---|
| `xa CMD` | `xargs` wrapper that preserves aliases and functions |
| `hist_search <pattern>` | Grep command history |
| `rsyncwdel <src> <dest>` | rsync + delete origin on success |

### 🔧 Prompt & venv

- **Smart `cd`** — auto-activates `.venv` when you enter a directory, deactivates when you leave
- **`set_prompt`** — colorful PS1 with git branch, venv name, exit status, timestamp

### 🚇 VS Code Tunnel (separate, LSF-specific)

See `lsf/bsubct.sh` — sets up a dropbear SSH tunnel on a compute node so VS Code Remote-SSH can connect through LSF.

```bash
source ~/.wexac-dotfiles/lsf/bsubct.sh
bsubct --init       # one-time host key
bsubct              # submit or check status
bsubct --stop       # kill tunnel
```

## File structure

```
wexac-dotfiles/
├── README.md
├── install.sh          # one-command installer
├── bash_functions.sh   # main file — source this
├── bin/
│   └── tns-clean       # ANSI-stripping helper for tmux logs
└── lsf/
    └── bsubct.sh       # VS Code tunnel (WEXAC-specific)
```

## Install for a colleague

Your colleague can do:

```bash
cp /home/your-user/wexac-dotfiles/bash_functions.sh ~/
mkdir -p ~/.local/bin
cp /home/your-user/wexac-dotfiles/bin/tns-clean ~/.local/bin/
echo 'export TMUX_LOG_DIR="$HOME/tmux-logs"' >> ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo '[ -f ~/.bash_functions.sh ] && . ~/.bash_functions.sh' >> ~/.bashrc
source ~/.bashrc
```

Or just point them to the git repo.

The LSF functions assume `bpeek`, `bjobs`, `bqueues`, `bsub`, etc. are in PATH.
