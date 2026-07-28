#!/bin/bash
# =============================================================================
# wexac-dotfiles installer
#
# Usage:
#   ./install.sh              # install to ~/.bash_functions.sh + ~/.local/bin
#   ./install.sh --dry-run    # preview what would be installed
#   ./install.sh --full       # also install LSF extras (bsubct)
# =============================================================================

set -euo pipefail

INSTALL_DIR="${HOME}"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=false
FULL=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --full)    FULL=true ;;
    esac
done

info()  { echo "  ✔ $*"; }
warn()  { echo "  ⚠ $*" >&2; }
dry()   { echo "  · $* (dry-run)"; }

install_file() {
    local src="$1" dst="$2"
    if $DRY_RUN; then
        dry "would copy $src → $dst"
        return
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    chmod "${3:-644}" "$dst"
    info "$dst"
}

echo "═══════════════════════════════════════════"
echo "  wexac-dotfiles installer"
echo "═══════════════════════════════════════════"
echo ""

# --- bash_functions.sh ---
install_file "$SRC_DIR/bash_functions.sh" "$INSTALL_DIR/.bash_functions.sh"

# --- tns-clean helper ---
install_file "$SRC_DIR/bin/tns-clean" "$INSTALL_DIR/.local/bin/tns-clean" 755

# --- LSF extras ---
if $FULL; then
    install_file "$SRC_DIR/lsf/bsubct.sh" "$INSTALL_DIR/.lsf/bsubct.sh"
fi

# --- .bashrc sourcing ---
BASHRC="$INSTALL_DIR/.bashrc"
SOURCING=$(cat <<'EOF'

# ── wexac-dotfiles ──
export TMUX_LOG_DIR="${TMUX_LOG_DIR:-$HOME/tmux-logs}"
export PATH="$HOME/.local/bin:$PATH"
[ -f ~/.bash_functions.sh ] && . ~/.bash_functions.sh
EOF
)

if ! $DRY_RUN; then
    if grep -q "wexac-dotfiles" "$BASHRC" 2>/dev/null; then
        warn ".bashrc already sources wexac-dotfiles — skipping"
    else
        echo "$SOURCING" >> "$BASHRC"
        info "added sourcing block to $BASHRC"
    fi
else
    dry "would append sourcing block to $BASHRC"
fi

echo ""
echo "═══════════════════════════════════════════"
if $DRY_RUN; then
    echo "  Dry-run complete. Run without --dry-run to install."
else
    echo "  Done! Restart your shell or run: source ~/.bashrc"
fi
echo "═══════════════════════════════════════════"
