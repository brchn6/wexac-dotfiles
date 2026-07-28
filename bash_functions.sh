# =============================================================================
# wexac-dotfiles — ~/.bash_functions.sh
#
# A collection of bash functions for cluster work, tmux, file inspection,
# process management, and everyday productivity on LSF/HPC systems.
#
# Source this from your ~/.bashrc:
#   [ -f ~/.bash_functions.sh ] && . ~/.bash_functions.sh
#
# If TMUX_LOG_DIR is not set, logs default to $HOME/tmux-logs/.
# =============================================================================

# =============================================================================
# LSF helpers
# =============================================================================

# bp — bpeek shortcut (view LSF job output)
bp() { bpeek "$@"; }

# bjmem — memory summaries for LSF jobs
bjmem() { bj -l | awk '/Job <[0-9]+>/ || /MAX MEM/'; }

# bjm — rich job monitor
bjm() {
  bj -l | awk '
    /^Job </ {
      if (match($0, /Job <([^>]+)>/, a)) jobid = a[1]
      if (match($0, /Job Name <([^>]+)>/, b)) jobname = b[1]
    }
    /MEMLIMIT/ {
      memlimit_line = $0
      getline
      memlimit_val = $0
    }
    /MEMORY USAGE:/ {
      print "----------------------------------------"
      print "Job:  " jobid
      print "Name: " jobname
      print memlimit_line
      print memlimit_val
      print $0
      getline; print
      getline; print
    }
  '
}

# =============================================================================
# OpenCode session helpers
# =============================================================================

# osl — list opencode sessions (last N, default 100)
osl() {
    local limit="${1:-100}"
    python3 -c "
import sqlite3, sys
from datetime import datetime, timezone
db = sqlite3.connect('$HOME/.local/share/opencode/opencode.db')
cur = db.execute('SELECT id, slug, title, directory, time_updated FROM session ORDER BY time_updated ASC LIMIT $limit')
rows = cur.fetchall()
if not rows:
    sys.exit(0)
rows_disp = []
for r in rows:
    dt = datetime.fromtimestamp(r[4] / 1000, tz=timezone.utc).strftime('%Y-%m-%d %H:%M')
    rows_disp.append((r[0], r[1], r[2], r[3], dt))
widths = [max(len(str(r[i])) for r in rows_disp) for i in range(5)]
headers = ['ID', 'SLUG', 'TITLE', 'DIRECTORY', 'UPDATED']
fmt = '  '.join(f'{{:<{max(w, len(h))}}}' for w, h in zip(widths, headers))
print(fmt.format(*headers))
for r in rows_disp:
    print(fmt.format(*[str(x) for x in r]))
"
}

