#!/usr/bin/env bash
set -uo pipefail
shopt -s extglob
export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=en_US.UTF-8 2>/dev/null || true

# ============================================================================ #
#  MINSTREL RECON (Minstrel Reconnaisance) — Minstrel Framework Recon Module   #
#  v2.0.0 | Dedicated Interactive TUI · Fast · Silent · Modern CVE Engine      #
# ============================================================================ #

VERSION="2.0.0"
FRAMEWORK_NAME="Minstrel"
APP_NAME="Minstrel Recon"
APP_FULL_NAME="Minstrel Reconnaisance"
APP_SLUG="minstrel-recon"

# Environment variables
DRY_ON="${MINSTREL_RECON_DRY:-${MINSTREL_DRY:-0}}"
QUIET="${MINSTREL_RECON_QUIET:-${MINSTREL_QUIET:-0}}"
AUTO_UPDATE_TEMPLATES="${MINSTREL_RECON_UPDATE_TEMPLATES:-0}"

# ---------- ANSI Color Palette (True Escape Bytes) ----------
G=$'\033[1;32m'          # Bold Green (log/success)
LG=$'\033[38;5;46m'      # Neon Green (primary accent)
DG=$'\033[38;5;22m'      # Deep Forest Green (border)
DGN=$'\033[38;5;28m'     # Medium Green (secondary label)
GRN=$'\033[38;5;40m'     # Bright Emerald
CYN=$'\033[38;5;51m'     # Cyber Cyan (badges/CVE tags)
ORG=$'\033[38;5;208m'    # High Severity Orange
GRAY=$'\033[38;5;250m'   # Light Gray (body text)
MUTED=$'\033[38;5;242m'  # Muted Gray (hints/dividers)
W=$'\033[1;97m'          # Bright White
Y=$'\033[1;33m'          # Warning Yellow
R=$'\033[1;31m'          # Error / Critical Red
DIM=$'\033[2m'
NC=$'\033[0m'
BG=$'\033[48;5;22m'      # Active Selection Background

# ---------- Pre-computed Padding Buffers (Zero-Subshell Optimization) ----------
HLINE_BUF="────────────────────────────────────────────────────────────────────────────────────────────────────"
SPACE_BUF="                                                                                                    "

# ---------- Matrix Block Wordmark: MINSTREL RECON ----------
ART=(
  '░█▄█░▀█▀░█▀█░█▀▀░▀█▀░█▀▄░█▀▀░█░░░░░█▀▄░█▀▀░█▀▀░█▀█░█▀█'
  '░█░█░░█░░█░█░▀▀█░░█░░█▀▄░█▀▀░█░░░░░█▀▄░█▀▀░█░░░█░█░█░█'
  '░▀░▀░▀▀▀░▀░▀░▀▀▀░░▀░░▀░▀░▀▀▀░▀▀▀░░░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀░▀'
)
ART_C=($'\033[38;5;28m' $'\033[38;5;40m' $'\033[38;5;46m')

# ---------- Modern 2025/2026 User-Agent Pool ----------
UAS=(
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36'
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15'
  'Mozilla/5.0 (X11; Linux x86_64; rv:136.0) Gecko/20100101 Firefox/136.0'
  'Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1'
)

# ---------- Runtime State ----------
JOBS=()
MENU_DESC=()
TUI_ACTIVE=0
MINSTREL_RECON_STTY=""
DOMAIN=""
OUTDIR=""
SPEED_NUM=3
SPEED_LBL="Normal"
SPEED_LVL="III"
NMAP_TIMING=(-T4 --max-rate 150)
RETRY=3
SUB_T=50
NUC_RL=50
CONC=30

# Unified 72-column visual grid (PRT=70 inner width + 2 borders = 72 cols; TOUT=74)
PRT=70
TOUT_DEFAULT=74

MODE_META=(
  ""
  "Port & Service Discovery"
  "Subdomain & CT Enumeration"
  "Tech & Security Header Audit"
  "CVE & Vulnerability Scan"
  "Auto-Pipeline (Full Suite)"
  "Critical CVE & CISA KEV Focus"
)

is_tty() { [[ -t 0 && -t 2 ]]; }
have()   { command -v "$1" >/dev/null 2>&1; }

# Verify ProjectDiscovery httpx vs Python httpx CLI conflict
have_pd_httpx() {
  have httpx || return 1
  httpx -version 2>&1 | grep -qiE 'projectdiscovery|Current Version'
}

# ---------------- ZERO-SUBSHELL TUI ENGINE ----------------

# Enter dedicated terminal interface (Alternate Screen Buffer + Hidden Cursor)
enter_tui() {
  if is_tty && [[ "$TUI_ACTIVE" -eq 0 ]]; then
    MINSTREL_RECON_STTY=$(stty -g 2>/dev/null) || MINSTREL_RECON_STTY=""
    # Use cbreak mode (-icanon -echo) instead of raw mode so \n and signals work cleanly
    [[ -n "$MINSTREL_RECON_STTY" ]] && stty -icanon -echo min 1 time 0 2>/dev/null || true
    printf '\033[?1049h\033[?25l\033[2J\033[H' >&2
    TUI_ACTIVE=1
  fi
}

# Leave dedicated terminal interface and restore original screen & stty
leave_tui() {
  if [[ "$TUI_ACTIVE" -eq 1 ]]; then
    printf '\033[?25h\033[?1049l' >&2
    TUI_ACTIVE=0
  fi
  if [[ -n "${MINSTREL_RECON_STTY:-}" ]]; then
    stty "$MINSTREL_RECON_STTY" 2>/dev/null || true
  fi
}

# Fast visible length calculation (strips ANSI CSI sequences with zero subshells)
vlen_var() {
  local _out=$1 _str=${2:-} _clean
  _clean="${_str//$'\033'\[*([0-9;:?])[@-~]/}"
  printf -v "$_out" '%d' "${#_clean}"
}

vlen() {
  local _n
  vlen_var _n "${1:-}"
  printf '%s' "$_n"
}

