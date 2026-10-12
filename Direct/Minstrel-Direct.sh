#!/usr/bin/env bash
set -uo pipefail
shopt -s extglob
export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=C

# ============================================================================ #
#  MINSTREL DIRECT v2.1.0 — Enterprise Web Content Discovery & CVE Engine      #
#  Part of the Minstrel Penetration Testing Framework                          #
#  Smart Auto-Proxy · TOR Stealth (SOCKS5h) · Calibrated Fuzzing · CVE Audit   #
# ============================================================================ #

readonly VERSION="2.1.0"
readonly APP_NAME="Minstrel Direct"
readonly BIN_NAME="minstrel-direct"
readonly FRAMEWORK_NAME="Minstrel"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd || pwd)"

# ---------------- PALETTE (GREEN MATRIX & CYBERPUNK) ----------------
readonly G=$'\033[1;32m'
readonly DG=$'\033[38;5;22m'
readonly LG=$'\033[38;5;46m'
readonly DGN=$'\033[38;5;28m'
readonly GRN=$'\033[38;5;40m'
readonly W=$'\033[1;97m'
readonly Y=$'\033[1;33m'
readonly R=$'\033[1;31m'
readonly CYN=$'\033[38;5;51m'
readonly PUR=$'\033[38;5;141m'
readonly ORG=$'\033[38;5;208m'
readonly GRAY=$'\033[38;5;250m'
readonly MUTED=$'\033[38;5;242m'
readonly BG=$'\033[48;5;22m'
readonly NC=$'\033[0m'

# ---------------- PRE-ALLOCATED BUFFERS (ZERO SUBSHELL OVERHEAD) ----------------
printf -v SPACE_BUF '%120s' ''
HLINE_BUF=""
for ((_i = 0; _i < 120; _i++)); do HLINE_BUF+="─"; done
unset _i

# ---------------- ASCII BANNER (MINSTREL DIRECT) ----------------
readonly -a ART=(
  "░█▄█░▀█▀░█▀█░█▀▀░▀█▀░█▀▄░█▀▀░█░░░░░█▀▄░▀█▀░█▀▄░█▀▀░█▀▀░▀█▀"
  "░█░█░░█░░█░█░▀▀█░░█░░█▀▄░█▀▀░█░░░░░█░█░░█░░█▀▄░█▀▀░█░░░░█░"
  "░▀░▀░▀▀▀░▀░▀░▀▀▀░░▀░░▀░▀░▀▀▀░▀▀▀░░░▀▀░░▀▀▀░▀░▀░▀▀▀░▀▀▀░░▀░"
)
readonly -a ART_C=(
  $'\033[38;5;28m'
  $'\033[38;5;40m'
  $'\033[38;5;46m'
)

readonly -a UAS=(
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15"
  "Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0"
  "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
)

readonly -a MODE_META=(
  [0]="TOR Stealth Mode (Full Anonymous SOCKS5h)"
  [1]="FFUF Smart Calibrated Fuzzer"
  [2]="Gobuster Rapid Directory & File Bruteforce"
  [3]="Dirb Recursive Directory Scanner"
  [4]="Nikto Web Server & Misconfiguration Audit"
  [5]="Enterprise CVE & Sensitive Surface Audit"
  [6]="Auto-Pipeline (Fuzz + CVE + Report)"
)

# Built-in fallback wordlist (used automatically if external wordlist is missing)
readonly -a BUILTIN_WORDS=(
  "admin" "administrator" "login" "logout" "dashboard" "panel" "cp" "controlpanel"
  "wp-admin" "wp-login.php" "wp-json" "wp-json/wp/v2/users" "xmlrpc.php" "wp-config.php.bak"
  "api" "api/v1" "api/v2" "api/v3" "v1" "v2" "graphql" "graphiql" "swagger" "swagger-ui"
  "swagger.json" "openapi.json" "api-docs" "v2/api-docs" "v3/api-docs" "redoc"
  "actuator" "actuator/health" "actuator/env" "actuator/mappings" "actuator/beans" "actuator/heapdump"
  ".env" ".env.local" ".env.production" ".env.staging" ".env.bak" ".env.example"
  ".git/HEAD" ".git/config" ".git/index" ".svn/entries" ".DS_Store" ".htaccess" ".htpasswd"
  "config" "config.json" "config.php" "config.yml" "config.bak" "settings.py" "web.config"
  "backup" "backups" "backup.zip" "backup.sql" "dump.sql" "db.sql" "database.sql" "db"
  "phpmyadmin" "pma" "adminer.php" "mail" "webmail" "cpanel" "whm"
  "test" "dev" "staging" "beta" "debug" "phpinfo.php" "info.php" "server-status" "server-info"
  "robots.txt" "sitemap.xml" "security.txt" ".well-known/security.txt" ".well-known/openid-configuration"
  "uploads" "files" "storage" "static" "assets" "media" "private" "internal" "secret"
  "console" "metrics" "prometheus" "health" "healthz" "readyz" "status" "version"
  "vendor/composer/installed.json" "composer.json" "package.json" "docker-compose.yml" "Dockerfile"
  "logs" "error.log" "debug.log" "access.log" "laravel.log" "storage/logs/laravel.log"
)

# ---------------- STATE VARIABLES ----------------
TARGET=""
TARGET_HOST=""
OUTDIR=""
TOOL_MODE=1
SPEED_LVL="III"
SPEED_LBL="Normal"
THREADS=40
TIMEOUT_S=7
RATE_LIMIT=0
PROXY_URL=""
TOR_FORCED=0
TOR_ACTIVE=0
TOR_EXIT_IP=""
CUSTOM_WORDLIST=""
WORDLIST=""
TMP_WORDLIST=""
SOFT404_LEN=0

QUIET_ON="${MINSTREL_DIRECT_QUIET:-0}"
DRY_ON="${MINSTREL_DIRECT_DRY:-0}"
CLI_THREADS=""
CLI_OUTDIR=""
JOBS=()
MENU_DESC=()

# Unified 72-column layout (PRT=70 interior + 2 border chars = 72 visible cols)
PRT=70
readonly TOUT_DEFAULT=74

TUI_ACTIVE=0
ORIG_STTY=""

# ---------------- TERMINAL & TUI LIFECYCLE ----------------
have() { command -v "$1" &>/dev/null; }
is_tty() { [[ -t 0 && -t 2 ]]; }
pick_ua() { echo "${UAS[$((RANDOM % ${#UAS[@]}))]}"; }

enter_tui() {
  if is_tty && [[ "$TUI_ACTIVE" -eq 0 ]]; then
    ORIG_STTY=$(stty -g 2>/dev/null || true)
    printf '\033[?1049h\033[?25l\033[2J\033[H' >&2
    TUI_ACTIVE=1
  fi
}

leave_tui() {
  if [[ "$TUI_ACTIVE" -eq 1 ]]; then
    [[ -n "$ORIG_STTY" ]] && stty "$ORIG_STTY" 2>/dev/null || stty sane 2>/dev/null || true
    printf '\033[?25h\033[?1049l' >&2
    TUI_ACTIVE=0
  else
    printf '\033[?25h' >&2 2>/dev/null || true
  fi
}

# Pure Bash visible-length helper (strips ANSI CSI sequences with zero subshells)
vlen_var() {
  local -n _out=$1
  local _s=${2:-}
  local _clean="${_s//$'\033'\[*([0-9;:?])[@-~]/}"
  _out=${#_clean}
}

# ---------------- LOGGING & TABLE RENDERING ----------------
log() {
  [[ "$QUIET_ON" == "1" ]] && return 0
  printf '  %s▸%s %s%(%H:%M:%S)T%s %s\n' "$LG" "$NC" "$DGN" -1 "$NC" "$*"
}
warn() { printf '  %s▲%s %s\n' "$Y" "$NC" "$*" >&2; }
err()  { printf '  %s✗%s %s\n' "$R" "$NC" "$*" >&2; }
die()  { err "$*"; exit 1; }
dry()  { printf '  %s[DRY-RUN]%s %s\n' "$CYN" "$NC" "$*"; }

# 72-column separator and 3-column finding row
sep() { printf '  %s%s%s\n' "$DG" "${HLINE_BUF:0:72}" "$NC"; }
row() {
  local c1=${1:-} c2=${2:-}
  printf '  %s┃%s %-28.28s %s┃%s %-37.37s %s┃%s\n' "$DG" "$NC" "$c1" "$DG" "$NC" "$c2" "$DG" "$NC"
}
frow() {
  local st=${1:-} sz=${2:-} pt=${3:-} col=${4:-$G}
  printf '  %s┃%s %s%-16.16s%s %s┃%s %-10.10s %s┃%s %s%-36.36s%s %s┃%s\n' \
    "$DG" "$NC" "$col" "$st" "$NC" "$DG" "$NC" "$sz" "$DG" "$NC" "$CYN" "$pt" "$NC" "$DG" "$NC"
}

prow() {
  local body=${1:-} back=${2:-} vl=0 pad=0
  vlen_var vl "$body"
  if (( vl > PRT )); then
    local plain="${body//$'\033'\[*([0-9;:?])[@-~]/}"
    body="${GRAY}${plain:0:$((PRT - 1))}…${NC}"
    vl=$PRT
  fi
  pad=$(( PRT - vl ))
  printf '  %s│%s%s%s%s%s%s%s│%s\n' \
    "$DG" "$NC" "$back" "$body" "$back" "${SPACE_BUF:0:pad}" "$NC" "$DG" "$NC"
}

pbox_top() {
  local t=$1 w=${2:-$TOUT_DEFAULT} tw=0 d
  vlen_var tw "$t"
  d=$(( w - 7 - tw ))
  (( d < 4 )) && d=4
  printf '  %s┌─[%s%s%s]%s%s┐%s\n' "$DG" "$NC" "$t" "$DG" "${HLINE_BUF:0:d}" "$DG" "$NC"
}

pbox_div() {
  local w=${1:-$TOUT_DEFAULT}
  printf '  %s├%s%s┤%s\n' "$DG" "${HLINE_BUF:0:$(( w - 4 ))}" "$DG" "$NC"
}

pbox_bottom() {
  local w=${1:-$TOUT_DEFAULT}
  printf '  %s└%s%s┘%s\n' "$DG" "${HLINE_BUF:0:$(( w - 4 ))}" "$DG" "$NC"
}

press_enter() {
  if is_tty; then
    PRT=70
    printf '\n' >&2
    pbox_top "${LG}NAVIGASI WORKSPACE — MINSTREL DIRECT${NC}" 74 >&2
    prow "  ${LG}▶${NC} ${W}Tekan [ENTER] atau [SPACE] untuk kembali ke menu utama${NC}" >&2
    pbox_bottom 74 >&2
    local k=""
    while IFS= read -rs -n 1 k; do
      case "$k" in
        ""|" "|$'\r'|$'\n'|q|Q) break ;;
      esac
    done
  fi
}