# ocs — resume/continue an opencode session
ocs() {
    if [[ $# -eq 0 ]]; then
        opencode --continue
        return
    fi

    local target="$1"
    local session_id=""

    if [[ "$target" == ses_* ]]; then
        session_id="$target"
    elif [[ "$target" =~ ^[0-9]+$ ]]; then
        session_id=$(python3 -c "
import sqlite3
db = sqlite3.connect('$HOME/.local/share/opencode/opencode.db')
cur = db.execute('SELECT id FROM session ORDER BY time_updated ASC LIMIT 1 OFFSET $((target - 1))')
row = cur.fetchone()
if row:
    print(row[0])
")
    else
        echo "ocs: expected row number or session ID, got: $target" >&2
        return 1
    fi

    if [[ -z "$session_id" ]]; then
        echo "ocs: no session at row $target" >&2
        return 1
    fi

    echo "ocs: resuming $session_id ..."
    opencode --session "$session_id"
}

# osc — opencode session shortcut
osc() {
  if [ $# -eq 0 ]; then
    opencode session list
    echo ""
    echo "Usage: osc <session-id>"
  else
    opencode -s "$@"
  fi
}

# =============================================================================
# Tmux helpers
# =============================================================================

# tks — kill a tmux session
tks() { tmux kill-session -t "$@"; }

# tas — attach to a tmux session (or switch if already inside tmux)
tas() {
  local target="$1"
  if [ -z "$target" ]; then
    echo "tas: usage: tas <session-name>" >&2
    return 2
  fi

  if [ -n "$TMUX" ]; then
    tmux switch-client -t "$target"
    return $?
  fi

  if [ -t 0 ] && [ -t 1 ]; then
    tmux attach-session -t "$target"
  else
    echo "tas: no controlling terminal (cannot attach from xargs/non-interactive shell)." >&2
    echo "tas: run 'tas <name>' directly, or inside tmux use 'tmux switch-client -t <name>'." >&2
    return 1
  fi
}

# tls — list tmux sessions
tls() { tmux list-sessions; }

# tkas — kill ALL tmux sessions
tkas() { tmux list-sessions | awk -F: '{print $1}' | xargs -r -I {} tmux kill-session -t {}; }

# taf — attach to the first/only session
taf() {
  local first
  first=$(tmux list-sessions -F '#S' 2>/dev/null | head -n 1)
  if [ -z "$first" ]; then
    echo "taf: no tmux sessions found." >&2
    return 1
  fi
  tas "$first"
}

export -f tks tas tls tkas taf

# =============================================================================
# Parquet tools shortcuts
# =============================================================================

pt()         { parquet-tools "$@"; }
ptc()        { parquet-tools cat -f tsv "$@"; }
ptc20()      { parquet-tools cat -f tsv --limit 20 "$@"; }
ptc1()       { parquet-tools cat -f tsv --limit 1 "$@"; }
ptimport()   { parquet-tools import "$@"; }
ptmerge()    { parquet-tools merge "$@"; }
ptmeta()     { parquet-tools meta "$@"; }
ptrowcount() { parquet-tools row-count "$@"; }
pts()        { parquet-tools schema "$@" | jq; }
ptsize()     { parquet-tools size "$@"; }
export -f pt ptc ptc20 ptimport ptmerge ptmeta ptrowcount pts ptsize

# =============================================================================
# xa — xargs wrapper that preserves quotes, aliases, and functions
# =============================================================================
xa() {
    local cmd="$1"
    shift

    if alias "$cmd" 2>/dev/null | grep -q "^alias $cmd="; then
        cmd="$(alias "$cmd" | sed -E "s/alias $cmd='(.*)'/\1/")"
    fi

    if [ "$(type -t "$cmd")" = "function" ]; then
        export -f "$cmd"
        xargs -I {} bash -c '"$0" "$@"' "$cmd" {} "$@"
    else
        xargs -I {} "$cmd" "$@" {}
    fi
}
export -f xa

# =============================================================================
# History search
# =============================================================================
hist_search() {
    history | grep --color=auto "$1"
}

# =============================================================================
# Prompt helpers
# =============================================================================
parse_git_branch() {
    git branch 2>/dev/null | grep '*' | sed 's/* //'
}

# ── ⚠️ OVERRIDES cd — smart venv auto-activation ──
# When you cd into a directory with .venv/, it activates.
# When you cd out, it deactivates.
cd() {
    if [ -z "$1" ]; then
        builtin cd ~
    elif [ -f "$1" ]; then
        builtin cd "$(dirname "$1")"
    else
        builtin cd "$1"
    fi

    if [ -f ".venv/bin/activate" ]; then
        if [ "$VIRTUAL_ENV" != "$PWD/.venv" ]; then
            source .venv/bin/activate
        fi
    elif [ -n "$VIRTUAL_ENV" ]; then
        deactivate 2>/dev/null
    fi
}

set_prompt() {
    local EXIT="$?"

    local White="\[\033[0m\]"
    local Green="\[\033[0;32m\]"
    local Blue="\[\033[0;36m\]"
    local Yellow="\[\033[1;33m\]"
    local Magenta="\[\033[0;35m\]"

    local Symbol=">"
    local EnvName=""
    local GitBranch=$(parse_git_branch)

    if [ -n "$VIRTUAL_ENV" ]; then
        EnvName="$Green($(basename "$VIRTUAL_ENV"))$White"
    elif [ -n "$CONDA_DEFAULT_ENV" ]; then
        EnvName="$Green($CONDA_DEFAULT_ENV)$White"
    fi

    history -a
    history -c
    history -r
    echo "$(date "+%F %T") $(history 1)" >> ~/.bash_permanent_history

    if [ $EXIT -eq 0 ]; then
        Status="✓"
    else
        Status="💜"
    fi

    PS1="$Magenta$EnvName $Green$GitBranch $White\$(date +%T) $Status $Blue\u@\h:$Yellow\w $Symbol $White"
}

# =============================================================================
# bcftools_view — pipe bcftools output through less
# =============================================================================
bcftools_view() {
    bcftools view "$1" | less
}

# =============================================================================
# rsync with delete (moves files)
# =============================================================================
rsyncwdel() {
    rsync -avz --no-g --info=progress2 --progress "$1" "$2"

    if [ $? -eq 0 ]; then
        echo "rsync completed successfully. Removing original files..."
        rm -rf "$1"
    else
        echo "rsync failed. Original files were not removed."
    fi
}

# =============================================================================
# bsubjup — submit Jupyter Lab via LSF
#
# Usage:
#   bsubjup                # Defaults: 42GB, no time limit, gsla-cpu queue
#   bsubjup -m 100GB       # 100GB
#   bsubjup -m 100GB -t 02:00  # With 2-hour wall time
#   bsubjup -q interactive      # Different queue
# =============================================================================
bsubjup() {
    local mem="42GB"
    local time=""
    local queue="gsla-cpu"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--mem) mem="$2"; shift 2 ;;
            -t|--time) time="$2"; shift 2 ;;
            -q|--queue) queue="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local time_option=()
    [[ -n "$time" ]] && time_option=(-W "$time")

    local port
    port=$(shuf -i 20000-65000 -n 1)

    echo "Using port: $port"

    local cmd="jupyter-lab --ip=0.0.0.0 --no-browser --port=${port}"

    local submit_out
    submit_out=$(bsub -q "${queue}" -R "rusage[mem=${mem}]" "${time_option[@]}" -J jupyter_env📓💻 "${cmd}" 2>&1)

    echo "$submit_out"

    local job_id
    job_id=$(echo "$submit_out" | grep -oE 'Job <[0-9]+>' | grep -oE '[0-9]+')

    if [[ -z "$job_id" ]]; then
        echo "❌ Failed to submit job"
        return 1
    fi

    echo "✅ Job submitted: $job_id"
    echo "⏳ Waiting for Jupyter URL..."

    while true; do
        local url
        url=$(bpeek "$job_id" 2>/dev/null | grep -E 'http' | grep -v '127\.0\.0\.1')

        if [[ -n "$url" ]]; then
            echo ""
            echo "🚀 Jupyter is ready:"
            echo "$url"
            echo ""
            break
        fi

        sleep 2
    done
}

# =============================================================================
# tnd — tmux send keys (or new session)
#
# Usage:
#   tnd                     # Start a new tmux session
#   tnd mysession           # Create/attach to 'mysession'
#   tnd mysession ls -la    # Send 'ls -la' to 'mysession'
# =============================================================================
tnd() {
  if [ -z "$1" ]; then
    tmux
    return
  fi

  local session="$1"
  shift
  if ! tmux has-session -t "$session" 2>/dev/null; then
    tmux new-session -d -s "$session"
  fi
  tmux send-keys -t "$session" "$*" C-m
}

# =============================================================================
# bsubistun — interactive shell on a compute node (e.g. for VS Code tunnel)
# =============================================================================
bsubistun() {
  bsub -R "rusage[mem=77GB]" -n 1 -q interactive -J "Tunnel🎵" -Is /bin/bash -l
  echo "💡 Now inside the compute node — run: code tunnel"
}

# =============================================================================
# bkill_non_is — kill non-interactive LSF jobs (safest to skip interactive ones)
# =============================================================================
bkill_non_is() {
  for jobid in $(bjobs | awk 'NR > 1 {print $1}'); do
    long_output=$(bjobs -l "$jobid" 2>/dev/null | tr -d '\n' | tr -d ' ')
    if echo "$long_output" | grep -Fq "Interactivepseudo-terminalshellmode"; then
      echo "Skipping job $jobid (interactive shell)..."
    else
      echo "Killing job $jobid (non-interactive)..."
      bkill "$jobid"
    fi
  done
}

# =============================================================================
# Tmux logged runner: tns (batch) / tni (interactive) / tlog (logger)
# =============================================================================
# Logs live under: ${TMUX_LOG_DIR:-$HOME/tmux-logs}/<session>/
#
# Usage:
#   tns  -- CMD ARGS...      # run batch (detached), log, auto-kill on finish
#   tns  NAME -- CMD ...     # same, with explicit session name
#   tns  CMD ...             # auto-named batch session
#   tni  [NAME]              # interactive (attach), logs enabled, no auto-kill
#   tlog [all|status|pane]   # log/report on tmux panes
# =============================================================================

# Ensure tns-clean is in PATH
if ! command -v tns-clean &>/dev/null && [ -f "$HOME/.local/bin/tns-clean" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

export TMUX_LOG_DIR="${TMUX_LOG_DIR:-$HOME/tmux-logs}"

__tns_enable_logging() {
  local name="$1" logdir="$2"
  while IFS= read -r pane; do
    tmux pipe-pane -o -t "$pane" "tns-clean >> '$logdir/#{window_index}.#{pane_index}.log'"
  done < <(tmux list-panes -t "$name" -F '#{pane_id}')
  tmux set-hook -t "$name" after-new-window  \
    "run-shell 'tmux pipe-pane -o -t #{pane_id} \"tns-clean >> $logdir/#{window_index}.#{pane_index}.log\"'"
  tmux set-hook -t "$name" after-split-window \
    "run-shell 'tmux pipe-pane -o -t #{pane_id} \"tns-clean >> $logdir/#{window_index}.#{pane_index}.log\"'"
}

__tns_hook_session_closed() {
  tmux set-hook -t "$1" session-closed \
    "run-shell 'printf \"[%s] session %s closed\\n\" \"\$(date +%F_%T)\" \"#{session_name}\" >> \"$TMUX_LOG_DIR/#{session_name}.events.log\"'"
}

tns() {
  local name="" do_cmd=0
  local -a cmd

  for i in "$@"; do
    if [[ "$i" == "--" ]]; then
      do_cmd=1; shift; cmd=("$@"); break
    fi
  done

  if (( ! do_cmd )); then
    if (( $# >= 1 )); then
      local first="$1"
      if { [[ "$first" == */* ]] && [[ -x "$first" ]]; } || command -v -- "$first" >/dev/null 2>&1; then
        do_cmd=1
        name="tmux-$(date +%Y%m%d-%H%M%S-%N)"
        cmd=("$@")
      else
        name="$1"; shift
        cmd=("$@")
      fi
    fi
  fi

  if [[ -z "$name" || "$name" == *"/"* || "$name" == *" "* || "$name" == -* ]]; then
    name="tmux-$(date +%Y%m%d-%H%M%S-%N)"
  fi

  if (( ! do_cmd )) && ((${#cmd[@]}==0)); then
    echo "tns: batch mode needs a command. Use: tns NAME -- CMD ...  or just: tns CMD ..." >&2
    echo "For interactive shell, use: tni [NAME]" >&2
    return 2
  fi

  mkdir -p "$TMUX_LOG_DIR" || { echo "tns: cannot create $TMUX_LOG_DIR"; return 1; }
  local logdir="$TMUX_LOG_DIR/$name"
  mkdir -p "$logdir" || { echo "tns: cannot create $logdir"; return 1; }

  if ! tmux has-session -t "$name" 2>/dev/null; then
    tmux new-session -d -s "$name"
  fi

  __tns_enable_logging "$name" "$logdir"
  __tns_hook_session_closed "$name"

  tmux set-hook -t "$name" pane-died \
    "run-shell 'printf \"[%s] pane %s died (%s:%s.%s)\\n\" \"\$(date +%F_%T)\" \"#{pane_id}\" \"#{session_name}\" \"#{window_index}\" \"#{pane_index}\" >> \"$TMUX_LOG_DIR/#{session_name}.events.log\"; \
               if [ \"\$(tmux list-panes -t #{session_name} 2>/dev/null | wc -l)\" -eq 0 ]; then sleep 1; tmux kill-session -t #{session_name}; fi'"

  tmux set-option -t "$name" -g remain-on-exit off

  local shcmd; shcmd=$(printf "%q " "${cmd[@]}")
  tmux send-keys -t "$name":0.0 "$shcmd" C-m

  echo "tns: started batch session '$name'. Logs: $logdir ; events: $TMUX_LOG_DIR/$name.events.log"
}

tni() {
  local name="${1:-$(date +tmux-%Y%m%d-%H%M%S)}"
  local logdir="$TMUX_LOG_DIR/$name"
  mkdir -p "$logdir" || { echo "tni: cannot create $logdir"; return 1; }

  if ! tmux has-session -t "$name" 2>/dev/null; then
    tmux new-session -d -s "$name"
  fi

  __tns_enable_logging "$name" "$logdir"
  __tns_hook_session_closed "$name"

  tmux set-option -t "$name" -g remain-on-exit on
  tmux attach -t "$name"
}

# tlog — tmux logger/reporter
tlog() {
  local mode="${1:-all}"

  if ! command -v tmux >/dev/null 2>&1; then
    echo "tlog: tmux is not available in PATH." >&2
    return 1
  fi

  if ! tmux list-sessions >/dev/null 2>&1; then
    echo "tlog: no running tmux sessions found." >&2
    return 1
  fi

  if [[ "$mode" == "pane" ]]; then
    local pane_id pane_session pane_win pane_idx pane_logdir pane_logfile
    pane_id=$(tmux display-message -p '#{pane_id}')
    pane_session=$(tmux display-message -p '#{session_name}')
    pane_win=$(tmux display-message -p '#{window_index}')
    pane_idx=$(tmux display-message -p '#{pane_index}')

    pane_logdir="$TMUX_LOG_DIR/$pane_session"
    mkdir -p "$pane_logdir" || { echo "tlog: cannot create $pane_logdir" >&2; return 1; }
    pane_logfile="$pane_logdir/${pane_win}.${pane_idx}.log"

    tmux pipe-pane -t "$pane_id"
    tmux pipe-pane -o -t "$pane_id" "cat >> '$pane_logfile'"
    echo "tlog: logging current pane to $pane_logfile"
    return 0
  fi

  if [[ "$mode" != "all" && "$mode" != "status" ]]; then
    echo "tlog: usage: tlog [all|status|pane]" >&2
    return 2
  fi

  mkdir -p "$TMUX_LOG_DIR" || { echo "tlog: cannot create $TMUX_LOG_DIR" >&2; return 1; }

  local now report_file
  now=$(date +%Y%m%d_%H%M%S)
  report_file="$TMUX_LOG_DIR/tlog_report_${now}.tsv"
  printf "session\twindow.pane\tstate\tcommand\tlog_path\tattach\n" > "$report_file"

  while IFS='|' read -r s w p pane_id cmd dead; do
    local state logdir logfile
    state="running"
    if [[ "$dead" == "1" ]]; then
      state="dead"
    elif [[ "$cmd" =~ ^(bash|zsh|fish|sh|tmux)$ ]]; then
      state="waiting"
    fi

    logdir="$TMUX_LOG_DIR/$s"
    mkdir -p "$logdir" || continue
    logfile="$logdir/${w}.${p}.log"

    if [[ "$mode" == "all" ]]; then
      tmux pipe-pane -o -t "$pane_id" "cat >> '$logfile'"
    fi

    printf "%s\t%s.%s\t%s\t%s\t%s\t%s\n" "$s" "$w" "$p" "$state" "$cmd" "$logfile" "tas $s" >> "$report_file"
  done < <(tmux list-panes -a -F '#{session_name}|#{window_index}|#{pane_index}|#{pane_id}|#{pane_current_command}|#{pane_dead}')

  if command -v column >/dev/null 2>&1; then
    column -ts $'\t' "$report_file"
  else
    cat "$report_file"
  fi

  echo ""
  echo "Report file: $report_file"
  if [[ "$mode" == "all" ]]; then
    echo "Logs root: $TMUX_LOG_DIR"
    echo "Attach to a session with: tas <session-name>"
  fi
}

# =============================================================================
# Port inspector
# =============================================================================
# myports — list all listening ports with process info
# mykill <port> — kill the process on a port

myports() {
  if ! command -v ss &>/dev/null; then
    echo "myports: 'ss' not found" >&2; return 1
  fi

  printf "%-6s %-8s %-25s %-20s %-12s %-8s %s\n" \
    "PORT" "PID" "PROCESS" "TYPE" "SINCE" "STATUS" "DETAILS"
  printf "%-6s %-8s %-25s %-20s %-12s %-8s %s\n" \
    "----" "---" "-------" "----" "-----" "------" "-------"

  ss -tlnp 2>/dev/null | grep 'users:' | while IFS= read -r line; do
    port=$(awk '{print $4}' <<< "$line" | awk -F: '{print $NF}')
    pid=$(grep -oP 'pid=\K[0-9]+' <<< "$line" | head -1)
    [ -z "$pid" ] && continue

    pname=$(grep -oP 'users:\(\(\K[^,]+' <<< "$line" | tr -d '"')
    since=$(ps -p "$pid" -o lstart= --no-headers 2>/dev/null | awk '{print $2,$3,$4}')
    cmdline=$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')

    if [[ "$cmdline" == *"agent host"* ]]; then
      type="VS Code"; details="SSH tunnel agent"
    elif [[ "$cmdline" == *"command-shell"* ]]; then
      type="VS Code"; details="Integrated terminal"
    elif [[ "$cmdline" == *"server-main.js"* ]]; then
      type="VS Code"; details="Main server process"
    elif [[ "$cmdline" == *"--type=extensionHost"* ]]; then
      type="VS Code"; details="Extension host"
    elif [[ "$cmdline" == *"streamlit"* ]]; then
      type="Streamlit"
      app=$(grep -oP 'run \K\S+' <<< "$cmdline" 2>/dev/null)
      details="${app:-app}"
    else
      type="Unknown"
      details="${cmdline:0:60}"
    fi

    printf "%-6s %-8s %-25s %-20s %-12s %-8s %s\n" \
      "$port" "$pid" "$pname" "$type" "${since:-?}" "ACTIVE" "$details"
  done
}

mykill() {
  local port=$1
  [ -z "$port" ] && { echo "Usage: mykill <port>"; return 1; }
  local pid
  pid=$(ss -tlnp 2>/dev/null | grep -P ":$port\s" | grep -oP 'pid=\K[0-9]+' | head -1)
  [ -z "$pid" ] && { echo "mykill: no process found on port $port"; return 1; }
  local pname
  pname=$(ps -p "$pid" -o comm= --no-headers 2>/dev/null || echo "?")
  echo "Killing PID $pid ($pname) on port $port..."
  kill "$pid"
}
export -f myports mykill

# =============================================================================
# User info — name or UID → details, groups, activity
# =============================================================================
userinfo() {
  local user="$1"
  if [ -z "$user" ]; then
    echo "Usage: userinfo <username or uid>"
    return 1
  fi

  if [[ "$user" =~ ^[0-9]+$ ]]; then
    local resolved
    resolved=$(getent passwd "$user" 2>/dev/null | cut -d: -f1)
    if [ -z "$resolved" ]; then
      echo "userinfo: no user with UID $user" >&2; return 1
    fi
    user="$resolved"
  fi

  if ! id "$user" &>/dev/null; then
    echo "userinfo: no such user: $user" >&2; return 1
  fi

  local uid gid primary_home primary_shell
  uid=$(id -u "$user")
  gid=$(id -g "$user")
  primary_home=$(getent passwd "$user" | cut -d: -f6)
  primary_shell=$(getent passwd "$user" | cut -d: -f7)
  local -a groups
  IFS=' ' read -ra groups <<< "$(id -nG "$user")"

  echo "═══════════════════════════════════════════"
  echo "  User: $user"
  echo "═══════════════════════════════════════════"

  if command -v lslogins &>/dev/null; then
    lslogins -u "$user" 2>/dev/null | head -15
  else
    echo "UID:    $uid"
    echo "GID:    $gid"
    echo "Home:   $primary_home"
    echo "Shell:  $primary_shell"
  fi

  echo ""
  echo "── Groups ──"
  for g in "${groups[@]}"; do
    local gid_num members count
    gid_num=$(getent group "$g" 2>/dev/null | cut -d: -f3)
    members=$(getent group "$g" 2>/dev/null | cut -d: -f4)
    if [ -n "$members" ]; then
      count=$(echo "$members" | tr ',' '\n' | wc -l)
      echo "  $g (GID ${gid_num:-?})  ${count} members"
      if [ "$count" -le 20 ]; then
        echo "    → $members"
      fi
    else
      echo "  $g (GID ${gid_num:-?})  (external group — members hidden)"
    fi
  done

  echo ""
  echo "── Activity ──"
  local procs
  procs=$(ps -u "$user" --no-headers 2>/dev/null | wc -l)
  echo "  Running processes:  ${procs:-?}"
  local who_line
  who_line=$(w -h "$user" 2>/dev/null | head -3)
  if [ -n "$who_line" ]; then
    echo "  Logged in:          yes"
    echo "$who_line" | while IFS= read -r wl; do
      echo "    $wl"
    done
  else
    echo "  Logged in:          no"
  fi
}
export -f userinfo

# =============================================================================
# Cluster queue intelligence (LSF)
# =============================================================================
#   bqinfo              → overview: all active queues + top users
#   bqinfo <queue>      → per-queue user breakdown + efficiency

bqinfo() {
  if ! command -v bqueues &>/dev/null; then
    echo "bqinfo: 'bqueues' not found — not on an LSF cluster?" >&2
    return 1
  fi

  local queue="$1"

  if [ -z "$queue" ]; then
    printf "%-22s %4s %6s %6s  %s\n" "QUEUE" "PRIO" "PEND" "RUN" "TOP USERS (jobs)"
    printf "%-22s %4s %6s %6s  %s\n" "-----" "----" "----" "---" "------------------"

    bqueues 2>/dev/null | awk 'NR>2 && $1!="----" {p=$9; r=$10; if(p=="-")p=0; if(r=="-")r=0; if(p>0||r>0) print $1, $2, p, r}' | sort -k3 -rn | \
    while IFS=' ' read -r qname prio pend run; do
      top=$(bjobs -u all -q "$qname" -o 'user stat' 2>/dev/null | \
        awk 'NF==2 && ($2=="RUN"||$2=="PEND"||$2=="SUSP") {print $1}' | sort | uniq -c | sort -rn | head -3 | \
        awk '{printf "%s(%s) ", $2, $1}')
      [ -z "$top" ] && top="-"
      printf "%-22s %4s %6s %6s  %s\n" "$qname" "$prio" "$pend" "$run" "$top"
    done

    echo ""
    bqueues 2>/dev/null | awk 'NR>2 && $1!="----" {t+=$8; p+=$9; r+=$10} END{printf "Total: %d jobs  ·  %d pending  ·  %d running\n", t, p, r}'

  else
    if ! bqueues 2>/dev/null | awk 'NR>2 {print $1}' | grep -qx "$queue"; then
      echo "bqinfo: no such queue '$queue'" >&2
      return 1
    fi

    echo "═══════════════════════════════════════════════════════════════"
    bqueues 2>/dev/null | awk -v q="$queue" '
      $1==q {printf "  Queue: %s  (PRIO %s · %s PEND · %s RUN)\n═══════════════════════════════════════════════════════════════\n", $1, $2, $9, $10}
    '

    printf "%-20s %7s %8s  %12s  %12s  %8s  %s\n" "USER" "STARTED" "PRIORITY" "CPU_TIME" "RUN_TIME" "EFF" "FLAGS"
    printf "%-20s %7s %8s  %12s  %12s  %8s  %s\n" "----" "-------" "--------" "--------" "--------" "---" "-----"

    bqueues -l "$queue" 2>/dev/null | awk '
      /^SHARE_INFO_FOR:/ {in_share=1; next}
      in_share && /^[[:space:]]*$/ {exit}
      in_share && /^ [A-Z]/ {next}
      in_share {
        user = $1
        priority = $3 + 0
        started = $4 + 0
        cpu = $6 + 0
        run = $7 + 0

        if (run > 0) {
          eff = cpu / run
          if (eff >= 1000) eff_str = sprintf("%.0fx", eff)
          else if (eff >= 100) eff_str = sprintf("%.1fx", eff)
          else if (eff >= 1) eff_str = sprintf("%.2fx", eff)
          else eff_str = sprintf("%.3fx", eff)
        } else eff_str = "-"

        if (cpu >= 1e9) cpu_str = sprintf("%.3e", cpu)
        else if (cpu >= 1e6) cpu_str = sprintf("%.3e", cpu)
        else if (cpu == int(cpu)) cpu_str = sprintf("%.0f", cpu)
        else cpu_str = sprintf("%.1f", cpu)

        if (run >= 1e9) run_str = sprintf("%.3e", run)
        else if (run >= 1e6) run_str = sprintf("%.3e", run)
        else if (run == int(run)) run_str = sprintf("%.0f", run)
        else run_str = sprintf("%.1f", run)

        flags = ""
        if (priority == 0 && run > 0) flags = "over"
        if (run > 600 && cpu < 0.1) {
          if (flags) flags = flags " "
          flags = flags "low-cpu"
        }

        printf "%-20s %7d %8.3f  %12s  %12s  %8s  %s\n", user, started, priority, cpu_str, run_str, eff_str, flags
      }
    ' 2>/dev/null
  fi
}
export -f bqinfo