fill() {
  local n=${1:-0}
  (( n < 0 )) && n=0
  if (( n <= ${#HLINE_BUF} )); then
    printf '%s' "${HLINE_BUF:0:n}"
  else
    local s="" i
    for ((i = 0; i < n; i++)); do s="${s}─"; done
    printf '%s' "$s"
  fi
}

spaces() {
  local n=${1:-0}
  (( n < 0 )) && n=0
  if (( n <= ${#SPACE_BUF} )); then
    printf '%s' "${SPACE_BUF:0:n}"
  else
    printf '%*s' "$n" ''
  fi
}

log()  { [[ "$QUIET" == "1" ]] && return 0; printf '  %s▸%s %s%s%s %s\n' "$LG" "$NC" "$DGN" "$(date +%H:%M:%S)" "$NC" "$*"; }
warn() { printf '  %s▲%s %s\n' "$Y" "$NC" "$*" >&2; }
err()  { printf '  %s✗%s %s\n' "$R" "$NC" "$*" >&2; }
die()  { leave_tui; err "$*"; exit 1; }
dry()  { printf '  %s[DRY-RUN]%s %s\n' "$CYN" "$NC" "$*"; }

# 72-column separator and table row (2+28+3+37+2 = 72 visible cols)
sep() { printf '  %s%s%s\n' "$DG" "${HLINE_BUF:0:72}" "$NC"; }
row() {
  local c1=${1:-} c2=${2:-}
  printf '  %s┃%s %-28.28s %s┃%s %-37.37s %s┃%s\n' "$DG" "$NC" "$c1" "$DG" "$NC" "$c2" "$DG" "$NC"
}

# Render one padded row inside a panel box of inner width $PRT
prow() {
  local body=${1:-} back=${2:-} vl=0 pad=0
  vlen_var vl "$body"
  if (( vl > PRT )); then
    # Strip ANSI if overflow occurs and clamp to PRT so border never shifts
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
    pbox_top "${LG}NAVIGASI WORKSPACE — MINSTREL RECON${NC}" 74 >&2
    prow "  ${LG}[ENTER / SPACE]${NC} ${GRAY}Tekan tombol apa saja untuk kembali ke workspace…${NC}" >&2
    pbox_bottom 74 >&2
    IFS= read -rs -n 1 _ || true
  fi
}

# Build live tool readiness indicator badge string
tool_status_line() {
  local s="" t
  for t in nmap subfinder whatweb nuclei curl; do
    if have "$t"; then
      s+="${LG}●${NC}${GRAY}${t}${NC}  "
    else
      s+="${MUTED}○${t}${NC}  "
    fi
  done
  if have_pd_httpx; then
    s+="${LG}●${NC}${GRAY}httpx${NC}"
  else
    s+="${LG}●${NC}${GRAY}http-probe${NC}"
  fi
  printf '%s' "$s"
}

# Main workspace header & status bar
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
    printf '          %s%s%s\n' "${ART_C[$i]}" "${ART[$i]}" "$NC"
  done
  printf '\n'
  sep
  printf '  %s●%s  %s%-39s%s %sv%s%s  %s·%s  %sCVE-2025/2026%s\n' \
    "$LG" "$NC" "$W" "MINSTREL RECONNAISANCE (MINSTREL RECON)" "$NC" \
    "$LG" "$VERSION" "$NC" "$DGN" "$NC" "$CYN" "$NC"
  sep
  PRT=70
  local tgt_disp="${DOMAIN:-belum dipilih}"
  tgt_disp="${tgt_disp:0:22}"
  local mode_badge="${GRN}LIVE ENGINE${NC}"
  [[ "$DRY_ON" == "1" ]] && mode_badge="${CYN}DRY-RUN MODE${NC}"
  pbox_top "${LG}MINSTREL RECON WORKSPACE${NC}" 74
  prow "  ${DGN}Target:${NC} ${W}${tgt_disp}${NC}  ${MUTED}│${NC}  ${DGN}Profile:${NC} ${W}${SPEED_LBL} (${SPEED_LVL})${NC}  ${MUTED}│${NC}  ${mode_badge}"
  prow "  ${DGN}Engine:${NC} $(tool_status_line)"
  pbox_bottom 74
  printf '\n'
}

# Interactive Menu Selector with Contextual Descriptions
# Usage: menu_pick <title> <opt1> ...
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
    PRT=70
    pbox_top "${LG}KONFIRMASI EKSEKUSI — MINSTREL RECON${NC}" 74 >&2
    prow "  ${W}${msg} ?${NC}   ${LG}[Y/n]${NC} ${MUTED}(Enter = Ya, n = Batal)${NC}" >&2
    pbox_bottom 74 >&2
    IFS= read -rs -n 1 ans || ans="n"
    printf '\033[3A\033[J' >&2
    case "${ans:-y}" in
      y|Y|""|$'\r'|$'\n')
        printf '  %s✓%s %s%s%s\n' "$LG" "$NC" "$W" "$msg" "$NC" >&2
        return 0
        ;;
      *)
        printf '  %s✗%s %sEksekusi dibatalkan.%s\n' "$Y" "$NC" "$GRAY" "$NC" >&2
        return 1
        ;;
    esac
  else
    printf '  %s%s ?%s %s[Y/n]%s ' "$Y" "$msg" "$NC" "$LG" "$NC" >&2
    IFS= read -r ans || ans="n"
    case "${ans:-y}" in
      y|Y|""|$'\r'|$'\n') return 0 ;;
      *) return 1 ;;
    esac
  fi
}

# Validate and sanitize target (Domain or valid IPv4 with octets 0-255)
sanitize_and_validate_target() {
  local raw=${1:-} t
  t=$(printf '%s' "$raw" | tr -d '[:space:]' | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#^[^@]+@##; s#[/?#].*$##; s#:[0-9]+$##')
  [[ -z "$t" ]] && return 1

  # Check IPv4 with strict octet bounds (0-255)
  if [[ $t =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
    local o1=${BASH_REMATCH[1]} o2=${BASH_REMATCH[2]} o3=${BASH_REMATCH[3]} o4=${BASH_REMATCH[4]}
    if (( 10#$o1 <= 255 && 10#$o2 <= 255 && 10#$o3 <= 255 && 10#$o4 <= 255 )); then
      printf '%s' "$t"
      return 0
    fi
    return 1
  fi

  # Check valid RFC-1123 domain name
  if [[ $t =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$ ]]; then
    printf '%s' "${t,,}"
    return 0
  fi

  return 1
}

input_target() {
  local raw="" t="" err_msg="" L=0 ch line
  PRT=70
  while true; do
    if (( L > 0 )); then printf '\033[%dA\033[J' "$L" >&2; fi
    L=0
    pbox_top "${LG}INPUT TARGET — MINSTREL RECON${NC}" 74 >&2; L=$((L + 1))
    prow "" >&2; L=$((L + 1))
    prow "  ${W}Masukkan Domain atau IPv4 Target${NC}" >&2; L=$((L + 1))
    prow "  ${DGN}Contoh:${NC} ${GRAY}example.com  ·  sub.target.id  ·  203.0.113.10${NC}" >&2; L=$((L + 1))
    prow "  ${MUTED}(URL penuh seperti https://example.com/path otomatis dinormalisasi)${NC}" >&2; L=$((L + 1))
    prow "" >&2; L=$((L + 1))
    if [[ -n "$err_msg" ]]; then
      prow "  ${R}✗ ${err_msg:0:64}${NC}" >&2; L=$((L + 1))
    fi
    pbox_bottom 74 >&2; L=$((L + 1))

    if is_tty; then
      line=""
      printf '\033[?25h' >&2
      printf '  %s▸ Target:%s ' "$LG" "$NC" >&2
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
      printf '  %s▸ Target:%s ' "$LG" "$NC" >&2
      if ! IFS= read -r raw; then return 1; fi
      printf '\033[%dA\033[J' "$L" >&2
      L=0
    fi

    if [[ -z "${raw//[[:space:]]/}" ]]; then
      err_msg="Target kosong — silakan masukkan domain atau IPv4."
      continue
    fi
    if t=$(sanitize_and_validate_target "$raw"); then
      printf '  %s✓%s Target terkunci: %s%s%s\n' "$LG" "$NC" "$W" "$t" "$NC" >&2
      echo "$t"
      return 0
    fi
    err_msg="Target tidak valid: '$raw' (gunakan domain atau IPv4 0-255)"
  done
}

# Animated spinner with elapsed timer and live job counter
phase_spin() {
  local label=$1
  shift
  local pids=("$@")
  local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0 t0 now alive p
  t0=$(date +%s)
  while true; do
    alive=0
    for p in "${pids[@]}"; do
      if kill -0 "$p" 2>/dev/null; then alive=$((alive + 1)); fi
    done
    (( alive == 0 )) && break
    now=$(( $(date +%s) - t0 ))
    if [[ "$QUIET" != "1" ]]; then
      printf '\r  %s%s%s %s %s[%d job aktif · %02d:%02d]%s' \
        "$LG" "${spin[$i]}" "$NC" "$label" "$DIM" "$alive" $((now / 60)) $((now % 60)) "$NC"
    fi
    i=$(( (i + 1) % ${#spin[@]} ))
    sleep 0.2
  done
  now=$(( $(date +%s) - t0 ))
  if [[ "$QUIET" != "1" ]]; then
    printf '\r\033[2K  %s✓%s %s %s(%02d:%02d)%s\n' \
      "$LG" "$NC" "$label" "$DIM" $((now / 60)) $((now % 60)) "$NC"
  fi
}

# ---------------- SAFE COUNTERS ----------------
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

count_open_ports() {
  local f=${1:-} n=0
  if [[ -s "$f" ]]; then
    n=$(grep -o '/open/' "$f" 2>/dev/null | wc -l | tr -d '[:space:]')
  fi
  printf '%s' "${n:-0}"
}

# ---------------- PROFILES & TARGET PARSING ----------------
parse_mode() {
  case "${1:-5}" in
    1|I|i|port|ports)         echo 1 ;;
    2|II|ii|sub|subs)         echo 2 ;;
    3|III|iii|tech|headers)   echo 3 ;;
    4|IV|iv|vuln|vulns)       echo 4 ;;
    5|V|v|auto|all|full)      echo 5 ;;
    6|VI|vi|cve|kev)          echo 6 ;;
    *)                        die "Mode tidak valid: '$1' (gunakan I-VI atau 1-6)" ;;
  esac
}

load_profile() {
  case "${1:-3}" in
    1|I|i)
      NMAP_TIMING=(-T1 --max-rate 10)
      RETRY=5; SUB_T=10; NUC_RL=5; CONC=5
      SPEED_NUM=1; SPEED_LBL="Paranoid"; SPEED_LVL="I"
      ;;
    2|II|ii)
      NMAP_TIMING=(-T2 --max-rate 30)
      RETRY=3; SUB_T=25; NUC_RL=15; CONC=12
      SPEED_NUM=2; SPEED_LBL="Stealth"; SPEED_LVL="II"
      ;;
    3|III|iii)
      NMAP_TIMING=(-T4 --max-rate 150)
      RETRY=3; SUB_T=50; NUC_RL=50; CONC=30
      SPEED_NUM=3; SPEED_LBL="Normal"; SPEED_LVL="III"
      ;;
    4|IV|iv)
      NMAP_TIMING=(-T4 --min-rate 400)
      RETRY=2; SUB_T=100; NUC_RL=120; CONC=60
      SPEED_NUM=4; SPEED_LBL="Aggressive"; SPEED_LVL="IV"
      ;;
    5|V|v)
      NMAP_TIMING=(-T5 --min-rate 1000)
      RETRY=1; SUB_T=150; NUC_RL=250; CONC=100
      SPEED_NUM=5; SPEED_LBL="Insane"; SPEED_LVL="V"
      ;;
    *)
      NMAP_TIMING=(-T4 --max-rate 150)
      RETRY=3; SUB_T=50; NUC_RL=50; CONC=30
      SPEED_NUM=3; SPEED_LBL="Normal"; SPEED_LVL="III"
      ;;
  esac
}

