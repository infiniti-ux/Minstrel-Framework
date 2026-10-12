#!/usr/bin/env bash
set -euo pipefail

# ============================================================================ #
#  Setup Minstrel Direct — Minstrel Framework Web & CVE Module                 #
# ============================================================================ #

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MAIN_BIN="$ROOT_DIR/minstrel-direct.sh"
[[ ! -f "$MAIN_BIN" && -f "$ROOT_DIR/main/minstrel-direct.sh" ]] && MAIN_BIN="$ROOT_DIR/main/minstrel-direct.sh"

chmod +x "$MAIN_BIN"

printf '\033[38;5;46m▸\033[0m Linking \033[1;97mminstrel-direct\033[0m command to /usr/local/bin/minstrel-direct …\n'
sudo ln -sf "$MAIN_BIN" /usr/local/bin/minstrel-direct

printf '\033[38;5;46m✓\033[0m \033[1;97mSetup Complete!\033[0m\n'
printf '  Run \033[38;5;46mminstrel-direct\033[0m to launch the interactive TUI workspace.\n'
printf '  Note for TOR Stealth Mode: An active Internet connection and the \033[1;97mtor\033[0m package are required.\n'