tool_status_line() {
  local s="" t
  for t in ffuf gobuster dirb nikto tor proxychains4 curl; do
    if have "$t"; then
      s+="${LG}●${NC}${GRAY}${t}${NC} "
    else
      s+="${MUTED}○${t}${NC} "
    fi
  done
  printf '%s' "$s"
}

# Mandatory English Notice Panel for TOR Stealth Mode
show_tor_notice_en() {
  PRT=70
  pbox_top "${PUR}TOR STEALTH MODE — MANDATORY REQUIREMENTS (ENGLISH)${NC}" 74 >&2
  prow "  ${Y}NOTICE:${NC} ${W}You MUST be connected to the Internet & have TOR installed!${NC}" >&2
  prow "  ${GRAY}1. An active Internet connection is REQUIRED for TOR circuits.${NC}" >&2
  prow "  ${GRAY}2. The 'tor' package MUST be installed & running (127.0.0.1:9050).${NC}" >&2
  prow "  ${MUTED}   Install (Debian/Kali): sudo apt install -y tor proxychains4${NC}" >&2
  pbox_bottom 74 >&2
}

banner() {
  if is_tty; then
    if [[ "$TUI_ACTIVE" -eq 1 ]]; then
      printf '\033[2J\033[H' >&2
    elif have clear; then
      clear >&2
    fi
  fi
  printf '\n'
  local i
  for ((i = 0; i < ${#ART[@]}; i++)); do
    printf '       %s%s%s\n' "${ART_C[$i]}" "${ART[$i]}" "$NC"
  done
  printf '\n'
  sep
  printf '  %s●%s  %s%-38s%s %sv%s%s  %s·%s  %sENTERPRISE EDITION%s\n' \
    "$LG" "$NC" "$W" "MINSTREL DIRECT — SMART WEB & CVE ENGINE" "$NC" \
    "$LG" "$VERSION" "$NC" "$DGN" "$NC" "$CYN" "$NC"
  sep
  PRT=70
  local tgt_disp="${TARGET:-belum dipilih}"
  tgt_disp="${tgt_disp#https://}"
  tgt_disp="${tgt_disp#http://}"
  tgt_disp="${tgt_disp:0:18}"
  local route_badge="${GRN}SMART DIRECT${NC}"
  if [[ "$TOR_FORCED" -eq 1 || "$TOR_ACTIVE" -eq 1 ]]; then
    route_badge="${PUR}TOR (9050)${NC}"
  elif [[ -n "$PROXY_URL" ]]; then
    route_badge="${CYN}CUSTOM PROXY${NC}"
  fi
  [[ "$DRY_ON" == "1" ]] && route_badge="${CYN}DRY-RUN MODE${NC}"

  pbox_top "${LG}MINSTREL DIRECT WORKSPACE${NC}" 74
  prow "  ${DGN}Target:${NC} ${W}${tgt_disp}${NC} ${MUTED}│${NC} ${DGN}Speed:${NC} ${W}${SPEED_LBL} (${SPEED_LVL})${NC} ${MUTED}│${NC} ${route_badge}"
  prow "  ${DGN}Engine:${NC} $(tool_status_line)"
  pbox_bottom 74
  printf '\n'
}

# Interactive Menu Selector with Contextual Descriptions
menu_pick() {
  local title=$1
  shift
  local opts=("$@")
  local n=${#opts[@]}
  local sel=0 key k2 line
  local i tw=0 d TOUT L=0 body back num desc_txt

  PRT=70
  TOUT=74
  vlen_var tw "$title"
  d=$(( TOUT - 7 - tw ))
  (( d < 4 )) && d=4

  while true; do
    if (( L > 0 )); then printf '\033[%dA\033[J' "$L" >&2; fi
    L=0
    printf '  %s┌─[%s%s%s]%s%s┐%s\n' "$DG" "$NC" "$title" "$DG" "${HLINE_BUF:0:d}" "$DG" "$NC" >&2
    L=$((L + 1))
    prow "" >&2; L=$((L + 1))

    for ((i = 0; i < n; i++)); do
      printf -v num '%2d' $((i + 1))
      if (( i == sel )); then
        body="${LG}  ▶ ${NC}${BG}${LG}[${num}]${NC}${BG}${W}  ${opts[$i]}"
        back="${BG}"
      else
        body="    ${DGN}[${num}]${NC}  ${GRAY}${opts[$i]}${NC}"
        back=""
      fi
      prow "$body" "$back" >&2
      L=$((L + 1))
    done

    prow "" >&2; L=$((L + 1))
    pbox_div "$TOUT" >&2; L=$((L + 1))

    if [[ -n "${MENU_DESC[$sel]:-}" ]]; then
      desc_txt="${MENU_DESC[$sel]}"
      prow "  ${CYN}ℹ${NC} ${GRAY}${desc_txt:0:$((PRT - 5))}${NC}" >&2
      L=$((L + 1))
    fi

    prow "  ${DGN}Navigasi:${NC} ${GRAY}↑↓ / j k / [1-${n}]${NC}  ${MUTED}·${NC}  ${GRAY}ENTER pilih${NC}  ${MUTED}·${NC}  ${GRAY}q keluar${NC}" >&2
    L=$((L + 1))
    pbox_bottom "$TOUT" >&2
    L=$((L + 1))

    if is_tty; then
      IFS= read -rs -n 1 key || { MENU_DESC=(); return 1; }
      case "$key" in
        ""|$'\r'|$'\n')
          printf '\033[%dA\033[J' "$L" >&2
          MENU_DESC=()
          echo $((sel + 1))
          return 0
          ;;
        $'\x03')
          printf '\033[%dA\033[J' "$L" >&2
          MENU_DESC=()
          exit 130
          ;;
        q|Q)
          printf '\033[%dA\033[J' "$L" >&2
          MENU_DESC=()
          echo "$n"
          return 0
          ;;
        k|K)
          sel=$(((sel - 1 + n) % n))
          ;;
        j|J)
          sel=$(((sel + 1) % n))
          ;;
        $'\x1b')
          IFS= read -rs -n 2 -t 0.05 k2 || k2=""
          case "$k2" in
            "[A"|"OA") sel=$(((sel - 1 + n) % n)) ;;
            "[B"|"OB") sel=$(((sel + 1) % n)) ;;
          esac
          ;;
        [1-9])
          if (( key >= 1 && key <= n )); then
            printf '\033[%dA\033[J' "$L" >&2
            printf '\n' >&2
            MENU_DESC=()
            echo "$key"
            return 0
          fi
          ;;
      esac
    else
      if ! IFS= read -r line; then MENU_DESC=(); return 1; fi
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
      if [[ $line =~ ^[0-9]+$ ]] && (( line >= 1 && line <= n )); then
        printf '\n' >&2
        MENU_DESC=()
        echo "$line"
        return 0
      fi
    fi
  done
}

confirm_yn() {
  local msg=$1 ans
  [[ "$DRY_ON" == "1" ]] && return 0
  if is_tty; then
    local c
    c=$(menu_pick "$msg" "Ya, Mulai Eksekusi Minstrel Direct" "Batal / Kembali") || return 1
    [[ "$c" == "1" ]]
  else
    printf '  %s?%s %s [Y/n]: ' "$Y" "$NC" "$msg" >&2
    IFS= read -r ans || return 1
    case "${ans:-y}" in
      y|Y|""|$'\r'|$'\n') return 0 ;;
      *) return 1 ;;
    esac
  fi
}

