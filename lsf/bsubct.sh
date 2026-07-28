# =============================================================================
# bsubct — VS Code Remote-SSH Tunnel via LSF (WEXAC-specific)
#
# Dropbear runs a lightweight SSH server on a compute node so VS Code
# Remote-SSH can connect via ProxyCommand (bypassing the no-direct-SSH
# rule enforced by LSF).
#
# Prerequisites:
#   1. Run bsubct --init once to generate the host key
#   2. Configure your local ~/.ssh/config per cluster docs
#   3. Source this file from ~/.bashrc
#
# Usage:
#   bsubct              show status of running tunnel, or auto-submit
#   bsubct -m 4GB -W 12:0  submit with custom memory/walltime
#   bsubct --stop       kill all tunnel jobs
#   bsubct --init       generate host key (one-time)
#   bsubct --help       show full help
#
# Docs: https://hpc.weizmann.ac.il -> Running VS Code on WEXAC
# =============================================================================

bsubct() {
    local name="vs-code-tunnel-$(hostname -s)"
    local logpath="${HOME}/.bsubct"
    local keyfile="${HOME}/.ssh/vs-code-tunnel"
    local port
    port=$(python3 -c "print(9000 + ($(id -u) % 55001))")

    case "${1:-}" in
        --help|-h)
            cat <<'EOF'
Usage: bsubct [OPTIONS]

Plug-and-play VS Code Remote-SSH tunnel on LSF clusters.

Commands:
  (no args)         show status of running tunnel, or auto-submit if none
  -m, --mem   SIZE  set memory (default: 2GB)
  -W, --time  H:M   set wall time (default: 8:0)
  -q, --queue NAME  set LSF queue (default: short)
  --stop            kill all bsubct jobs
  --run             (internal) start dropbear on current node
  --init            generate host key (one-time)

Note: passing any -m/-W/-q flag forces (re)submission even if tunnel exists.
EOF
            return 0
            ;;

        --init)
            mkdir -p "${HOME}/.ssh" "$logpath"
            if [ -f "$keyfile" ]; then
                echo "Host key already exists: $keyfile"
                return 0
            fi
            echo "Generating dropbear host key (one-time) ..."
            dropbearkey -t rsa -f "$keyfile"
            echo "Done: $keyfile"
            return $?
            ;;

        --run)
            if [ ! -f "$keyfile" ]; then
                echo "bsubct: host key missing — run 'bsubct --init' first" >&2
                return 1
            fi
            if ! command -v dropbear &>/dev/null; then
                echo "bsubct: dropbear not found in PATH" >&2
                return 1
            fi
            mkdir -p "$logpath"
            echo "Tunnel starting on $(hostname) port $port"
            dropbear -F -E -p "$port" -r "$keyfile" \
                -P "${logpath}/dropbear.${port}.pid" \
                >> "${logpath}/${name}-sshd.log" 2>&1
            ;;

        --stop|-k)
            bjobs -J "$name" -o jobid -noheader 2>/dev/null | xargs -r bkill
            echo "Tunnel jobs killed."
            return 0
            ;;

        *)
            local mem="2GB" walltime="8:0" queue="short"
            local -a extra_args
            local force=0

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -m|--mem)    mem="$2";      shift 2; force=1 ;;
                    -W|--time)   walltime="$2"; shift 2; force=1 ;;
                    -q|--queue)  queue="$2";    shift 2; force=1 ;;
                    --)          shift; extra_args+=("$@"); break; force=1 ;;
                    *)           extra_args+=("$1"); shift; force=1 ;;
                esac
            done

            local job_id job_stat job_host
            job_id=$(bjobs -J "$name" -o jobid -noheader 2>/dev/null | head -1)

            if [ -n "$job_id" ] && [ "$force" -eq 0 ]; then
                job_stat=$(bjobs -J "$name" -o stat -noheader 2>/dev/null | head -1)
                job_host=$(bjobs -J "$name" -o exec_host -noheader 2>/dev/null | head -1)

                echo ""
                echo "  Tunnel job:  $job_id   [$job_stat]"
                echo "  Host:        ${job_host:-<pending>}"
                echo "  Port:        $port"
                echo "  User:        $(whoami)"
                echo ""
                if [ "$job_stat" = "RUN" ]; then
                    echo "  Ready. Connect via VS Code Remote-SSH."
                    echo ""
                    echo "  ProxyCommand (add to ~/.ssh/config):"
                    echo "    ssh login-node \"nc \\\$(bjobs -J $name -o exec_host -noheader) $port\""
                    echo ""
                else
                    echo "  Waiting for resources ..."
                fi
                echo "  Kill:  bsubct --stop"
                return 0
            fi

            if [ -n "$job_id" ]; then
                echo "Stopping old tunnel jobs ..."
                bjobs -J "$name" -o jobid -noheader 2>/dev/null | xargs -r bkill
                sleep 1
            fi

            echo "Submitting tunnel (${mem}, ${walltime}, ${queue}) ..."
            bsub -q "$queue" -J "$name" \
                -R "rusage[mem=${mem}]" \
                -W "$walltime" \
                "${extra_args[@]}" \
                "$HOME/bin/run-bsubct" 2>&1

            echo ""
            echo "  Monitor:  watch bjobs -J $name"
            echo "  Stop:     bsubct --stop"
            ;;
    esac
}
export -f bsubct