parse_target() {
  local raw=${1:-} t
  if t=$(sanitize_and_validate_target "$raw"); then
    DOMAIN=$t
  else
    die "Target tidak valid: '$raw' — gunakan domain valid atau IPv4 (0-255)."
  fi
}

# ---------------- DEPENDENCY & TEMPLATE MANAGEMENT ----------------
install_apt() {
  if [[ "$DRY_ON" == "1" ]]; then dry "apt-get install -y $*"; return 0; fi
  warn "Menginstal paket via apt: $* …"
  sudo apt-get update -qq >/dev/null 2>&1 || true
  if sudo apt-get install -y -qq "$@" >/dev/null 2>&1; then
    log "Terinstal: $*"
  else
    warn "Tidak dapat menginstal $* via apt (menggunakan engine fallback internal)."
  fi
}

try_go_install() {
  local t=$1
  have go || return 1
  warn "Fallback: go install projectdiscovery/$t …"
  if go install -v "github.com/projectdiscovery/${t}/v2/cmd/${t}@latest" >/dev/null 2>&1 ||
     go install -v "github.com/projectdiscovery/${t}/v3/cmd/${t}@latest" >/dev/null 2>&1; then
    local gobin
    gobin="$(go env GOPATH 2>/dev/null)/bin/$t"
    if [[ -x "$gobin" ]]; then
      sudo install -m 0755 "$gobin" "/usr/local/bin/$t" 2>/dev/null || cp "$gobin" "$HOME/.local/bin/$t" 2>/dev/null || true
      return 0
    fi
  fi
  return 1
}

install_pd_tool() {
  local tool=$1 os arch url tmp
  case $(uname -s) in Linux) os=linux ;; Darwin) os=macOS ;; *) os=linux ;; esac
  case $(uname -m) in x86_64|amd64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; *) arch=amd64 ;; esac
  if [[ "$DRY_ON" == "1" ]]; then dry "install $tool (${os}_${arch}) from ProjectDiscovery releases"; return 0; fi

  url=$(curl -fsSL --max-time 20 "https://api.github.com/repos/projectdiscovery/${tool}/releases/latest" 2>/dev/null \
        | grep -oE '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 \
        | grep -iE "${os}_${arch}\.zip" | head -1 || true)
  if [[ -z "$url" ]]; then
    try_go_install "$tool" || warn "Binary $tool belum tersedia — menggunakan fallback internal."
    return 0
  fi
  tmp=$(mktemp -d)
  if curl -fsSL --max-time 90 "$url" -o "$tmp/$tool.zip" 2>/dev/null && unzip -oq "$tmp/$tool.zip" -d "$tmp" 2>/dev/null; then
    if sudo install -m 0755 "$tmp/$tool" "/usr/local/bin/$tool" 2>/dev/null; then
      log "Terinstal: $tool"
    else
      mkdir -p "$HOME/.local/bin"
      install -m 0755 "$tmp/$tool" "$HOME/.local/bin/$tool" 2>/dev/null && export PATH="$HOME/.local/bin:$PATH"
      log "Terinstal (user-local): $tool"
    fi
  else
    try_go_install "$tool" || warn "Gagal mengunduh $tool — menggunakan fallback internal."
  fi
  rm -rf "$tmp"
}

check_deps() {
  local mode=${1:-5}
  have curl || die "curl wajib terpasang untuk operasi jaringan."
  if [[ "$DRY_ON" == "1" ]]; then return 0; fi

  case "$mode" in
    1) have nmap || install_apt nmap ;;
    2) have subfinder || install_pd_tool subfinder ;;
    3) have whatweb || install_apt whatweb ;;
    4|6) have nuclei || install_pd_tool nuclei ;;
    5)
      have nmap || install_apt nmap
      have whatweb || install_apt whatweb
      have subfinder || install_pd_tool subfinder
      have nuclei || install_pd_tool nuclei
      ;;
  esac

  if [[ "$AUTO_UPDATE_TEMPLATES" == "1" ]] && have nuclei; then
    log "Memperbarui Nuclei CVE templates (-ut)…"
    nuclei -ut -silent >/dev/null 2>&1 || true
  fi
}

pick_ua() { printf '%s' "${UAS[$((RANDOM % ${#UAS[@]}))]}" ; }

# ---------------- RECONNAISSANCE ENGINE (MODERN TECHNIQUES & FALLBACKS) ----------------
start_bg() { "$@" >/dev/null 2>&1 & JOBS+=($!); }
wait_jobs() {
  local j
  for j in "${JOBS[@]:-}"; do wait "$j" 2>/dev/null || true; done
  JOBS=()
}