# ---------------- TARGET, WORDLIST & PROFILE INITIALIZATION ----------------
normalize_target_url() {
  local raw=${1:-} t host
  t=$(printf '%s' "$raw" | tr -d '[:space:]')
  [[ -z "$t" ]] && return 1
  if [[ ! "$t" =~ ^https?:// ]]; then
    t="https://$t"
  fi
  t="${t%/}"
  host=$(printf '%s' "$t" | sed -E 's#^https?://##; s#^[^@]+@##; s#[/?#].*$##; s#:[0-9]+$##')
  [[ -z "$host" ]] && return 1

  # Validate IPv4 octets (0-255) or RFC-1123 hostname
  if [[ $host =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
    local o1=${BASH_REMATCH[1]} o2=${BASH_REMATCH[2]} o3=${BASH_REMATCH[3]} o4=${BASH_REMATCH[4]}
    (( 10#$o1 <= 255 && 10#$o2 <= 255 && 10#$o3 <= 255 && 10#$o4 <= 255 )) || return 1
  elif [[ ! $host =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$ && "$host" != "localhost" ]]; then
    return 1
  fi

  printf '%s|%s\n' "$t" "${host,,}"
  return 0
}

input_target_url() {
  local raw="" parsed="" err_msg="" L=0 ch line
  PRT=70
  while true; do
    if (( L > 0 )); then printf '\033[%dA\033[J' "$L" >&2; fi
    L=0
    pbox_top "${LG}INPUT TARGET — MINSTREL DIRECT${NC}" 74 >&2; L=$((L + 1))
    prow "" >&2; L=$((L + 1))
    prow "  ${W}Masukkan URL Lengkap, Domain, atau IPv4 Target${NC}" >&2; L=$((L + 1))
    prow "  ${DGN}Contoh:${NC} ${GRAY}https://example.com  ·  app.target.id  ·  203.0.113.10${NC}" >&2; L=$((L + 1))
    prow "" >&2; L=$((L + 1))
    if [[ -n "$err_msg" ]]; then
      prow "  ${R}✗ ${err_msg:0:64}${NC}" >&2; L=$((L + 1))
    fi
    pbox_bottom 74 >&2; L=$((L + 1))

    if is_tty; then
      line=""
      printf '\033[?25h' >&2
      printf '  %s▸ Target URL/IP:%s ' "$LG" "$NC" >&2
      while IFS= read -rs -n 1 ch; do
        case "$ch" in
          ""|$'\r'|$'\n') break ;;
          $'\x7f'|$'\x08')
            if [[ -n "$line" ]]; then
              line=${line%?}
              printf '\b \b' >&2
            fi
            ;;
          $'\x03')
            printf '\033[?25l\n' >&2
            return 1
            ;;
          $'\x1b')
            IFS= read -rs -n 2 -t 0.03 _ || {
              printf '\033[?25l\n' >&2
              return 1
            }
            ;;
          *)
            line="${line}${ch}"
            printf '%s' "$ch" >&2
            ;;
        esac
      done
      printf '\033[?25l\n' >&2
      raw=$line
      printf '\033[%dA\033[J' "$((L + 1))" >&2
      L=0
    else
      printf '  %s▸ Target URL/IP:%s ' "$LG" "$NC" >&2
      if ! IFS= read -r raw; then return 1; fi
      printf '\033[%dA\033[J' "$L" >&2
      L=0
    fi

    if [[ -z "${raw//[[:space:]]/}" ]]; then
      err_msg="Target tidak boleh kosong — masukkan URL, domain, atau IPv4."
      continue
    fi
    if parsed=$(normalize_target_url "$raw"); then
      printf '  %s✓%s Target terkunci: %s%s%s\n' "$LG" "$NC" "$W" "${parsed%%|*}" "$NC" >&2
      echo "${parsed%%|*}"
      return 0
    fi
    err_msg="Target tidak valid: '$raw' (gunakan URL/domain atau IPv4 0-255)"
  done
}

resolve_wordlist() {
  if [[ -n "$CUSTOM_WORDLIST" ]]; then
    [[ -f "$CUSTOM_WORDLIST" ]] || die "Custom wordlist tidak ditemukan: $CUSTOM_WORDLIST"
    WORDLIST="$CUSTOM_WORDLIST"
    return 0
  fi

  local candidates=(
    "$SCRIPT_DIR/wordlists/minstrel-wordlist.txt"
    "$ROOT_DIR/wordlists/minstrel-wordlist.txt"
    "$ROOT_DIR/MinstrelDirect/wordlists/minstrel-wordlist.txt"
    "$HOME/minstrel-direct/wordlists/minstrel-wordlist.txt"
    "/usr/share/seclists/Discovery/Web-Content/common.txt"
    "/usr/share/wordlists/dirb/common.txt"
  )
  local c
  for c in "${candidates[@]}"; do
    if [[ -f "$c" && -s "$c" ]]; then
      WORDLIST="$c"
      return 0
    fi
  done

  TMP_WORDLIST=$(mktemp /tmp/minstrel_direct_wl.XXXXXX)
  printf '%s\n' "${BUILTIN_WORDS[@]}" > "$TMP_WORDLIST"
  WORDLIST="$TMP_WORDLIST"
}

load_profile() {
  case "${1:-3}" in
    1|I|i|paranoid)
      SPEED_LVL="I"; SPEED_LBL="Paranoid"; THREADS=5; TIMEOUT_S=15; RATE_LIMIT=5 ;;
    2|II|ii|stealth)
      SPEED_LVL="II"; SPEED_LBL="Stealth"; THREADS=15; TIMEOUT_S=10; RATE_LIMIT=20 ;;
    3|III|iii|normal)
      SPEED_LVL="III"; SPEED_LBL="Normal"; THREADS=40; TIMEOUT_S=7; RATE_LIMIT=0 ;;
    4|IV|iv|aggressive)
      SPEED_LVL="IV"; SPEED_LBL="Aggressive"; THREADS=80; TIMEOUT_S=5; RATE_LIMIT=0 ;;
    5|V|v|insane)
      SPEED_LVL="V"; SPEED_LBL="Insane"; THREADS=120; TIMEOUT_S=4; RATE_LIMIT=0 ;;
    *)
      die "Speed profile tidak valid: '$1' (gunakan I-V atau 1-5)" ;;
  esac
}

parse_mode() {
  case "${1:-1}" in
    0|tor|eclipse|stealth)            echo 0 ;;
    1|I|i|ffuf|direct|helios)         echo 1 ;;
    2|II|ii|gobuster)                 echo 2 ;;
    3|III|iii|dirb)                   echo 3 ;;
    4|IV|iv|nikto)                    echo 4 ;;
    5|V|v|cve|cve-audit|audit)        echo 5 ;;
    6|VI|vi|auto|all|full)            echo 6 ;;
    *) die "Mode tidak valid: '$1' (gunakan 0, I-VI, atau 1-6)" ;;
  esac
}

# ---------------- TOR & SMART AUTO-PROXY ENGINE ----------------

