# wexac-dotfiles — Function Reference

Detailed documentation for every function in `bash_functions.sh`.

---

## Tmux Toolkit

### `tls` — List tmux sessions

```
tls
```

Thin wrapper around `tmux list-sessions`. Shows session name, window count,
and attached status.

---

### `tas <session>` — Attach to session

```
tas my-session
```

Smart attach:
- If already **inside** tmux: does `tmux switch-client -t <session>` (switches
  the current client to the target session without detaching)
- If **outside** tmux with a terminal: does `tmux attach-session -t <session>`
- If **non-interactive** (piped, xargs): prints error — must be run directly

---

### `taf` — Attach to first session

```
taf
```

Gets the first session name from `tmux list-sessions -F '#S'` and calls `tas`
on it. Useful when you have only one session and don't want to type the name.

---

### `tks <session>` — Kill session

```
tks my-session
```

Thin wrapper around `tmux kill-session -t`.

---

### `tkas` — Kill all sessions

```
tkas
```

Lists all sessions with `tmux list-sessions`, extracts names via `awk -F:`,
and kills each one. **Use with caution** — no confirmation prompt.

---

### `tnd [name] [cmd...]` — Tmux send keys

```
tnd                    # Start a new tmux session
tnd mysession          # Create/ensure session exists
tnd mysession ls -la   # Send 'ls -la' to mysession
```

If the session doesn't exist, creates it detached. Then sends the command
as keys to the session's first pane.

---

### `tns` — Batch tmux session (logged, auto-kill)

```
tns python train.py
tns my-experiment -- python train.py --epochs 100
tns -- python train.py
```

**The flagship function.** Creates a detached tmux session, runs the command
with full output logging, and auto-kills when done.

**Auto-naming logic:**
1. If `--` is present: everything after is the command. Name is the argument
   before `--`, or auto-generated if missing.
2. If the first argument is a valid command/executable: auto-generates a name
   like `tmux-20250101-120000-123456789`.
3. Otherwise: first argument is the session name, rest is the command.

**Logging:**
- All output is piped through `tns-clean` (strips ANSI codes) to
  `$TMUX_LOG_DIR/<session-name>/<window>.<pane>.log`
- Events (pane died, session closed) logged to
  `$TMUX_LOG_DIR/<session-name>.events.log`
- Log directory created automatically

**Auto-kill:** When all panes have died (command finished), waits 1 second
then kills the session. This prevents zombie sessions.

**Remain-on-exit:** Set to `off` — panes close immediately when the command
finishes, triggering the auto-kill hook.

---

### `tni [name]` — Interactive tmux session (logged)

```
tni                    # Auto-named interactive session
tni my-work            # Named interactive session
```

Same as `tns` but:
- Attaches you to the session immediately
- `remain-on-exit` is `on` — panes stay after the shell exits
- Session does NOT auto-kill — persists until you `tks` it or close tmux

Great for long-running interactive work where you want:
- Automatic logging of everything you type
- Ability to detach/re-attach (`Ctrl+B d`, then `tas my-work`)

---

### `tlog [mode]` — Tmux logger/reporter

```
tlog                  # Enable logging on all panes + print status report
tlog status           # Print status report only (no logging changes)
tlog pane             # Log only the current pane
```

**Status report** is a TSV table written to `$TMUX_LOG_DIR/tlog_report_<timestamp>.tsv`:

```
session   window.pane   state    command    log_path                         attach
my-work   0.0           running  python3    ~/tmux-logs/my-work/0.0.log     tas my-work
my-work   0.1           waiting  bash       ~/tmux-logs/my-work/0.1.log     tas my-work
```

- **state:** `running` (active command), `waiting` (shell prompt), `dead` (exited)
- **attach:** copy-paste command to attach to that session

---

## LSF Helpers

### `bp [job]` — bpeek shortcut

```
bp               # peek at most recent job
bp 123456        # peek at job 123456
```

Calls `bpeek`. Requires LSF.

---

### `bjmem` — Memory summaries

```
bjmem
```

Calls `bj -l` and filters for `Job <...>` and `MAX MEM` lines. Shows job ID
and peak memory usage.

---

### `bjm` — Rich job monitor

```
bjm
```

Calls `bj -l` and parses job ID, name, MEMLIMIT, and MEMORY USAGE into a
readable block per job.

---

### `bqinfo [queue]` — Queue intelligence