# Fallback TCP Connect port scanner when nmap is unavailable
fallback_port_scan() {
  local target=$1 out=$2
  local top_ports=(21 22 23 25 53 80 110 111 135 139 143 443 445 993 995 1433 1521 2049 3306 3389 5432 5900 6379 8000 8080 8443 8888 9000 9090 9200 27017)
  local open_entries=() p svc
  for p in "${top_ports[@]}"; do
    if timeout 1.5 bash -c "exec 3<>/dev/tcp/${target}/${p}" 2>/dev/null; then
      case $p in
        21) svc="ftp" ;; 22) svc="ssh" ;; 23) svc="telnet" ;; 25) svc="smtp" ;;
        53) svc="domain" ;; 80|8000|8080|8888) svc="http" ;; 110) svc="pop3" ;;
        143) svc="imap" ;; 443|8443) svc="https" ;; 445) svc="microsoft-ds" ;;
        3306) svc="mysql" ;; 3389) svc="ms-wbt-server" ;; 5432) svc="postgresql" ;;
        6379) svc="redis" ;; 9200) svc="elasticsearch" ;; 27017) svc="mongodb" ;;
        *) svc="tcp-service" ;;
      esac
      open_entries+=("${p}/open/tcp//${svc}///")
    fi
  done
  if (( ${#open_entries[@]} > 0 )); then
    local joined
    joined=$(IFS=', '; printf '%s' "${open_entries[*]}")
    printf 'Host: %s ()\tPorts: %s\n' "$target" "$joined" > "$out"
  else
    printf '# Nmap-compatible fallback scan completed for %s (0 open ports)\n' "$target" > "$out"
  fi
}

# Phase 1A: Port & Service Discovery (Privilege-aware Nmap + Service Banner + Fallback)
ph_ports() {
  local scan_flag="-sT"
  local extra_flags=()
  if (( EUID == 0 )); then
    scan_flag="-sS"
    (( SPEED_NUM <= 2 )) && extra_flags+=(-D RND:3)
  fi
  local top_cnt=1000
  (( SPEED_NUM <= 2 )) && top_cnt=500

  log "Port & Service Scan: ${W}${DOMAIN}${NC} [${G}${SPEED_LBL}${NC}/${SPEED_LVL} · ${scan_flag} · top-${top_cnt}]"
  if [[ "$DRY_ON" == "1" ]]; then
    dry "nmap ${scan_flag} ${NMAP_TIMING[*]} --top-ports ${top_cnt} -sV --version-light --script banner,http-title,ssl-cert -Pn -n --max-retries ${RETRY} --open ${DOMAIN} -oG ${OUTDIR}/ports.txt"
    return 0
  fi

  if have nmap; then
    start_bg nmap "$scan_flag" "${NMAP_TIMING[@]}" "${extra_flags[@]}" \
      --top-ports "$top_cnt" -sV --version-light \
      --script "banner,http-title,ssl-cert" \
      -Pn --disable-arp-ping -n --max-retries "$RETRY" --open \
      "$DOMAIN" -oG "$OUTDIR/ports.txt" -oN "$OUTDIR/ports_detail.txt"
  else
    start_bg fallback_port_scan "$DOMAIN" "$OUTDIR/ports.txt"
  fi
}

# Passive Certificate Transparency (crt.sh) Subdomain Enrichment
fetch_crtsh_subs() {
  local domain=$1 out=$2
  curl -fsSL --max-time 15 -A "$(pick_ua)" "https://crt.sh/?q=%25.${domain}&output=json" 2>/dev/null \
    | sed 's/},{/}\n{/g' \
    | grep -oE '"(name_value|common_name)":"[^"]*"' \
    | cut -d'"' -f4 \
    | sed 's/\\n/\n/g; s/^\*\.//' \
    | tr '[:upper:]' '[:lower:]' \
    | grep -E "^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)*${domain//./\\.}$" \
    | sort -u > "$out" || true
}

run_subs_pipeline() {
  local domain=$1 out=$2 threads=$3
  : > "$out.raw"
  if have subfinder; then
    subfinder -d "$domain" -all -silent -t "$threads" -timeout 20 -o "$out.subfinder" >/dev/null 2>&1 || true
    cat "$out.subfinder" >> "$out.raw" 2>/dev/null || true
  fi
  fetch_crtsh_subs "$domain" "$out.crtsh"
  cat "$out.crtsh" >> "$out.raw" 2>/dev/null || true
  printf '%s\n' "$domain" >> "$out.raw"
  tr -d '\r' < "$out.raw" | sed '/^[[:space:]]*$/d' | tr '[:upper:]' '[:lower:]' | sort -u > "$out"
  rm -f "$out.raw" "$out.subfinder" "$out.crtsh"
}

# Phase 1B: Subdomain Enumeration (Subfinder v2 + Certificate Transparency crt.sh)
ph_subs() {
  log "Subdomain & CT Enumeration: ${W}${DOMAIN}${NC} [subfinder + crt.sh · threads: ${G}${SUB_T}${NC}]"
  if [[ "$DRY_ON" == "1" ]]; then
    dry "subfinder -d ${DOMAIN} -all -silent -t ${SUB_T} + crt.sh CT log enrichment -> ${OUTDIR}/subs.txt"
    return 0
  fi
  start_bg run_subs_pipeline "$DOMAIN" "$OUTDIR/subs.txt" "$SUB_T"
}

# Multi-scheme HTTPS -> HTTP fallback prober with Server & redirect capture
probe_one() {
  local h=$1 code="000" url="" ua
  h=$(printf '%s' "$h" | tr -d '\r[:space:]')
  [[ -z "$h" ]] && return 0
  ua=$(pick_ua)
  code=$(curl -skL --max-redirs 3 -o /dev/null -w '%{http_code}' --max-time 4 -A "$ua" "https://$h" 2>/dev/null || true)
  if [[ -n "$code" && "$code" != "000" ]]; then
    url="https://$h"
  else
    code=$(curl -sL --max-redirs 3 -o /dev/null -w '%{http_code}' --max-time 4 -A "$ua" "http://$h" 2>/dev/null || true)
    [[ -n "$code" && "$code" != "000" ]] && url="http://$h"
  fi
  printf '%s %s %s\n' "${code:-000}" "$h" "${url:--}"
}

# Phase 2: Resolve + Multi-Scheme HTTP/TLS Probe
ph_probe() {
  if [[ ! -s "$OUTDIR/subs.txt" ]]; then
    printf '%s\n' "$DOMAIN" > "$OUTDIR/subs.txt"
  else
    tr -d '\r' < "$OUTDIR/subs.txt" | sed '/^[[:space:]]*$/d' | sort -u > "$OUTDIR/subs.clean"
    mv "$OUTDIR/subs.clean" "$OUTDIR/subs.txt"
  fi

  log "HTTP/TLS Surface Probe (paralel ${G}${CONC}${NC} workers)"
  if [[ "$DRY_ON" == "1" ]]; then
    dry "probe https/http (${CONC} workers) < ${OUTDIR}/subs.txt -> ${OUTDIR}/live_hosts.txt"
    return 0
  fi

  export -f probe_one pick_ua
  export UAS OUTDIR
  # shellcheck disable=SC2016
  xargs -P "$CONC" -I{} bash -c 'probe_one "$1"' _ {} < "$OUTDIR/subs.txt" | sort -u > "$OUTDIR/probe.txt"
  awk '$1 != "000" && NF >= 2' "$OUTDIR/probe.txt" | sort -u > "$OUTDIR/live_http.txt"
  awk '{print $2}' "$OUTDIR/live_http.txt" | sort -u > "$OUTDIR/live_hosts.txt"

  local live_cnt total_cnt
  live_cnt=$(count_lines "$OUTDIR/live_hosts.txt")
  total_cnt=$(count_lines "$OUTDIR/subs.txt")
  log "Live HTTP/S hosts: ${G}${live_cnt}${NC} aktif dari ${W}${total_cnt}${NC} host"
}

# Inspect Tech Stack, WAF/CDN, and Security Headers per host
tech_inspect_one() {
  local h=$1 safe hdrs srv pow waf="" missing_sec=()
  h=$(printf '%s' "$h" | tr -d '\r[:space:]')
  [[ -z "$h" ]] && return 0
  safe=$(printf '%s' "$h" | tr -c 'a-zA-Z0-9._-' '_')

  if command -v whatweb >/dev/null 2>&1; then
    whatweb -U "$(pick_ua)" -a 1 --color=never --no-errors --log-brief="$OUTDIR/tech_tmp/${safe}_ww.txt" "https://$h" >/dev/null 2>&1 ||
      whatweb -U "$(pick_ua)" -a 1 --color=never --no-errors --log-brief="$OUTDIR/tech_tmp/${safe}_ww.txt" "http://$h" >/dev/null 2>&1 || true
  fi

  hdrs=$(curl -skI -L --max-redirs 2 --max-time 5 -A "$(pick_ua)" "https://$h" 2>/dev/null ||
         curl -sI -L --max-redirs 2 --max-time 5 -A "$(pick_ua)" "http://$h" 2>/dev/null || true)

  if [[ -n "$hdrs" ]]; then
    srv=$(printf '%s\n' "$hdrs" | tr -d '\r' | grep -i '^server:' | tail -1 | cut -d: -f2- | sed 's/^ *//')
    pow=$(printf '%s\n' "$hdrs" | tr -d '\r' | grep -iE '^(x-powered-by|x-generator|x-aspnet-version):' | tr '\n' ' ' | sed 's/^ *//')
    printf '%s\n' "$hdrs" | grep -qi '^cf-ray:' && waf="Cloudflare"
    printf '%s\n' "$hdrs" | grep -qi '^x-amz-cf-id:' && waf="${waf:+$waf, }AWS CloudFront"
    printf '%s\n' "$hdrs" | grep -qi '^x-vercel-id:' && waf="${waf:+$waf, }Vercel"
    printf '%s\n' "$hdrs" | grep -qi '^x-fastly-request-id:' && waf="${waf:+$waf, }Fastly"
    printf '%s\n' "$hdrs" | grep -qi '^strict-transport-security:' || missing_sec+=("HSTS")
    printf '%s\n' "$hdrs" | grep -qi '^content-security-policy:' || missing_sec+=("CSP")
    printf '%s\n' "$hdrs" | grep -qi '^x-frame-options:' || missing_sec+=("X-Frame-Options")
    printf '%s\n' "$hdrs" | grep -qi '^x-content-type-options:' || missing_sec+=("X-Content-Type-Options")

    local summary_parts=()
    [[ -n "$srv" ]] && summary_parts+=("Server/${srv}")
    [[ -n "$pow" ]] && summary_parts+=("${pow}")
    [[ -n "$waf" ]] && summary_parts+=("WAF-CDN/${waf}")
    if (( ${#missing_sec[@]} > 0 )); then
      local ms
      ms=$(IFS=','; printf '%s' "${missing_sec[*]}")
      summary_parts+=("MissingSecHeaders[${ms}]")
      printf '[sec-headers-missing] [http] [low] https://%s [Missing: %s]\n' "$h" "$ms" >> "$OUTDIR/tech_tmp/${safe}_sec.txt"
    fi
    if (( ${#summary_parts[@]} > 0 )); then
      printf '%s: %s\n' "$h" "${summary_parts[*]}" >> "$OUTDIR/tech_tmp/${safe}_hdr.txt"
    fi
  fi
}

# Phase 3: Tech Fingerprinting & Security Header Audit
ph_tech() {
  if [[ "$DRY_ON" == "1" ]]; then
    log "Tech Stack & Security Header Audit (whatweb + HTTP header analyzer · ${G}${CONC}${NC} workers)"
    dry "whatweb -a 1 + HTTP security header & WAF/CDN fingerprint < ${OUTDIR}/live_hosts.txt"
    return 0
  fi
  if [[ ! -s "$OUTDIR/live_hosts.txt" ]]; then
    warn "Tidak ada host aktif — melewati fase Tech Fingerprint."
    return 0
  fi
  log "Tech Stack & Security Header Audit (whatweb + HTTP header analyzer · ${G}${CONC}${NC} workers)"
  mkdir -p "$OUTDIR/tech_tmp"
  export -f tech_inspect_one pick_ua
  export OUTDIR UAS
  # shellcheck disable=SC2016
  xargs -P "$CONC" -I{} bash -c 'tech_inspect_one "$1"' _ {} < "$OUTDIR/live_hosts.txt" || true
  cat "$OUTDIR"/tech_tmp/*_ww.txt "$OUTDIR"/tech_tmp/*_hdr.txt 2>/dev/null | sed '/^[[:space:]]*$/d' | sort -u > "$OUTDIR/tech.txt" || true
  cat "$OUTDIR"/tech_tmp/*_sec.txt 2>/dev/null | sort -u > "$OUTDIR/surface_findings.txt" || true
  rm -rf "$OUTDIR/tech_tmp"
}

# Passive CVE Banner & High-Risk Exposure Surface Verification
surface_cve_audit_one() {
  local url=$1 ua body hdr srv
  url=$(printf '%s' "$url" | tr -d '\r[:space:]')
  [[ -z "$url" ]] && return 0
  ua=$(pick_ua)

  hdr=$(curl -skI --max-time 5 -A "$ua" "$url" 2>/dev/null | tr -d '\r' || true)
  srv=$(printf '%s\n' "$hdr" | grep -i '^server:' | head -1 | cut -d: -f2- | sed 's/^ *//')

  # Passive Banner Version -> High-Impact CVE / CISA KEV Correlation
  if [[ -n "$srv" ]]; then
    if [[ "$srv" =~ Apache/2\.4\.(49|50)([^0-9]|$) ]]; then
      printf '[CVE-2021-41773] [http] [critical] %s [Apache Path Traversal & RCE - CISA KEV (%s)]\n' "$url" "$srv"
    fi
    if [[ "$srv" =~ Apache/2\.4\.([1-9]|[1-5][0-9]|6[01])([^0-9]|$) ]]; then
      printf '[CVE-2024-38476] [http] [high] %s [Apache HTTP Server Backend Output Handling (%s)]\n' "$url" "$srv"
    fi
    if [[ "$srv" =~ nginx/1\.(1[0-9]|2[0-4])\. ]]; then
      printf '[CVE-2024-7347] [http] [medium] %s [Outdated Nginx Branch - HTTP/3 & mp4 Module Advisories (%s)]\n' "$url" "$srv"
    fi
  fi
  if printf '%s\n' "$hdr" | grep -qiE '^x-powered-by: *Next\.js'; then
    printf '[CVE-2025-29927-check] [http] [info] %s [Next.js Detected - Verify Middleware Subrequest Header Patch >=14.2.25/15.2.3]\n' "$url"
  fi

  # Verified Exposure Checks (Strict Signature Matching to Prevent False Positives)
  body=$(curl -sk --max-time 4 -A "$ua" "${url%/}/.git/HEAD" 2>/dev/null | head -c 200 || true)
  if [[ "$body" =~ ^ref:\ refs/heads/ ]]; then
    printf '[exposed-git-head] [http] [high] %s/.git/HEAD [Git Repository Metadata Exposed]\n' "${url%/}"
  fi

  body=$(curl -sk --max-time 4 -A "$ua" "${url%/}/.env" 2>/dev/null | head -c 500 || true)
  if printf '%s' "$body" | grep -qE '^(APP_KEY|DB_PASSWORD|AWS_SECRET_ACCESS_KEY|SECRET_KEY)='; then
    printf '[exposed-dotenv] [http] [critical] %s/.env [Environment Secrets Exposed]\n' "${url%/}"
  fi
}

# Phase 4: Vulnerability & CVE Scanning (Nuclei v3 + Built-in CVE/Surface Audit)
ph_nuclei() {
  local focus_mode=${1:-standard}
  local nuc_tags="cve,kev,misconfig,exposure,takeover,panel,default-login"
  local nuc_sev="low,medium,high,critical"
  if [[ "$focus_mode" == "cve_focus" ]]; then
    nuc_tags="cve,kev,exposure"
    nuc_sev="medium,high,critical"
  fi

  log "CVE & Vulnerability Audit [tags: ${CYN}${nuc_tags}${NC} · rate: ${G}${NUC_RL}/s${NC}]"
  if [[ "$DRY_ON" == "1" ]]; then
    dry "nuclei -l ${OUTDIR}/nuc_targets.txt -tags ${nuc_tags} -s ${nuc_sev} -rl ${NUC_RL} -c ${CONC} -bs 25 -nc -silent -o ${OUTDIR}/vulns.txt"
    return 0
  fi

  {
    awk '$3 != "-" {print $3}' "$OUTDIR/live_http.txt" 2>/dev/null
    awk '$3 == "-" && NF >= 2 {print "https://" $2}' "$OUTDIR/live_http.txt" 2>/dev/null
    sed 's|^|https://|' "$OUTDIR/subs.txt" 2>/dev/null
  } | tr -d '\r' | sed '/^[[:space:]]*$/d' | sort -u > "$OUTDIR/nuc_targets.txt"

  if [[ ! -s "$OUTDIR/nuc_targets.txt" ]]; then
    warn "Tidak ada target untuk pemindaian CVE."
    return 0
  fi

  : > "$OUTDIR/vulns.raw"

  if have nuclei; then
    local ua
    ua=$(pick_ua)
    nuclei -l "$OUTDIR/nuc_targets.txt" \
      -tags "$nuc_tags" \
      -s "$nuc_sev" \
      -rl "$NUC_RL" -c "$CONC" -bs 25 -timeout 8 -retries "$RETRY" \
      -nc -silent \
      -H "User-Agent: $ua" \
      -o "$OUTDIR/vulns.nuclei" >/dev/null 2>&1 || true
    cat "$OUTDIR/vulns.nuclei" >> "$OUTDIR/vulns.raw" 2>/dev/null || true
    rm -f "$OUTDIR/vulns.nuclei"
  fi

  export -f surface_cve_audit_one pick_ua
  export UAS
  # shellcheck disable=SC2016
  head -n 50 "$OUTDIR/nuc_targets.txt" | xargs -P "$CONC" -I{} bash -c 'surface_cve_audit_one "$1"' _ {} >> "$OUTDIR/vulns.raw" 2>/dev/null || true

  if [[ -s "$OUTDIR/ports_detail.txt" ]] && grep -qiE 'OpenSSH_(8\.[5-9]|9\.[0-7])[^0-9]' "$OUTDIR/ports_detail.txt"; then
    printf '[CVE-2024-6387] [ssh] [high] %s:22 [OpenSSH regreSSHion Unauthenticated Race Condition RCE Banner Match]\n' "$DOMAIN" >> "$OUTDIR/vulns.raw"
  fi

  if [[ -s "$OUTDIR/surface_findings.txt" && "$focus_mode" != "cve_focus" ]]; then
    cat "$OUTDIR/surface_findings.txt" >> "$OUTDIR/vulns.raw" 2>/dev/null || true
  fi

  sed '/^[[:space:]]*$/d' "$OUTDIR/vulns.raw" | sort -u > "$OUTDIR/vulns.txt"
  rm -f "$OUTDIR/vulns.raw"
}

# ---------------- RESULT PARSERS & REPORT DISPLAY ----------------
show_result_ports() {
  banner
  row "PORT / PROTOCOL / SERVICE" "STATUS & VERSION"
  sep
  if grep -q "Ports:" "$OUTDIR/ports.txt" 2>/dev/null; then
    grep "Ports:" "$OUTDIR/ports.txt" | sed 's/.*Ports: //; s/, /\n/g' | while IFS= read -r entry; do
      local port stat proto serv ver
      port=$(printf '%s' "$entry" | awk -F'/' '{print $1}')
      stat=$(printf '%s' "$entry" | awk -F'/' '{print $2}')
      proto=$(printf '%s' "$entry" | awk -F'/' '{print $3}')
      serv=$(printf '%s' "$entry" | awk -F'/' '{print $5}')
      ver=$(printf '%s' "$entry" | awk -F'/' '{print $7}')
      if [[ -n "$port" ]]; then
        row "${port}/${proto:-tcp} (${serv:-unknown})" "${stat:-open}${ver:+ - $ver}"
      fi
    done
  else
    row "No Open Ports Detected" "Filtered / Host Down"
  fi
  sep
}

show_result_subs() {
  banner
  row "SUBDOMAIN / HOSTNAME" "DISCOVERY STATUS"
  sep
  if [[ -s "$OUTDIR/subs.txt" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      row "$line" "Resolved / CT Indexed"
    done < "$OUTDIR/subs.txt"
  else
    row "No Subdomains Found" "N/A"
  fi
  sep
}

show_result_tech() {
  banner
  row "HOST / TECHNOLOGY" "FINGERPRINT & HEADERS"
  sep
  if [[ -s "$OUTDIR/tech.txt" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local key val
      if [[ "$line" == *:* ]]; then
        key=${line%%:*}
        val=${line#*:}
        val=${val# }
      else
        key=$(printf '%s' "$line" | awk '{print $1}')
        val=$(printf '%s' "$line" | cut -d' ' -f2-)
      fi
      [[ -n "$val" ]] && row "$key" "$val"
    done < "$OUTDIR/tech.txt"
  else
    row "Fingerprint Unknown" "No HTTP Banner / Tech Detected"
  fi
  sep
}

# Parse both Nuclei v3 format `[id] [proto] [severity] target [info]` and legacy 2-bracket lines
parse_vuln_line() {
  local line=$1 tid="" proto="" sev="" rest=""
  line="${line//$'\033'\[*([0-9;:?])[@-~]/}"
  if [[ "$line" =~ ^\[([^]]+)\][[:space:]]*\[([^]]+)\][[:space:]]*\[([^]]+)\][[:space:]]*(.*)$ ]]; then
    tid="${BASH_REMATCH[1]}"
    proto="${BASH_REMATCH[2]}"
    sev="${BASH_REMATCH[3]^^}"
    rest="${BASH_REMATCH[4]}"
  elif [[ "$line" =~ ^\[([^]]+)\][[:space:]]*\[([^]]+)\][[:space:]]*(.*)$ ]]; then
    tid="${BASH_REMATCH[1]}"
    sev="${BASH_REMATCH[2]^^}"
    rest="${BASH_REMATCH[3]}"
  else
    tid="finding"
    sev="INFO"
    rest="$line"
  fi
  printf '%s|%s|%s\n' "$sev" "$tid" "${proto:+$proto - }${rest}"
}

show_result_vulns() {
  banner
  row "SEVERITY & TEMPLATE / CVE" "TARGET & REMARK"
  sep
  if [[ -s "$OUTDIR/vulns.txt" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local parsed sev tid detail
      parsed=$(parse_vuln_line "$line")
      IFS='|' read -r sev tid detail <<< "$parsed"
      row "[${sev}] ${tid}" "$detail"
    done < "$OUTDIR/vulns.txt"
  else
    row "CLEAN" "No Medium/High/Critical CVEs Found"
  fi
  sep
}

summarize() {
  local subs live ports tech vulns crit high med low ts
  subs=$(count_lines "$OUTDIR/subs.txt")
  live=$(count_lines "$OUTDIR/live_hosts.txt")
  ports=$(count_open_ports "$OUTDIR/ports.txt")
  tech=$(count_lines "$OUTDIR/tech.txt")
  vulns=$(count_lines "$OUTDIR/vulns.txt")
  crit=$(count_pattern '\[critical\]' "$OUTDIR/vulns.txt")
  high=$(count_pattern '\[high\]' "$OUTDIR/vulns.txt")
  med=$(count_pattern '\[medium\]' "$OUTDIR/vulns.txt")
  low=$(count_pattern '\[(low|info)\]' "$OUTDIR/vulns.txt")
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  cat > "$OUTDIR/report.json" <<EOF
{
  "framework": "$FRAMEWORK_NAME",
  "tool": "$APP_NAME ($APP_FULL_NAME)",
  "version": "$VERSION",
  "target": "$DOMAIN",
  "speed": "$SPEED_LBL (L$SPEED_LVL)",
  "subdomains": $subs,
  "live_hosts": $live,
  "open_ports": $ports,
  "tech_found": $tech,
  "vulns_found": $vulns,
  "severity_breakdown": {
    "critical": $crit,
    "high": $high,
    "medium": $med,
    "low_info": $low
  },
  "timestamp": "$ts"
}
EOF

  cat > "$OUTDIR/report.md" <<EOF
# Minstrel Recon (Minstrel Reconnaisance) — Executive Report

- **Framework:** \`$FRAMEWORK_NAME\`
- **Module:** \`$APP_NAME v$VERSION\`
- **Target:** \`$DOMAIN\`
- **Speed Profile:** \`$SPEED_LBL (Level $SPEED_LVL)\`
- **Timestamp (UTC):** \`$ts\`
- **Subdomains Discovered:** \`$subs\`
- **Live HTTP/S Hosts:** \`$live\`
- **Open TCP Ports:** \`$ports\`
- **Tech Stack & Header Entries:** \`$tech\`
- **CVE & Security Findings:** \`$vulns\` (Critical: $crit, High: $high, Medium: $med, Low/Info: $low)
EOF

  banner
  row "MINSTREL RECON SUMMARY" "METRICS & DETAILS"
  sep
  row "Target Host" "$DOMAIN"
  row "Speed Profile" "$SPEED_LBL (Level $SPEED_LVL)"
  row "Subdomains Indexed" "$subs Discovered"
  row "Live HTTP/S Hosts" "$live Active"
  row "Open TCP Ports" "$ports Detected"
  row "Tech & Header Fingerprints" "$tech Recorded"
  row "CVE & Security Findings" "$vulns Total (C:$crit H:$high M:$med)"
  row "JSON & Markdown Report" "$OUTDIR/report.json"
  sep
  printf '  %s» RECONNAISSANCE ACCOMPLISHED. [ MINSTREL RECON v%s ]%s\n' "$LG" "$VERSION" "$NC"
}

# ---------------- PIPELINE RUNNER ----------------
run_mode() {
  local mode=$1
  case "$mode" in
    1)
      ph_ports
      phase_spin "Phase 1 · Port & Service Discovery" "${JOBS[@]}"
      wait_jobs
      show_result_ports
      ;;
    2)
      ph_subs
      phase_spin "Phase 1 · Subdomain & CT Enumeration" "${JOBS[@]}"
      wait_jobs
      show_result_subs
      ;;
    3)
      printf '%s\n' "$DOMAIN" > "$OUTDIR/subs.txt"
      ph_probe
      ph_tech
      show_result_tech
      ;;
    4)
      printf '%s\n' "$DOMAIN" > "$OUTDIR/subs.txt"
      ph_probe
      ph_nuclei "standard"
      show_result_vulns
      ;;
    5)
      ph_subs
      ph_ports
      phase_spin "Phase 1 · Parallel Enumeration (Subdomains + CT + TCP Ports)" "${JOBS[@]}"
      wait_jobs
      ph_probe
      ph_tech
      ph_nuclei "standard"
      summarize
      ;;
    6)
      printf '%s\n' "$DOMAIN" > "$OUTDIR/subs.txt"
      ph_probe
      ph_nuclei "cve_focus"
      summarize
      ;;
  esac
}

run_recon() {
  local raw_mode=$1 target=$2 speed=${3:-3} mode
  mode=$(parse_mode "$raw_mode")
  parse_target "$target"
  load_profile "$speed"
  OUTDIR="minstrel_recon_${DOMAIN}"
  mkdir -p "$OUTDIR"
  log "Target: ${W}${DOMAIN}${NC} │ Profile: ${G}${SPEED_LBL}${NC} (${SPEED_LVL}) │ Mode: ${CYN}${MODE_META[$mode]}${NC}"
  check_deps "$mode"
  run_mode "$mode"
}

# ---------------- INTERACTIVE WIZARD & WORKSPACE VIEWS ----------------
summary_panel() {
  local m=$1 s=$2 t=$3
  load_profile "$s"
  PRT=70
  pbox_top "${LG}RINGKASAN KONFIGURASI — MINSTREL RECON${NC}" 74 >&2
  prow "" >&2
  prow "  ${DGN}Mode Operasi${NC}     ${W}${m}${NC}" >&2
  prow "  ${DGN}Profil Kecepatan${NC} ${W}${SPEED_LBL} (Level ${SPEED_LVL})${NC}" >&2
  prow "  ${DGN}Parameter Engine${NC} ${GRAY}Threads: ${SUB_T} · Concurrency: ${CONC} · Rate: ${NUC_RL}/s${NC}" >&2
  prow "  ${DGN}Target Sasaran${NC}   ${LG}${t}${NC}" >&2
  prow "  ${DGN}Workspace Output${NC} ${GRAY}minstrel_recon_${t}/${NC}" >&2
  prow "" >&2
  pbox_bottom 74 >&2
}

wizard_recon() {
  banner
  local m s tgt mm
  MENU_DESC=(
    "Scan port TCP (-sS/-sT), deteksi versi & NSE script banner/SSL"
    "Enumerasi subdomain pasif via Subfinder (-all) & crt.sh CT log"
    "Multi-scheme HTTP/S probe, WhatWeb & audit Security Headers"
    "Scan CVE, CISA KEV, misconfig & exposed secrets via Nuclei v3"
    "Otomasi penuh: Subs+Ports -> HTTP Probe -> Tech -> CVE -> Report"
    "Fokus khusus kerentanan CVE kritis/tinggi & katalog CISA KEV"
    "Kembali ke menu utama Minstrel Recon"
  )
  m=$(menu_pick "PILIH MODE OPERASI — MINSTREL RECON" \
    "Port & Service Discovery" \
    "Subdomain & CT Enumeration" \
    "Tech & Security Header Audit" \
    "CVE & Vulnerability Scan" \
    "Auto-Pipeline (Full Suite)" \
    "Critical CVE & CISA KEV Focus" \
    "← Kembali") || return 1
  case "$m" in
    7) return 1 ;;
    1|2|3|4|5|6) mm="${MODE_META[$m]}" ;;
    *) return 1 ;;
  esac

  banner
  MENU_DESC=(
    "Sangat lambat & senyap (-T1, max-rate 10, 5 rps) — IDS evasion"
    "Mode hati-hati (-T2, max-rate 30, 15 rps) — jaringan sensitif"
    "Seimbang kecepatan & akurasi (-T4, max-rate 150, 50 rps)"
    "Eksekusi cepat (-T4, min-rate 400, 120 rps, 60 workers)"
    "Kecepatan maksimum (-T5, min-rate 1000, 250 rps, 100 workers)"
    "Batal dan kembali ke menu utama"
  )
  s=$(menu_pick "PILIH PROFIL KECEPATAN" \
    "I   · Paranoid   (Stealth Maksimum · IDS Evasion)" \
    "II  · Stealth    (Low Noise · Rate Terbatas)" \
    "III · Normal     (Balanced · Rekomendasi Standar)" \
    "IV  · Aggressive (High Concurrency · Cepat)" \
    "V   · Insane     (Maximum Throughput)" \
    "← Kembali") || return 1
  case "$s" in
    6) return 1 ;;
    1|2|3|4|5) ;;
    *) return 1 ;;
  esac

  banner
  tgt=$(input_target) || return 1

  banner
  summary_panel "$mm" "$s" "$tgt"
  if confirm_yn "Mulai eksekusi Minstrel Recon sekarang"; then
    run_recon "$m" "$tgt" "$s"
    press_enter
  fi
  return 0
}

# Interactive Report Browser
view_reports() {
  banner
  local dirs=() d
  while IFS= read -r d; do
    [[ -n "$d" ]] && dirs+=("$d")
  done < <(ls -dt minstrel_recon_* 2>/dev/null || true)

  if (( ${#dirs[@]} == 0 )); then
    warn "Belum ada direktori laporan hasil recon (minstrel_recon_<target>/)."
    press_enter
    return 0
  fi

  local latest="${dirs[0]}"
  OUTDIR="$latest"
  DOMAIN="${latest#minstrel_recon_}"

  while true; do
    banner
    PRT=70
    pbox_top "${LG}LAPORAN AKTIF: ${W}${latest:0:45}${NC}" 74 >&2
    if [[ -f "$latest/report.json" ]]; then
      while IFS= read -r jline; do
        prow "  ${GRAY}${jline:0:66}${NC}" >&2
      done < "$latest/report.json"
    else
      prow "  ${GRAY}Direktori artefak ditemukan tanpa report.json ringkasan.${NC}" >&2
    fi
    pbox_bottom 74 >&2
    printf '\n' >&2

    if ! is_tty; then
      [[ -f "$latest/report.json" ]] && cat "$latest/report.json"
      return 0
    fi

    MENU_DESC=(
      "Lihat tabel port terbuka, protokol, dan banner layanan"
      "Lihat daftar subdomain hasil enumerasi pasif & CT log"
      "Lihat fingerprinting teknologi, WAF/CDN & Security Headers"
      "Lihat daftar temuan CVE, CISA KEV & tingkat keparahannya"
      "Kembali ke menu utama"
    )
    local sub_c
    sub_c=$(menu_pick "INSPEKSI DETAIL LAPORAN — MINSTREL RECON" \
      "Lihat Tabel Open Ports & Services" \
      "Lihat Daftar Subdomains & Live Hosts" \
      "Lihat Tech Stack & Security Headers" \
      "Lihat Temuan CVE & Vulnerabilities" \
      "← Kembali ke Menu Utama") || return 0

    case "$sub_c" in
      1) show_result_ports; press_enter ;;
      2) show_result_subs; press_enter ;;
      3) show_result_tech; press_enter ;;
      4) show_result_vulns; press_enter ;;
      5|*) return 0 ;;
    esac
  done
}

# Engine Diagnostics & CVE Template Updater View
view_engine_health() {
  banner
  PRT=70
  pbox_top "${LG}DIAGNOSTIK ENGINE & DATABASE CVE${NC}" 74 >&2
  prow "" >&2
  local t ver st
  for t in nmap subfinder whatweb nuclei curl jq; do
    if have "$t"; then
      ver=$("$t" --version 2>&1 | head -1 | tr -d '\r' | cut -c1-38 || true)
      [[ -z "$ver" ]] && ver=$("$t" -version 2>&1 | head -1 | tr -d '\r' | cut -c1-38 || true)
      st="${LG}READY${NC}  ${MUTED}(${ver:-installed})${NC}"
    else
      st="${Y}FALLBACK${NC} ${MUTED}(menggunakan engine internal)${NC}"
    fi
    prow "$(printf '  %-14s : %s' "${W}${t}${NC}" "$st")" >&2
  done
  prow "" >&2
  prow "  ${CYN}Mode Eksekusi Port:${NC} $( (( EUID == 0 )) && printf '%sRoot SYN Stealth (-sS)%s' "$LG" "$NC" || printf '%sUnprivileged TCP Connect (-sT)%s' "$GRN" "$NC" )" >&2
  prow "" >&2
  pbox_bottom 74 >&2

  if is_tty; then
    printf '\n' >&2
    MENU_DESC=(
      "Instal otomatis dependensi (nmap, whatweb, subfinder, nuclei)"
      "Perbarui repositori template CVE terbaru (nuclei -ut)"
      "Kembali ke menu utama"
    )
    local hc
    hc=$(menu_pick "TINDAKAN PEMELIHARAAN ENGINE" \
      "Install / Lengkapi Semua Dependensi Recon" \
      "Update Nuclei CVE Templates Terkini (-ut)" \
      "← Kembali") || return 0
    case "$hc" in
      1)
        check_deps 5
        press_enter
        ;;
      2)
        if have nuclei; then
          log "Menjalankan: nuclei -update-templates …"
          nuclei -ut || true
        else
          warn "Nuclei belum terinstal. Pilih opsi 1 terlebih dahulu."
        fi
        press_enter
        ;;
      *) return 0 ;;
    esac
  fi
}

view_info() {
  banner
  PRT=70
  pbox_top "${LG}DOKUMENTASI & METODOLOGI — MINSTREL RECON${NC}" 74 >&2
  prow "" >&2
  prow "  ${W}Minstrel Recon v${VERSION}${NC} ${GRAY}(Minstrel Reconnaisance · Minstrel)${NC}" >&2
  prow "  ${GRAY}Otomasi Surface Reconnaissance & Audit Kerentanan CVE Terkini${NC}" >&2
  prow "" >&2
  prow "  ${GRN}1. Port & Service${NC}  ${GRAY}Nmap (-sS/-sT adaptif, -sV banner, NSE ssl)${NC}" >&2
  prow "  ${GRN}2. Subdomains & CT${NC} ${GRAY}Subfinder v2 (-all) + crt.sh CT log OSINT${NC}" >&2
  prow "  ${GRN}3. HTTP & Tech${NC}     ${GRAY}HTTPS/HTTP probe + WhatWeb + Sec-Headers${NC}" >&2
  prow "  ${GRN}4. CVE & KEV Scan${NC}  ${GRAY}Nuclei v3 (-tags cve,kev,exposure) + Audit${NC}" >&2
  prow "" >&2
  pbox_div 74 >&2
  prow "  ${CYN}CLI Mode:${NC}  ${W}minstrel-recon -i <target> -t <I-VI> [-s <I-V>]${NC}" >&2
  prow "  ${CYN}Env Vars:${NC}  ${GRAY}MINSTREL_RECON_DRY=1 · MINSTREL_RECON_QUIET=1${NC}" >&2
  prow "  ${CYN}Output:${NC}    ${GRAY}minstrel_recon_<target>/report.json & report.md${NC}" >&2
  prow "" >&2
  pbox_bottom 74 >&2
  press_enter
}

# ---------------- MAIN INTERACTIVE WORKSPACE LOOP ----------------
app_loop() {
  while true; do
    banner
    MENU_DESC=(
      "Wizard interaktif: pilih mode recon, kecepatan & target sasaran"
      "Inspeksi laporan hasil scan terakhir (Ports, Subs, Tech & CVE)"
      "Cek status engine recon, instal dependensi & update CVE Nuclei"
      "Lihat dokumentasi arsitektur, teknik CVE, CLI & variabel env"
      "Tutup antarmuka Minstrel Recon dan kembali ke terminal"
    )
    local c
    c=$(menu_pick "MENU UTAMA — MINSTREL RECON" \
      "Jalankan Recon (Wizard Interaktif)" \
      "Lihat Hasil & Laporan Terakhir" \
      "Diagnostik Engine & Update CVE" \
      "Info, Dokumentasi & Metodologi" \
      "Keluar") || c=5

    case "$c" in
      1) wizard_recon || true ;;
      2) view_reports ;;
      3) view_engine_health ;;
      4) view_info ;;
      ""|5|*)
        leave_tui
        printf '  %s✓%s %sSampai jumpa! [ MINSTREL RECON v%s ]%s\n' "$LG" "$NC" "$W" "$VERSION" "$NC"
        exit 0
        ;;
    esac
  done
}

usage_cli() {
  banner
  PRT=70
  pbox_top "${LG}PENGGUNAAN CLI — MINSTREL RECON${NC}" 74
  prow ""
  prow "  ${W}Interaktif (TUI):${NC}  ${LG}minstrel-recon${NC}"
  prow "  ${W}Mode CLI:${NC}          ${LG}minstrel-recon -i <target> -t <I-VI> [-s <I-V>]${NC}"
  prow ""
  prow "  ${DGN}-i <target>${NC}  ${GRAY}Domain (example.com) atau IPv4 (203.0.113.10)${NC}"
  prow "  ${DGN}-t <mode>${NC}    ${GRAY}I:Ports II:Subs III:Tech IV:Vulns V:Auto VI:CVE-KEV${NC}"
  prow "  ${DGN}-s <speed>${NC}   ${GRAY}I:Paranoid II:Stealth III:Normal IV:Aggressive V:Insane${NC}"
  prow "  ${DGN}-u${NC}           ${GRAY}Auto-update Nuclei CVE templates sebelum scan${NC}"
  prow ""
  pbox_bottom 74
}

# ---------------- CLEANUP & ENTRYPOINT ----------------
cleanup() {
  local j
  for j in "${JOBS[@]:-}"; do kill "$j" 2>/dev/null || true; done
  leave_tui
}
trap cleanup EXIT INT TERM

if (( $# > 0 )); then
  # ---------------- CLI MODE (Backward Compatible) ----------------
  while getopts "i:t:s:uhv" opt; do
    case "$opt" in
      i) RAW_TARGET=$OPTARG ;;
      t) TOOL_OP=$OPTARG ;;
      s) SPEED_OP=$OPTARG ;;
      u) AUTO_UPDATE_TEMPLATES=1 ;;
      v) printf 'Minstrel Recon (Minstrel Reconnaisance) v%s\n' "$VERSION"; exit 0 ;;
      h) usage_cli; exit 0 ;;
      *) usage_cli >&2; exit 1 ;;
    esac
  done
  if [[ -z "${RAW_TARGET:-}" || -z "${TOOL_OP:-}" ]]; then
    usage_cli >&2
    exit 1
  fi
  run_recon "$TOOL_OP" "$RAW_TARGET" "${SPEED_OP:-3}"
else
  # ---------------- DEDICATED INTERACTIVE TUI MODE ----------------
  enter_tui
  app_loop
fi