# Verify Internet & TOR installation/service in English as required
ensure_tor_ready() {
  show_tor_notice_en
  if [[ "$DRY_ON" == "1" ]]; then
    dry "Verify internet connectivity, verify 'tor' binary, start tor service, route via socks5h://127.0.0.1:9050"
    TOR_ACTIVE=1
    PROXY_URL="socks5h://127.0.0.1:9050"
    return 0
  fi

  # 1. Verify 'tor' binary is installed
  if ! have tor; then
    err "[TOR MODE ERROR] You MUST have 'tor' installed and an active Internet connection!"
    err "Please install TOR first (e.g., 'sudo apt update && sudo apt install -y tor proxychains4')."
    return 1
  fi

  # 2. Verify active Internet connection
  if ! curl -fsSL --max-time 6 -I "https://1.1.1.1" >/dev/null 2>&1 &&
     ! curl -fsSL --max-time 6 -I "https://check.torproject.org" >/dev/null 2>&1; then
    err "[TOR MODE ERROR] You MUST be connected to the Internet to use TOR Stealth Mode!"
    return 1
  fi

  # 3. Start TOR daemon if port 9050 is not yet listening
  if ! timeout 1.5 bash -c "exec 3<>/dev/tcp/127.0.0.1/9050" 2>/dev/null; then
    log "Starting TOR daemon service (127.0.0.1:9050)…"
    if have systemctl; then
      sudo systemctl start tor >/dev/null 2>&1 || sudo service tor start >/dev/null 2>&1 || true
    elif have service; then
      sudo service tor start >/dev/null 2>&1 || true
    fi
    sleep 1
  fi

  if ! timeout 2 bash -c "exec 3<>/dev/tcp/127.0.0.1/9050" 2>/dev/null; then
    err "[TOR MODE ERROR] TOR SOCKS5 proxy is not listening on 127.0.0.1:9050."
    err "Ensure the 'tor' service is running ('sudo systemctl start tor') and you are connected to the Internet."
    return 1
  fi

  TOR_ACTIVE=1
  PROXY_URL="socks5h://127.0.0.1:9050"

  # 4. Verify live TOR circuit & exit IP
  local tor_chk
  tor_chk=$(curl -fsSL --max-time 8 -x "$PROXY_URL" "https://check.torproject.org/api/ip" 2>/dev/null || true)
  if [[ "$tor_chk" =~ \"IP\":\"([^\"]+)\" ]]; then
    TOR_EXIT_IP="${BASH_REMATCH[1]}"
    log "TOR Stealth Tunnel Active: ${PUR}socks5h://127.0.0.1:9050${NC} · Exit IP: ${G}${TOR_EXIT_IP}${NC}"
  else
    log "TOR Stealth Tunnel Active: ${PUR}socks5h://127.0.0.1:9050${NC} (DNS Leak Protection Enabled)"
  fi
  return 0
}

# Pre-flight Soft-404 Canary Calibration + Smart WAF Probe
smart_route_probe() {
  SOFT404_LEN=0
  if [[ "$TOR_FORCED" -eq 1 ]]; then
    ensure_tor_ready || return 1
  elif [[ -n "$PROXY_URL" ]]; then
    log "Menggunakan Custom Proxy: ${CYN}${PROXY_URL}${NC}"
  fi

  if [[ "$DRY_ON" == "1" ]]; then
    dry "Smart Engine probe -> $TARGET (auto-reroute to TOR SOCKS5 on HTTP 403/429 + soft-404 calibration)"
    return 0
  fi

  local -a c_args=(-skL --max-redirs 2 -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT_S" -A "$(pick_ua)")
  [[ -n "$PROXY_URL" ]] && c_args+=(-x "$PROXY_URL")

  local status
  status=$(curl "${c_args[@]}" "$TARGET" 2>/dev/null || true)
  status="${status:-000}"

  # If HTTPS failed with 000 and user didn't force scheme, try HTTP fallback
  if [[ "$status" == "000" && "$TARGET" == https://* ]]; then
    local http_try="http://${TARGET#https://}"
    local http_st
    http_st=$(curl "${c_args[@]}" "$http_try" 2>/dev/null || true)
    if [[ -n "$http_st" && "$http_st" != "000" ]]; then
      TARGET="$http_try"
      status="$http_st"
    fi
  fi

  if [[ "$TOR_ACTIVE" -eq 0 && ( "$status" == "403" || "$status" == "429" || "$status" == "503" ) ]]; then
    warn "Smart Engine mendeteksi WAF / Rate-Limit Block (HTTP $status) pada $TARGET!"
    warn "Mengaktifkan Auto-Proxy Failover ke jaringan TOR SOCKS5…"
    if ensure_tor_ready; then
      log "Failover berhasil — seluruh trafik dialihkan via TOR (127.0.0.1:9050)."
    else
      warn "TOR tidak tersedia — melanjutkan dalam Direct Mode dengan header evasion."
    fi
  elif [[ "$TOR_ACTIVE" -eq 0 ]]; then
    log "Smart Engine Probe: ${G}Connection Clean (HTTP ${status})${NC} · Mode: ${W}Direct High-Speed${NC}"
  fi

  # Soft-404 / Wildcard Canary Calibration Probe (used by Gobuster & Native Fuzzer)
  local canary="minstrel-canary-${RANDOM}-${RANDOM}"
  local cal_out cal_code cal_sz
  local -a cal_args=(-sk -o /dev/null -w '%{http_code}|%{size_download}' --max-time "$TIMEOUT_S" -A "$(pick_ua)")
  [[ -n "$PROXY_URL" ]] && cal_args+=(-x "$PROXY_URL")
  cal_out=$(curl "${cal_args[@]}" "${TARGET}/${canary}" 2>/dev/null || true)
  cal_code="${cal_out%%|*}"
  cal_sz="${cal_out#*|}"
  cal_sz="${cal_sz//[^0-9]/}"
  if [[ "$cal_code" == "200" && -n "$cal_sz" && "$cal_sz" -gt 0 ]]; then
    SOFT404_LEN="$cal_sz"
    log "Auto-Calibration: terdeteksi Soft-404 Wildcard (HTTP 200 · ${SOFT404_LEN}B) — auto-exclude aktif."
  fi

  return 0
}

# ---------------- SAFE COUNTERS & RECORDING ----------------
count_lines() {
  local f=${1:-} n=0
  if [[ -s "$f" ]]; then
    n=$(wc -l < "$f" 2>/dev/null | tr -d '[:space:]')
  fi
  printf '%s' "${n:-0}"
}

count_pattern() {
  local pat=$1 f=${2:-} n=0
  if [[ -s "$f" ]]; then
    n=$(grep -cE "$pat" "$f" 2>/dev/null || true)
    n=${n//[^0-9]/}
  fi
  printf '%s' "${n:-0}"
}

record_finding() {
  local st=$1 sz=$2 pt=$3 col=$G
  case "$st" in
    200|201|204) col=$G ;;
    301|302|307|308) col=$Y ;;
    401|403|405) col=$ORG ;;
    CVE*|VULN*|CRIT*|HIGH*|EXPOSED|CORS*) col=$R ;;
    *) col=$CYN ;;
  esac
  frow "[$st]" "$sz" "$pt" "$col"
  printf '%s|%s|%s\n' "$st" "$sz" "$pt" >> "$OUTDIR/findings.raw"
}

print_table_header() {
  sep
  frow "STATUS" "SIZE/SEV" "DISCOVERED PATH / CVE FINDING" "$W"
  sep
}

# ---------------- EXECUTION ENGINES (ENTERPRISE & CVE UPGRADED) ----------------

# High-Efficiency Batched Curl Worker (reuses HTTP/TLS connections per worker)
native_fuzz_batch() {
  local base=$1 timeout_s=$2 proxy_arg=$3 baseline_len=$4
  shift 4
  local ua word out code sz
  ua=$(pick_ua)
  local -a c_args=(-sk -o /dev/null -w '%{http_code}|%{size_download}' --keepalive-time 30 --max-time "$timeout_s" -A "$ua")
  [[ -n "$proxy_arg" ]] && c_args+=(-x "$proxy_arg")

  for word in "$@"; do
    word="${word#/}"
    [[ -z "$word" ]] && continue
    out=$(curl "${c_args[@]}" "${base}/${word}" 2>/dev/null || true)
    code="${out%%|*}"
    sz="${out#*|}"
    [[ -z "$code" || "$code" == "000" || "$code" == "404" || "$code" == "400" ]] && continue
    if [[ "$baseline_len" -gt 0 && "$code" == "200" && "$sz" == "$baseline_len" ]]; then
      continue
    fi
    printf '%s|%sB|/%s\n' "$code" "${sz:-0}" "$word"
  done
}

run_native_fuzzer() {
  log "Menjalankan Native Calibrated HTTP Fuzzer (batched connection-reuse engine)…"
  local tmp_hits="$OUTDIR/.native_hits.tmp"
  : > "$tmp_hits"

  local -a words=()
  local word
  while IFS= read -r word || [[ -n "$word" ]]; do
    word="${word%%[$'\r\n']*}"
    [[ -z "$word" || "$word" =~ ^# ]] && continue
    words+=("$word")
  done < "$WORDLIST"

  local total_w=${#words[@]}
  (( total_w == 0 )) && return 0

  local workers=$(( THREADS > 24 ? 24 : THREADS ))
  (( workers > total_w )) && workers=$total_w
  (( workers < 1 )) && workers=1
  local chunk=$(( (total_w + workers - 1) / workers ))

  local idx=0
  while (( idx < total_w )); do
    local -a slice=("${words[@]:idx:chunk}")
    native_fuzz_batch "$TARGET" "$TIMEOUT_S" "$PROXY_URL" "${SOFT404_LEN:-0}" "${slice[@]}" >> "$tmp_hits" &
    idx=$((idx + chunk))
  done
  wait

  if [[ -s "$tmp_hits" ]]; then
    local st sz pt
    while IFS='|' read -r st sz pt; do
      [[ -z "$st" ]] && continue
      record_finding "$st" "$sz" "$pt"
    done < "$tmp_hits"
  fi
  rm -f "$tmp_hits"
}

# Mode 1: FFUF v2 Smart Calibrated Fuzzer (-ac auto-calibration + JSON telemetry)
engine_ffuf() {
  log "Engine: ${W}FFUF Smart Calibrated Fuzzer${NC} [threads: ${G}${THREADS}${NC} · auto-calibrate: ${G}-ac${NC}]"
  print_table_header
  if [[ "$DRY_ON" == "1" ]]; then
    dry "ffuf -u ${TARGET}/FUZZ -w ${WORDLIST} -t ${THREADS} -timeout ${TIMEOUT_S} -ac -mc 200,201,204,301,302,307,308,401,403,405 -json -s ${PROXY_URL:+-x $PROXY_URL}"
    sep
    return 0
  fi

  if ! have ffuf; then
    warn "Binary 'ffuf' belum terinstal — menggunakan Native Parallel Calibrated Fuzzer."
    run_native_fuzzer
    sep
    return 0
  fi

  local ff_json="$OUTDIR/ffuf_raw.json"
  local ff_args=(
    -u "${TARGET}/FUZZ"
    -w "$WORDLIST"
    -t "$THREADS"
    -timeout "$TIMEOUT_S"
    -ac
    -mc "200,201,204,301,302,307,308,401,403,405"
    -H "User-Agent: $(pick_ua)"
    -H "X-Forwarded-For: 127.0.0.1"
    -o "$ff_json" -of json
    -json -s
  )
  (( RATE_LIMIT > 0 )) && ff_args+=(-rate "$RATE_LIMIT")
  [[ -n "$PROXY_URL" ]] && ff_args+=(-x "$PROXY_URL")

  local line st sz pt
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    st="200"; sz="HIT"; pt=""
    [[ "$line" =~ \"status\":([0-9]+) ]] && st="${BASH_REMATCH[1]}"
    [[ "$line" =~ \"length\":([0-9]+) ]] && sz="${BASH_REMATCH[1]}B"
    if [[ "$line" =~ \"FUZZ\":\"([^\"]+)\" ]]; then
      pt="/${BASH_REMATCH[1]#/}"
    elif [[ "$line" != \{* ]]; then
      pt="/${line#/}"
    fi
    [[ -n "$pt" ]] && record_finding "$st" "$sz" "$pt"
  done < <(ffuf "${ff_args[@]}" 2>/dev/null || true)
  sep
}

# Mode 2: Gobuster v3.6+ Directory & File Bruteforce (with wildcard length exclusion)
engine_gobuster() {
  log "Engine: ${W}Gobuster Rapid Directory & File Bruteforce${NC} [threads: ${G}${THREADS}${NC}]"
  print_table_header
  if [[ "$DRY_ON" == "1" ]]; then
    dry "gobuster dir -u ${TARGET} -w ${WORDLIST} -t ${THREADS} --timeout ${TIMEOUT_S}s -k --no-error -q ${SOFT404_LEN:+--exclude-length $SOFT404_LEN} ${PROXY_URL:+--proxy $PROXY_URL}"
    sep
    return 0
  fi

  if ! have gobuster; then
    warn "Binary 'gobuster' belum terinstal — menggunakan Native Parallel Calibrated Fuzzer."
    run_native_fuzzer
    sep
    return 0
  fi

  local gb_proxy="${PROXY_URL/socks5h:/socks5:}"
  local gb_args=(
    dir -u "$TARGET" -w "$WORDLIST"
    -t "$THREADS" --timeout "${TIMEOUT_S}s"
    -a "$(pick_ua)" -k --no-error --no-color -q
  )
  (( SOFT404_LEN > 0 )) && gb_args+=(--exclude-length "$SOFT404_LEN")
  [[ -n "$gb_proxy" ]] && gb_args+=(--proxy "$gb_proxy")

  local line pt st sz
  while IFS= read -r line; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    pt="${line%%[[:space:]]*}"
    st="200"; sz="-"
    [[ "$line" =~ Status:[[:space:]]*([0-9]+) ]] && st="${BASH_REMATCH[1]}"
    [[ "$line" =~ Size:[[:space:]]*([0-9]+) ]] && sz="${BASH_REMATCH[1]}B"
    [[ -n "$pt" ]] && record_finding "$st" "$sz" "$pt"
  done < <(gobuster "${gb_args[@]}" 2>/dev/null || true)
  sep
}

# Mode 3: Dirb Recursive Directory Scan (with proper SOCKS5 wrapper via proxychains4/torsocks)
engine_dirb() {
  log "Engine: ${W}Dirb Recursive Directory Scanner${NC}"
  print_table_header
  if [[ "$DRY_ON" == "1" ]]; then
    dry "${TOR_ACTIVE:+proxychains4 -q }dirb ${TARGET} ${WORDLIST} -S -w -a '<UA>'"
    sep
    return 0
  fi

  if ! have dirb; then
    warn "Binary 'dirb' belum terinstal — menggunakan Native Parallel Calibrated Fuzzer."
    run_native_fuzzer
    sep
    return 0
  fi

  local -a runner=()
  local -a dirb_extra=()
  if [[ "$TOR_ACTIVE" -eq 1 ]]; then
    if have proxychains4; then
      runner=(proxychains4 -q)
    elif have torsocks; then
      runner=(torsocks)
    fi
  elif [[ -n "$PROXY_URL" && "$PROXY_URL" =~ ^https?:// ]]; then
    dirb_extra=(-p "$PROXY_URL")
  fi

  local line pt st sz
  while IFS= read -r line; do
    if [[ "$line" =~ ^\+[[:space:]]+([^[:space:]]+)[[:space:]]+\(CODE:([0-9]+)\|SIZE:([0-9]+)\) ]]; then
      pt="${BASH_REMATCH[1]#"$TARGET"}"
      st="${BASH_REMATCH[2]}"
      sz="${BASH_REMATCH[3]}B"
      record_finding "$st" "$sz" "${pt:-/}"
    elif [[ "$line" =~ ==\>[[:space:]]+DIRECTORY:[[:space:]]+([^[:space:]]+) ]]; then
      pt="${BASH_REMATCH[1]#"$TARGET"}"
      record_finding "DIR" "DIRECTORY" "${pt:-/}"
    fi
  done < <("${runner[@]}" dirb "$TARGET" "$WORDLIST" -S -w -a "$(pick_ua)" "${dirb_extra[@]}" 2>/dev/null || true)
  sep
}

# Mode 4: Nikto Enterprise Web Server & Misconfiguration Assessment
engine_nikto() {
  log "Engine: ${W}Nikto Web Server & Misconfiguration Audit${NC} [Tuning: ${CYN}123457890abcde${NC}]"
  print_table_header
  if [[ "$DRY_ON" == "1" ]]; then
    dry "${TOR_ACTIVE:+proxychains4 -q }nikto -h ${TARGET} -Tuning 123457890abcde -timeout ${TIMEOUT_S} -nointeractive -ask no"
    sep
    return 0
  fi

  if ! have nikto; then
    warn "Binary 'nikto' belum terinstal — mengalihkan ke Enterprise CVE & Misconfiguration Engine."
    engine_cve_audit
    return 0
  fi

  local -a runner=()
  local -a nikto_extra=()
  if [[ "$TOR_ACTIVE" -eq 1 ]]; then
    if have proxychains4; then
      runner=(proxychains4 -q)
    elif have torsocks; then
      runner=(torsocks)
    fi
  elif [[ -n "$PROXY_URL" && "$PROXY_URL" =~ ^https?:// ]]; then
    nikto_extra=(-useproxy "$PROXY_URL")
  fi

  local line clean
  while IFS= read -r line; do
    if [[ "$line" =~ ^\+[[:space:]]+(.*) ]]; then
      clean="${BASH_REMATCH[1]}"
      [[ "$clean" =~ ^(Target|Start|End|Server:) ]] && continue
      record_finding "VULN" "NIKTO" "${clean:0:36}"
    fi
  done < <("${runner[@]}" nikto -h "$TARGET" -Tuning 123457890abcde -timeout "$TIMEOUT_S" -useragent "$(pick_ua)" "${nikto_extra[@]}" -nointeractive -ask no 2>/dev/null || true)
  sep
}

# Batched CVE probe worker (reuses HTTP/TLS connections & avoids backlog drops)
cve_probe_batch() {
  local target_url=$1 timeout_s=$2 proxy_arg=$3
  shift 3
  local entry p_path p_regex p_sev p_lbl body tag
  local -a c_args=(-skL --keepalive-time 30 --max-redirs 1 --max-time "$timeout_s" -A "$(pick_ua)")
  [[ -n "$proxy_arg" ]] && c_args+=(-x "$proxy_arg")

  for entry in "$@"; do
    IFS=$'\t' read -r p_path p_regex p_sev p_lbl <<< "$entry"
    body=$(curl "${c_args[@]}" "${target_url}${p_path}" 2>/dev/null | head -c 8192 || true)
    if [[ -n "$body" ]] && grep -qE "$p_regex" <<< "$body"; then
      case "$p_sev" in
        CRITICAL|HIGH) tag="EXPOSED" ;;
        *)             tag="API-SPEC" ;;
      esac
      [[ "$p_lbl" =~ ^(CVE-[0-9]+-[0-9]+) ]] && tag="${BASH_REMATCH[1]}"
      printf '%s|%s|%s\n' "$tag" "$p_sev" "$p_lbl"
    fi
  done
}

# Mode 5: Enterprise CVE & High-Risk Exposure Audit (2024–2026 CVEs + CISA KEV + Nuclei v3)
engine_cve_audit() {
  log "Engine: ${W}Enterprise CVE & Sensitive Surface Audit (2024–2026 / CISA KEV)${NC}"
  print_table_header

  if [[ "$DRY_ON" == "1" ]]; then
    dry "Parallel CVE Probes (CVE-2025-29927, CVE-2025-24813, CVE-2024-4577, CVE-2024-23897, CVE-2024-27198, CVE-2023-46805, CVE-2021-41773, CORS, GraphQL, .env, .git, Actuator) + nuclei -u ${TARGET}"
    sep
    return 0
  fi

  local -a c_base=(-sk --max-time "$TIMEOUT_S" -A "$(pick_ua)")
  [[ -n "$PROXY_URL" ]] && c_base+=(-x "$PROXY_URL")

  # 1. Security Headers, CORS Misconfiguration & Server Banner Fingerprinting
  local hdrs srv xpb acao acac allow_hdr
  hdrs=$(curl "${c_base[@]}" -I -H "Origin: https://evil.minstrel.invalid" "$TARGET" 2>/dev/null | tr -d '\r' || true)
  if [[ -n "$hdrs" ]]; then
    srv=$(printf '%s\n' "$hdrs" | awk -F': ' 'tolower($1)=="server"{print $2; exit}')
    xpb=$(printf '%s\n' "$hdrs" | awk -F': ' 'tolower($1)=="x-powered-by"{print $2; exit}')
    acao=$(printf '%s\n' "$hdrs" | awk -F': ' 'tolower($1)=="access-control-allow-origin"{print $2; exit}')
    acac=$(printf '%s\n' "$hdrs" | awk -F': ' 'tolower($1)=="access-control-allow-credentials"{print $2; exit}')
    [[ -n "$srv" ]] && record_finding "BANNER" "SERVER" "Server: $srv"
    [[ -n "$xpb" ]] && record_finding "BANNER" "TECH" "X-Powered-By: $xpb"

    # Passive CVE Version Correlation on Server Banner
    if [[ "$srv" =~ Apache/2\.4\.(49|50) ]]; then
      record_finding "CVE-2021-41773" "CRITICAL" "Apache 2.4.49/50 Path Traversal & RCE"
    elif [[ "$srv" =~ Apache/2\.4\.([0-5][0-9]|6[01])([^0-9]|$) ]]; then
      record_finding "CVE-2024-38476" "HIGH" "Apache <2.4.62 Backend Output Handling"
    fi
    if [[ "$srv" =~ nginx/1\.(1[0-9]|2[0-5])\. ]]; then
      record_finding "CVE-2024-7347" "MEDIUM" "Nginx <1.26.2 HTTP/3 & mp4 Vulnerability"
    fi
    if [[ "$xpb" =~ PHP/(8\.1\.([0-9]|1[0-9]|2[0-8])|8\.2\.([0-9]|1[0-9])|8\.3\.[0-7])([^0-9]|$) ]]; then
      record_finding "CVE-2024-4577" "HIGH" "PHP <8.3.8/8.2.20 CGI Arg Injection"
    fi
    if [[ "$xpb" =~ Next\.js ]]; then
      record_finding "CVE-2025-29927" "CHECK" "Next.js detected - testing middleware"
    fi

    # Enterprise CORS Reflection Audit (CWE-942)
    if [[ "$acao" == "https://evil.minstrel.invalid" && "${acac,,}" == "true" ]]; then
      record_finding "CORS-VULN" "HIGH" "Arbitrary Origin + Credentials Reflected"
    elif [[ "$acao" == "https://evil.minstrel.invalid" ]]; then
      record_finding "CORS-WARN" "MEDIUM" "Arbitrary Origin Reflected in ACAO"
    fi

    # Missing Enterprise Security Headers Check
    local missing=()
    grep -qi '^strict-transport-security:' <<< "$hdrs" || missing+=("HSTS")
    grep -qi '^content-security-policy:' <<< "$hdrs"   || missing+=("CSP")
    grep -qi '^x-frame-options:' <<< "$hdrs"           || missing+=("XFO")
    grep -qi '^x-content-type-options:' <<< "$hdrs"    || missing+=("XCTO")
    if (( ${#missing[@]} > 0 )); then
      local IFS=','
      record_finding "SEC-HDR" "LOW" "Missing Security Headers: ${missing[*]}"
    fi
  fi

  # Dangerous HTTP Methods Check (OPTIONS / PUT / DELETE / TRACE)
  local opt_hdrs
  opt_hdrs=$(curl "${c_base[@]}" -I -X OPTIONS "$TARGET" 2>/dev/null | tr -d '\r' || true)
  allow_hdr=$(printf '%s\n' "$opt_hdrs" | awk -F': ' 'tolower($1)=="allow"{print $2; exit}')
  if [[ "$allow_hdr" =~ (PUT|DELETE|TRACE) ]]; then
    record_finding "HTTP-METHOD" "MEDIUM" "Risky HTTP Methods Enabled: $allow_hdr"
  fi

  # 2. Parallel Active High-Impact CVE & Exposure Signature Probes (Verified Body Matching)
  # Format (TAB-delimited): PATH \t EXPECTED_SUBSTRING_REGEX \t SEVERITY \t LABEL
  local -a cve_probes=(
    $'/.git/HEAD\tref: refs/\tHIGH\t/.git/HEAD (Git Repository Metadata)'
    $'/.env\t(DB_PASSWORD|APP_KEY|AWS_|SECRET|DATABASE_URL|REDIS_)\tCRITICAL\t/.env (Production Environment Secrets)'
    $'/.env.production\t(DB_PASSWORD|APP_KEY|AWS_|SECRET|DATABASE_URL)\tCRITICAL\t/.env.production (Prod Secrets Exposed)'
    $'/.aws/credentials\taws_access_key_id\tCRITICAL\t/.aws/credentials (AWS IAM Keys Exposed)'
    $'/actuator/env\t(propertySources|activeProfiles|systemProperties)\tCRITICAL\t/actuator/env (Spring Boot Actuator Env)'
    $'/actuator/health\t"status"[[:space:]]*:[[:space:]]*"(UP|DOWN)"\tMEDIUM\t/actuator/health (Spring Actuator Health)'
    $'/actuator/mappings\t"dispatcherServlets"\tHIGH\t/actuator/mappings (Spring Route Mappings)'
    $'/swagger.json\t"(swagger|openapi)"[[:space:]]*:\tINFO\t/swagger.json (OpenAPI / Swagger Spec)'
    $'/openapi.json\t"(swagger|openapi)"[[:space:]]*:\tINFO\t/openapi.json (OpenAPI Specification)'
    $'/v2/api-docs\t"swagger"[[:space:]]*:\tINFO\t/v2/api-docs (Springfox Swagger v2 Docs)'
    $'/v3/api-docs\t"openapi"[[:space:]]*:\tINFO\t/v3/api-docs (Springdoc OpenAPI v3 Docs)'
    $'/wp-json/wp/v2/users\t"slug"[[:space:]]*:\tMEDIUM\t/wp-json/wp/v2/users (WP User Enum CVE)'
    $'/phpinfo.php\tPHP Version [0-9]+\\.[0-9]+\tHIGH\t/phpinfo.php (PHP Configuration Exposed)'
    $'/server-status\tApache Server Status for\tMEDIUM\t/server-status (Apache mod_status)'
    $'/.well-known/openid-configuration\t"issuer"[[:space:]]*:\tINFO\t/.well-known/openid-configuration (OIDC)'
    $'/vendor/composer/installed.json\t"packages"[[:space:]]*:\tMEDIUM\t/vendor/composer/installed.json (Deps)'
    $'/docker-compose.yml\tservices:\tHIGH\t/docker-compose.yml (Container Spec)'
    $'/debug/pprof/\tTypes of profiles available\tHIGH\t/debug/pprof/ (Go Runtime Profiling)'
    $'/cgi-bin/.%2e/%2e%2e/%2e%2e/%2e%2e/etc/passwd\troot:x:0:0:\tCRITICAL\tCVE-2021-41773 (Apache Path Traversal)'
    $'/app/rest/server\tversionMajor\tCRITICAL\tCVE-2024-27198 (TeamCity Auth Bypass)'
    $'/api/v1/totp/user-backup-code/../../system/system-information\t"build"\tCRITICAL\tCVE-2023-46805 (Ivanti Connect Bypass)'
  )

  local tmp_cve="$OUTDIR/.cve_hits.tmp"
  : > "$tmp_cve"
  local total_p=${#cve_probes[@]}
  local p_workers=4
  local p_chunk=$(( (total_p + p_workers - 1) / p_workers ))
  local p_idx=0
  while (( p_idx < total_p )); do
    local -a p_slice=("${cve_probes[@]:p_idx:p_chunk}")
    cve_probe_batch "$TARGET" "$TIMEOUT_S" "$PROXY_URL" "${p_slice[@]}" >> "$tmp_cve" &
    p_idx=$((p_idx + p_chunk))
  done
  wait

  if [[ -s "$tmp_cve" ]]; then
    local c_tag c_sev c_lbl
    while IFS='|' read -r c_tag c_sev c_lbl; do
      [[ -z "$c_tag" ]] && continue
      record_finding "$c_tag" "$c_sev" "$c_lbl"
    done < "$tmp_cve"
  fi
  rm -f "$tmp_cve"

  # 3. CVE-2025-29927 Next.js Middleware Authorization Bypass Probe
  local code_normal code_bypass
  code_normal=$(curl "${c_base[@]}" -o /dev/null -w '%{http_code}' "${TARGET}/admin" 2>/dev/null || true)
  if [[ "$code_normal" == "401" || "$code_normal" == "403" || "$code_normal" == "307" || "$code_normal" == "302" ]]; then
    code_bypass=$(curl "${c_base[@]}" -o /dev/null -w '%{http_code}' \
      -H "x-middleware-subrequest: middleware:middleware:middleware:middleware:middleware" \
      -H "x-middleware-subrequest: src/middleware:src/middleware:src/middleware:src/middleware:src/middleware" \
      "${TARGET}/admin" 2>/dev/null || true)
    if [[ "$code_bypass" == "200" ]]; then
      record_finding "CVE-2025-29927" "CRITICAL" "Next.js Middleware Auth Bypass (/admin)"
    fi
  fi

  # 4. GraphQL Introspection Enabled Check (Enterprise API Security Standard)
  local gql_resp
  gql_resp=$(curl "${c_base[@]}" -X POST -H "Content-Type: application/json" \
    --data '{"query":"{__schema{types{name}}}"}' "${TARGET}/graphql" 2>/dev/null | head -c 4096 || true)
  if [[ "$gql_resp" == *"__schema"* ]]; then
    record_finding "GQL-INTRO" "MEDIUM" "/graphql (GraphQL Introspection Enabled)"
  fi

  # 5. Nuclei v3 Enterprise CVE & KEV Integration (if nuclei is installed)
  if have nuclei; then
    log "Menjalankan Nuclei v3 Enterprise Templates (cve,kev,exposures,misconfig)…"
    local nuc_args=(
      -u "$TARGET"
      -tags "cve,kev,exposures,misconfig,takeover,panel,default-login"
      -severity "critical,high,medium"
      -c "$THREADS"
      -timeout "$TIMEOUT_S"
      -silent -nc
    )
    [[ -n "$PROXY_URL" ]] && nuc_args+=(-proxy "$PROXY_URL")
    local nline tid sev
    while IFS= read -r nline; do
      [[ -z "$nline" ]] && continue
      tid="NUCLEI"; sev="HIGH"
      if [[ "$nline" =~ ^\[([^]]+)\][[:space:]]*\[[^]]+\][[:space:]]*\[([^]]+)\] ]]; then
        tid="${BASH_REMATCH[1]}"
        sev="${BASH_REMATCH[2]^^}"
      fi
      record_finding "$tid" "$sev" "${nline:0:36}"
    done < <(nuclei "${nuc_args[@]}" 2>/dev/null || true)
  fi

  sep
}

# ---------------- EXECUTIVE SUMMARY & JSON/MARKDOWN REPORT ----------------
summarize_direct() {
  local raw="$OUTDIR/findings.raw"
  local total ok_cnt redir_cnt auth_cnt cve_cnt ts route_mode
  total=$(count_lines "$raw")
  ok_cnt=$(count_pattern '^2[0-9]{2}\|' "$raw")
  redir_cnt=$(count_pattern '^3[0-9]{2}\|' "$raw")
  auth_cnt=$(count_pattern '^40[135]\|' "$raw")
  cve_cnt=$(count_pattern '^(CVE|VULN|EXPOSED|API-SPEC|SEC-HDR|CORS|HTTP-METHOD|GQL-INTRO)' "$raw")
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  route_mode="Direct"
  [[ "$TOR_ACTIVE" -eq 1 ]] && route_mode="TOR_SOCKS5h_9050"
  [[ -n "$PROXY_URL" && "$TOR_ACTIVE" -eq 0 ]] && route_mode="Custom_Proxy"

  cat > "$OUTDIR/report.json" <<EOF
{
  "framework": "$FRAMEWORK_NAME",
  "tool": "$APP_NAME",
  "version": "$VERSION",
  "target": "$TARGET",
  "host": "$TARGET_HOST",
  "mode": "${MODE_META[$TOOL_MODE]}",
  "speed_profile": "$SPEED_LBL (L$SPEED_LVL)",
  "routing": "$route_mode",
  "tor_exit_ip": "${TOR_EXIT_IP:-none}",
  "soft404_calibrated_len": $SOFT404_LEN,
  "threads": $THREADS,
  "total_findings": $total,
  "breakdown": {
    "http_2xx_ok": $ok_cnt,
    "http_3xx_redirect": $redir_cnt,
    "http_4xx_protected": $auth_cnt,
    "cve_and_exposures": $cve_cnt
  },
  "timestamp": "$ts"
}
EOF

  cat > "$OUTDIR/report.md" <<EOF
# Minstrel Direct — Enterprise Web & CVE Assessment Report

- **Framework:** \`$FRAMEWORK_NAME\`
- **Module:** \`$APP_NAME v$VERSION\`
- **Target URL:** \`$TARGET\`
- **Operation Mode:** \`${MODE_META[$TOOL_MODE]}\`
- **Routing Mode:** \`$route_mode\`
- **Speed Profile:** \`$SPEED_LBL (Level $SPEED_LVL · $THREADS threads)\`
- **Soft-404 Auto-Calibration:** \`${SOFT404_LEN}B\`
- **Timestamp (UTC):** \`$ts\`
- **Total Findings:** \`$total\` (2xx OK: $ok_cnt, 3xx Redirect: $redir_cnt, 4xx Protected: $auth_cnt, CVE/Exposures: $cve_cnt)
EOF

  printf '\n'
  row "MINSTREL DIRECT SUMMARY" "METRICS & DETAILS"
  sep
  row "Target URL" "$TARGET"
  row "Operation Mode" "${MODE_META[$TOOL_MODE]}"
  row "Network Routing" "$route_mode"
  row "Speed Profile" "$SPEED_LBL (L$SPEED_LVL / $THREADS threads)"
  row "Total Findings" "$total Discovered (2xx:$ok_cnt 4xx:$auth_cnt CVE:$cve_cnt)"
  row "JSON & Markdown Report" "$OUTDIR/report.json"
  sep
  printf '  %s» TASK ACCOMPLISHED. [ MINSTREL DIRECT v%s ]%s\n' "$LG" "$VERSION" "$NC"
}

run_direct() {
  local raw_mode=$1 raw_target=$2 speed=${3:-3} parsed
  TOOL_MODE=$(parse_mode "$raw_mode")
  if [[ "$TOOL_MODE" -eq 0 ]]; then
    TOR_FORCED=1
    TOOL_MODE=1
  fi

  if ! parsed=$(normalize_target_url "$raw_target"); then
    die "Target tidak valid: '$raw_target' — gunakan URL, domain, atau IPv4 (0-255)."
  fi
  TARGET="${parsed%%|*}"
  TARGET_HOST="${parsed#*|}"

  load_profile "$speed"
  [[ -n "${CLI_THREADS:-}" ]] && THREADS="$CLI_THREADS"
  resolve_wordlist
  OUTDIR="${CLI_OUTDIR:-minstrel_direct_${TARGET_HOST}}"
  mkdir -p "$OUTDIR"
  : > "$OUTDIR/findings.raw"

  banner
  log "Target: ${W}${TARGET}${NC} │ Mode: ${CYN}${MODE_META[$TOOL_MODE]}${NC} │ Wordlist: ${G}$(count_lines "$WORDLIST") paths${NC}"

  smart_route_probe || return 1

  case "$TOOL_MODE" in
    1) engine_ffuf ;;
    2) engine_gobuster ;;
    3) engine_dirb ;;
    4) engine_nikto ;;
    5) engine_cve_audit ;;
    6)
      engine_ffuf
      engine_cve_audit
      ;;
  esac

  summarize_direct
}

# ---------------- INTERACTIVE WIZARD & WORKSPACE VIEWS ----------------
wizard_direct() {
  banner
  local m r s tgt
  MENU_DESC=(
    "High-speed fuzzing dengan Auto-Calibration (-ac) anti false-positive SPA/WAF"
    "Enumerasi direktori & file backup cepat berbasis Go (gobuster dir)"
    "Pemindaian direktori rekursif mendalam (dirb)"
    "Audit konfigurasi web server & komprehensif tuning (nikto)"
    "Audit endpoint CVE 2024-2026, CISA KEV, Actuator, .env, .git & Security Headers"
    "Otomasi penuh: Smart Calibrated Fuzzing + Enterprise CVE Audit + Executive Report"
    "Kembali ke menu utama Minstrel Direct"
  )
  m=$(menu_pick "PILIH ENGINE & MODE OPERASI — MINSTREL DIRECT" \
    "FFUF Smart Calibrated Fuzzer   [EXTREME]" \
    "Gobuster Rapid Path Discovery  [FAST]" \
    "Dirb Recursive Directory Scan  [DEEP]" \
    "Nikto Enterprise Server Audit  [COMPREHENSIVE]" \
    "Enterprise CVE & Exposure Scan [CVE-2025/2026]" \
    "Auto-Pipeline (Fuzz + CVE)     [FULL SUITE]" \
    "← Kembali") || return 1
  [[ "$m" == "7" ]] && return 1

  banner
  show_tor_notice_en
  printf '\n' >&2
  MENU_DESC=(
    "Mode cerdas: koneksi langsung cepat, otomatis pindah ke TOR jika diblokir WAF (403/429)"
    "Wajib koneksi Internet & paket 'tor' terinstal — seluruh trafik dipaksa lewat SOCKS5 TOR"
    "Batal dan kembali ke menu utama"
  )
  r=$(menu_pick "PILIH MODE ROUTING & ANONIMITAS" \
    "Smart Auto-Proxy (Direct + Auto-Failover TOR saat 403/429)" \
    "Full TOR Stealth Mode (Mandatory: Internet + TOR Installed)" \
    "← Kembali") || return 1
  case "$r" in
    1) TOR_FORCED=0 ;;
    2) TOR_FORCED=1 ;;
    *) return 1 ;;
  esac

  banner
  MENU_DESC=(
    "Sangat lambat & senyap (5 threads, rate-limit 5/s) — cocok untuk TOR & WAF ketat"
    "Mode hati-hati (15 threads, rate-limit 20/s) — low noise"
    "Seimbang kecepatan & stabilitas (40 threads) — rekomendasi standar"
    "Konkurensi tinggi (80 threads, timeout 5s) — agresif"
    "Throughput maksimum (120 threads, timeout 4s) — jaringan berkecepatan tinggi"
    "Batal dan kembali ke menu utama"
  )
  s=$(menu_pick "PILIH PROFIL KECEPATAN" \
    "I   · Paranoid   (5 threads · Rate-Limited)" \
    "II  · Stealth    (15 threads · Low Noise)" \
    "III · Normal     (40 threads · Balanced)" \
    "IV  · Aggressive (80 threads · High Speed)" \
    "V   · Insane     (120 threads · Max Throughput)" \
    "← Kembali") || return 1
  [[ "$s" == "6" ]] && return 1

  banner
  tgt=$(input_target_url) || return 1

  banner
  load_profile "$s"
  PRT=70
  pbox_top "${LG}RINGKASAN KONFIGURASI — MINSTREL DIRECT${NC}" 74 >&2
  prow "" >&2
  prow "  ${DGN}Target URL      :${NC} ${W}${tgt}${NC}" >&2
  prow "  ${DGN}Engine Operasi  :${NC} ${LG}${MODE_META[$m]}${NC}" >&2
  if [[ "$TOR_FORCED" -eq 1 ]]; then
    prow "  ${DGN}Network Routing :${NC} ${PUR}Full TOR Stealth (socks5h://127.0.0.1:9050)${NC}" >&2
  else
    prow "  ${DGN}Network Routing :${NC} ${GRN}Smart Auto-Proxy (Direct + TOR Failover)${NC}" >&2
  fi
  prow "  ${DGN}Speed Profile   :${NC} ${Y}${SPEED_LBL} (Level ${SPEED_LVL} · ${THREADS} threads)${NC}" >&2
  prow "" >&2
  pbox_bottom 74 >&2
  printf '\n' >&2

  if confirm_yn "KONFIRMASI EKSEKUSI MINSTREL DIRECT"; then
    run_direct "$m" "$tgt" "$s" || true
    press_enter
  fi
}

view_reports() {
  banner
  shopt -s nullglob
  local dirs=(minstrel_direct_*/)
  shopt -u nullglob
  if (( ${#dirs[@]} == 0 )); then
    warn "Belum ada direktori hasil (minstrel_direct_<target>/)."
    press_enter
    return
  fi

  local opts=() d
  for d in "${dirs[@]}"; do opts+=("${d%/}"); done
  opts+=("← Kembali")

  local c
  c=$(menu_pick "PILIH LAPORAN HASIL — MINSTREL DIRECT" "${opts[@]}") || return
  (( c == ${#opts[@]} )) && return
  local chosen="${opts[$((c - 1))]}"

  banner
  row "LAPORAN: $chosen" "RINGKASAN TEMUAN"
  sep
  if [[ -s "$chosen/findings.raw" ]]; then
    local st sz pt
    while IFS='|' read -r st sz pt; do
      [[ -z "$st" ]] && continue
      frow "[$st]" "$sz" "$pt" "$G"
    done < <(head -n 25 "$chosen/findings.raw")
  else
    row "Status" "Belum ada item temuan pada sesi ini"
  fi
  sep
  press_enter
}

view_engine_health() {
  banner
  show_tor_notice_en
  printf '\n' >&2
  PRT=70
  pbox_top "${LG}DIAGNOSTIK ENGINE & STATUS TOR${NC}" 74 >&2
  prow "" >&2
  local t ver st
  for t in ffuf gobuster dirb nikto nuclei tor proxychains4 curl; do
    if have "$t"; then
      ver=$("$t" --version 2>&1 | head -1 | tr -d '\r' | cut -c1-34 || true)
      [[ -z "$ver" ]] && ver=$("$t" -version 2>&1 | head -1 | tr -d '\r' | cut -c1-34 || true)
      st="${LG}READY${NC}    ${MUTED}(${ver:-installed})${NC}"
    else
      st="${Y}FALLBACK${NC} ${MUTED}(menggunakan engine internal)${NC}"
    fi
    prow "$(printf '  %-14s : %s' "${W}${t}${NC}" "$st")" >&2
  done
  prow "" >&2
  if timeout 1 bash -c "exec 3<>/dev/tcp/127.0.0.1/9050" 2>/dev/null; then
    prow "  ${PUR}TOR Daemon (9050):${NC} ${LG}ACTIVE & LISTENING (127.0.0.1:9050)${NC}" >&2
  else
    prow "  ${PUR}TOR Daemon (9050):${NC} ${Y}INACTIVE${NC} ${MUTED}(start via: sudo systemctl start tor)${NC}" >&2
  fi
  prow "" >&2
  pbox_bottom 74 >&2
  press_enter
}

view_info() {
  banner
  show_tor_notice_en
  printf '\n' >&2
  PRT=70
  pbox_top "${LG}DOKUMENTASI & METODOLOGI — MINSTREL DIRECT${NC}" 74 >&2
  prow "" >&2
  prow "  ${W}Minstrel Direct v${VERSION}${NC} ${GRAY}(Minstrel Framework Web & CVE Module)${NC}" >&2
  prow "  ${GRAY}Enterprise Directory Discovery, Smart Auto-Proxy & CVE Audit${NC}" >&2
  prow "" >&2
  prow "  ${GRN}1. Smart Auto-Proxy${NC} ${GRAY}Deteksi blokir WAF (403/429) & auto-reroute TOR${NC}" >&2
  prow "  ${GRN}2. Calibrated Fuzz${NC}  ${GRAY}FFUF (-ac) & Native Fuzzer anti false-positive${NC}" >&2
  prow "  ${GRN}3. TOR Stealth${NC}      ${GRAY}SOCKS5h (127.0.0.1:9050) + DNS Leak Protection${NC}" >&2
  prow "  ${GRN}4. Enterprise CVE${NC}   ${GRAY}Audit CVE-2025-29927, Actuator, .env, .git & KEV${NC}" >&2
  prow "" >&2
  pbox_div 74 >&2
  prow "  ${CYN}CLI Mode:${NC}  ${W}minstrel-direct -u <URL> -t <0|I-VI> [-s <I-V>]${NC}" >&2
  prow "  ${CYN}TOR CLI:${NC}   ${W}minstrel-direct -u <URL> -t 1 --tor${NC}" >&2
  prow "  ${CYN}Env Vars:${NC}  ${GRAY}MINSTREL_DIRECT_DRY=1 · MINSTREL_DIRECT_QUIET=1${NC}" >&2
  prow "" >&2
  pbox_bottom 74 >&2
  press_enter
}

app_loop() {
  while true; do
    banner
    MENU_DESC=(
      "Wizard interaktif: pilih engine (FFUF/Gobuster/Dirb/Nikto/CVE), routing & target"
      "Aktifkan langsung Full TOR Stealth Mode (Requires Internet & TOR installed)"
      "Lihat laporan JSON/Markdown dan tabel temuan path/CVE terakhir"
      "Cek kesiapan ffuf, gobuster, dirb, nikto, nuclei & status koneksi TOR 9050"
      "Lihat dokumentasi penggunaan, arsitektur Smart Proxy & persyaratan TOR"
      "Keluar dari workspace Minstrel Direct dan kembali ke terminal"
    )
    local c
    c=$(menu_pick "MENU UTAMA — MINSTREL DIRECT" \
      "Jalankan Minstrel Direct (Wizard Interaktif)" \
      "Launch TOR Stealth Mode (Full Anonymous)" \
      "Lihat Hasil & Laporan Terakhir" \
      "Diagnostik Engine & Status TOR" \
      "Info, Dokumentasi & Metodologi" \
      "Keluar") || c=6

    case "$c" in
      1) TOR_FORCED=0; wizard_direct || true ;;
      2)
        banner
        if ensure_tor_ready; then
          TOR_FORCED=1
          local tgt
          if tgt=$(input_target_url); then
            run_direct 6 "$tgt" 2
            press_enter
          fi
        else
          press_enter
        fi
        ;;
      3) view_reports ;;
      4) view_engine_health ;;
      5) view_info ;;
      ""|6|*)
        leave_tui
        printf '  %s✓%s %sSampai jumpa! [ MINSTREL DIRECT v%s ]%s\n' "$LG" "$NC" "$W" "$VERSION" "$NC"
        exit 0
        ;;
    esac
  done
}

usage_cli() {
  banner
  show_tor_notice_en
  printf '\n'
  PRT=70
  pbox_top "${LG}PENGGUNAAN CLI — MINSTREL DIRECT${NC}" 74
  prow ""
  prow "  ${W}Interaktif (TUI):${NC}  ${LG}minstrel-direct${NC}"
  prow "  ${W}Mode CLI:${NC}          ${LG}minstrel-direct -u <URL> -t <0-6> [-s <I-V>]${NC}"
  prow ""
  prow "  ${DGN}-u <url>${NC}     ${GRAY}Target URL penuh (https://example.com)${NC}"
  prow "  ${DGN}-i <ip/host>${NC} ${GRAY}Target IP atau domain (203.0.113.10 / example.com)${NC}"
  prow "  ${DGN}-t <mode>${NC}    ${GRAY}1:FFUF 2:Gobuster 3:Dirb 4:Nikto 5:CVE 6:Auto 0:TOR${NC}"
  prow "  ${DGN}-s <speed>${NC}   ${GRAY}I:Paranoid II:Stealth III:Normal IV:Aggressive V:Insane${NC}"
  prow "  ${DGN}-w <file>${NC}    ${GRAY}Gunakan custom wordlist file${NC}"
  prow "  ${DGN}-p <proxy>${NC}   ${GRAY}Custom proxy (contoh: socks5h://127.0.0.1:9050)${NC}"
  prow "  ${DGN}--tor${NC}        ${GRAY}Force Full TOR Stealth Mode (Internet + TOR required)${NC}"
  prow ""
  pbox_bottom 74
}

# ---------------- CLEANUP & ENTRYPOINT ----------------
cleanup() {
  local j
  for j in "${JOBS[@]:-}"; do kill "$j" 2>/dev/null || true; done
  [[ -n "${TMP_WORDLIST:-}" && -f "${TMP_WORDLIST:-}" ]] && rm -f "$TMP_WORDLIST"
  leave_tui
}
trap cleanup EXIT INT TERM

# Shortcut `minstrel-direct 0` -> Launch directly in TOR Stealth interactive mode
if [[ "${1:-}" == "0" && $# -eq 1 ]]; then
  TOR_FORCED=1
  enter_tui
  app_loop
  exit 0
fi

if (( $# > 0 )); then
  RAW_TARGET=""
  TOOL_OP="1"
  SPEED_OP="3"
  while (( $# > 0 )); do
    case "$1" in
      -u|-d) RAW_TARGET="${2:-}"; shift ;;
      -i) RAW_TARGET="https://${2:-}"; shift ;;
      -t) TOOL_OP="${2:-1}"; shift ;;
      -s) SPEED_OP="${2:-3}"; shift ;;
      -T) CLI_THREADS="${2:-}"; shift ;;
      -o) CLI_OUTDIR="${2:-}"; shift ;;
      -w) CUSTOM_WORDLIST="${2:-}"; shift ;;
      -p) PROXY_URL="${2:-}"; shift ;;
      --tor) TOR_FORCED=1 ;;
      -v|--version) printf 'Minstrel Direct v%s (Minstrel Framework)\n' "$VERSION"; exit 0 ;;
      -h|--help) usage_cli; exit 0 ;;
      *) usage_cli >&2; exit 1 ;;
    esac
    shift
  done

  if [[ -z "$RAW_TARGET" ]]; then
    usage_cli >&2
    exit 1
  fi
  run_direct "$TOOL_OP" "$RAW_TARGET" "$SPEED_OP"
else
  enter_tui
  app_loop
fi
