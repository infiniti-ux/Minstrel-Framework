#!/usr/bin/env bash
set -euo pipefail

# ============================================================================ #
#  Setup Minstrel Graphi — Minstrel Framework Auto-Cryptanalysis & GPU Engine  #
# ============================================================================ #

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MAIN_BIN="$ROOT_DIR/minstrel-graphi.sh"
[[ ! -f "$MAIN_BIN" && -f "$ROOT_DIR/main/minstrel-graphi.sh" ]] && MAIN_BIN="$ROOT_DIR/main/minstrel-graphi.sh"

chmod +x "$MAIN_BIN"

printf '\033[38;5;46m▸\033[0m Linking \033[1;97mminstrel-graphi\033[0m command to /usr/local/bin/minstrel-graphi …\n'
sudo ln -sf "$MAIN_BIN" /usr/local/bin/minstrel-graphi

printf '\033[38;5;46m✓\033[0m \033[1;97mSetup Complete!\033[0m\n'
printf '  Run \033[38;5;46mminstrel-graphi\033[0m to launch the interactive TUI workspace.\n'
printf '  Optional GPU packages (Debian/Ubuntu/Kali): \033[1;97msudo apt install -y python3 hashcat clinfo openssl\033[0m\n'