```
bqinfo              # Overview: all active queues + top 3 users per queue
bqinfo gsla-cpu     # Per-queue breakdown: user priority, CPU efficiency, flags
```

**Overview mode** shows:
- Queue name, priority, pending/running counts
- Top 3 users (by total jobs) per queue

**Per-queue mode** (`bqinfo <queue>`) shows:
- Each user: started jobs, priority, CPU time, run time, CPU efficiency ratio
- Flags: `over` (over limit), `low-cpu` (running >10min with <0.1 CPU)

---

### `bsubjup` — Submit Jupyter Lab

```
bsubjup                     # 42GB, no time limit, gsla-cpu
bsubjup -m 100GB            # 100GB
bsubjup -m 64GB -t 02:00    # 64GB, 2-hour wall time
bsubjup -q interactive       # Custom queue
```

Submits a Jupyter Lab job to LSF and waits for the URL. Automatically picks
a random port between 20000-65000.

---

### `bsubistun` — Interactive compute node shell

```
bsubistun
```

Requests an interactive LSF job (77GB, 1 core, `interactive` queue) and drops
you into a bash shell on a compute node.

---

### `bkill_non_is` — Kill non-interactive jobs

```
bkill_non_is
```

Iterates all your LSF jobs. Skips interactive shell jobs (detected by
"Interactive pseudo-terminal shell mode" in `bjobs -l`), kills everything
else. Safe guard against accidentally killing your interactive sessions.

---

## Port Inspector

### `myports` — List listening ports

```
myports
```

Uses `ss -tlnp` to find all TCP listening ports and enriches each with:
- **PORT**: the port number
- **PID**: process ID
- **PROCESS**: process name (from `ps`)
- **TYPE**: categorized as VS Code (agent host, terminal, server, extension),
  Streamlit, or Unknown
- **SINCE**: when the process started
- **STATUS**: ACTIVE
- **DETAILS**: command line / app name

Also checks for configured-but-stopped apps in known config locations.

---

### `mykill <port>` — Kill process on port

```
mykill 8080
```

Finds the PID listening on `<port>` via `ss`, shows what it's killing, and
sends SIGTERM.

---

## File & Inspection Helpers

### `xa CMD -- args` — xargs wrapper

```
find . -name '*.py' | xa python3
find . -name '*.txt' | xa myfunction --
```

Unlike plain `xargs`, `xa`:
1. Resolves aliases to their expanded form
2. If the command is a bash function, exports it and runs via `bash -c`
   (so the function is available in the subprocess)

---

### `rsyncwdel <src> <dest>` — rsync + delete

```
rsyncwdel /path/to/data/ server:/backup/data/
```

Runs `rsync -avz --no-g --info=progress2 --progress`. If successful, deletes
the source files with `rm -rf`. If rsync fails, source is preserved.

---

### `userinfo <name|uid>` — User details

```
userinfo jdoe
userinfo 12345
```

Shows:
- UID, GID, home directory, shell
- Group membership with member counts (lists names if ≤20 members)
- Activity: running process count, logged-in status (from `w`)

---

### `hist_search <pattern>` — History search

```
hist_search train_model
```

Greps `history` output for matching commands with color highlighting.

---

### `osl [N]` — List opencode sessions

```
osl          # Last 100 sessions
osl 5        # Last 5 sessions
```

Queries the opencode SQLite database and prints a table:
`ID  SLUG  TITLE  DIRECTORY  UPDATED`

### `ocs <id|num>` — Resume opencode session

```
ocs             # Continue most recent session
ocs ses_abc123  # Resume by session ID
ocs 3           # Resume 3rd session from osl output
```

### `osc <id>` — Opencode session shortcut

```
osc             # List sessions
osc ses_abc123  # Resume session
```

---

## Shell Enhancements

### `cd` (override)

```
cd project/
```

Smart directory change:
- If `.venv/bin/activate` exists in the target directory, activates it
  (if not already active)
- If leaving a directory with `VIRTUAL_ENV` set, deactivates

### `set_prompt`

Colorful PS1:
```
[Magenta] (venv) [Green] main [White] 14:30:00 ✓ [Blue] user@host:[Yellow]/path > [White]
```
- Green: virtualenv/conda name (if active)
- Green: git branch (if in a repo)
- Timestamp
- Exit status: ✓ (0) or 💜 (non-zero)
- user@host:cwd
