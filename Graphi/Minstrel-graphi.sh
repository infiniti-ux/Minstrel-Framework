#!/usr/bin/env bash
set -uo pipefail
shopt -s extglob
export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=C

# ============================================================================ #
#  MINSTREL GRAPHI v2.1.0 — Auto-Cryptanalysis & Linux GPU Acceleration Suite  #
#  Part of the Minstrel Penetration Testing Framework                          #
#  Auto-Scan · 5 Crypto Categories · 30+ Sub-Engines · CUDA/ROCm/OpenCL GPU    #
# ============================================================================ #

readonly VERSION="2.1.0"
readonly APP_NAME="Minstrel Graphi"
readonly BIN_NAME="minstrel-graphi"
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

# ---------------- ASCII BANNER (MINSTREL GRAPHI) ----------------
readonly -a ART=(
  "░█▄█░▀█▀░█▀█░█▀▀░▀█▀░█▀▄░█▀▀░█░░░░░█▀▀░█▀▄░█▀█░█▀█░█░█░▀█▀"
  "░█░█░░█░░█░█░▀▀█░░█░░█▀▄░█▀▀░█░░░░░█░█░█▀▄░█▀█░█▀▀░█▀█░░█░"
  "░▀░▀░▀▀▀░▀░▀░▀▀▀░░▀░░▀░▀░▀▀▀░▀▀▀░░░▀▀▀░▀░▀░▀░▀░▀░░░▀░▀░▀▀▀"
)
readonly -a ART_C=(
  $'\033[38;5;28m'
  $'\033[38;5;40m'
  $'\033[38;5;46m'
)

# ---------------- STATE VARIABLES ----------------
TARGET_FILE=""
OUTDIR=""
CUSTOM_WORDLIST=""
WORDLIST=""
TMP_WORDLIST=""
CIPHER_HINT="auto"

GPU_VENDOR="NONE"
GPU_MODEL="CPU Multi-Core Fallback"
GPU_DRIVER="POSIX SMP Threads"
GPU_BACKEND="CPU-PARALLEL"
GPU_ACTIVE=0
GPU_WORKLOAD=3   # Hashcat -w 3 (High Performance) default
CPU_CORES=4

QUIET_ON="${MINSTREL_GRAPHI_QUIET:-0}"
DRY_ON="${MINSTREL_GRAPHI_DRY:-0}"
CLI_OUTDIR=""
MENU_DESC=()

# Unified 72-column layout (PRT=70 interior + 2 border chars = 72 visible cols)
PRT=70
readonly TOUT_DEFAULT=74

TUI_ACTIVE=0
ORIG_STTY=""

readonly -a BUILTIN_PASSWORDS=(
  "admin" "password" "123456" "12345678" "123456789" "12345" "qwerty" "secret"
  "minstrel" "flag" "ctf" "root" "toor" "letmein" "welcome" "dragon" "monkey"
  "shadow" "master" "superman" "batman" "passw0rd" "Password1" "Password123"
  "admin123" "root123" "secret123" "minstrel123" "p@ssw0rd" "qwerty123" "iloveyou"
  "sunshine" "princess" "charlie" "hunter" "matrix" "cyberpunk" "crypto" "enigma"
  "caesar" "vigenere" "rsa" "aes256" "opensesame" "indonesia" "merdeka" "rahasia"
  "sidoarjo" "surabaya" "jakarta" "kali" "kalilinux" "ubuntu" "debian" "anonymous"
  "hackthebox" "tryhackme" "picoctf"
)

# ---------------- TERMINAL & TUI LIFECYCLE ----------------
have() { command -v "$1" &>/dev/null; }
is_tty() { [[ -t 0 && -t 2 ]]; }

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

# 72-column separator and aligned table rows (strictly single-byte ASCII inside printf widths)
sep() { printf '  %s%s%s\n' "$DG" "${HLINE_BUF:0:72}" "$NC"; }
row() {
  local c1=${1:-} c2=${2:-}
  printf '  %s┃%s %-26.26s %s┃%s %-39.39s %s┃%s\n' "$DG" "$NC" "$c1" "$DG" "$NC" "$c2" "$DG" "$NC"
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
    pbox_top "${LG}NAVIGASI WORKSPACE — MINSTREL GRAPHI${NC}" 74 >&2
    prow "  ${LG}▶${NC} ${W}Tekan [ENTER] atau [SPACE] untuk kembali ke menu${NC}" >&2
    pbox_bottom 74 >&2
    local k=""
    while IFS= read -rs -n 1 k; do
      case "$k" in
        ""|" "|$'\r'|$'\n'|q|Q) break ;;
      esac
    done
  fi
}

# ---------------- LINUX GPU DRIVER & HARDWARE ACCELERATION DETECTOR ----------------
detect_linux_gpu() {
  CPU_CORES=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
  if (( GPU_WORKLOAD == 0 )); then
    GPU_VENDOR="CPU-ONLY"
    GPU_MODEL="CPU Multi-Core (${CPU_CORES} Threads)"
    GPU_DRIVER="Forced CPU Parallel Mode"
    GPU_BACKEND="CPU-SMP (${CPU_CORES}c)"
    GPU_ACTIVE=0
    return 0
  fi

  # 1. Check NVIDIA CUDA / NVML via nvidia-smi
  if have nvidia-smi; then
    local nv_info
    nv_info=$(nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || true)
    if [[ -n "$nv_info" ]]; then
      IFS=',' read -r g_name g_drv g_mem <<< "$nv_info"
      g_name="${g_name#"${g_name%%[![:space:]]*}"}"
      g_drv="${g_drv#"${g_drv%%[![:space:]]*}"}"
      g_mem="${g_mem#"${g_mem%%[![:space:]]*}"}"
      GPU_VENDOR="NVIDIA"
      GPU_MODEL="${g_name:0:32} (${g_mem}MB)"
      GPU_DRIVER="NVIDIA CUDA Driver v${g_drv}"
      GPU_BACKEND="CUDA/OpenCL (-O -w ${GPU_WORKLOAD})"
      GPU_ACTIVE=1
      return 0
    fi
  fi

  # 2. Check AMD ROCm via rocm-smi / rocminfo
  if have rocm-smi || have rocminfo; then
    local amd_name=""
    if have rocminfo; then
      amd_name=$(rocminfo 2>/dev/null | awk -F: '/Marketing Name/{gsub(/^[ \t]+/, "", $2); if($2!~"CPU"){print $2; exit}}' || true)
    fi
    if [[ -n "$amd_name" ]]; then
      GPU_VENDOR="AMD"
      GPU_MODEL="${amd_name:0:36}"
      GPU_DRIVER="AMD ROCm / AMDGPU Kernel Driver"
      GPU_BACKEND="ROCm/HIP (-O -w ${GPU_WORKLOAD})"
      GPU_ACTIVE=1
      return 0
    fi
  fi

  # 3. Check OpenCL ICD via clinfo
  if have clinfo; then
    local cl_dev
    cl_dev=$(clinfo 2>/dev/null | awk -F: '/Device Name/{gsub(/^[ \t]+/, "", $2); print $2; exit}' || true)
    if [[ -n "$cl_dev" ]]; then
      GPU_VENDOR="OPENCL"
      GPU_MODEL="${cl_dev:0:36}"
      GPU_DRIVER="Linux OpenCL ICD Runtime"
      GPU_BACKEND="OpenCL (-O -w ${GPU_WORKLOAD})"
      GPU_ACTIVE=1
      return 0
    fi
  fi

  # 4. Check Linux DRM / PCI sysfs (/dev/dri/renderD* or lspci)
  if [[ -e /dev/dri/renderD128 ]] && have lspci; then
    local pci_vga
    pci_vga=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed -E 's/^[^:]+:[^:]+: //' || true)
    if [[ -n "$pci_vga" && ! "$pci_vga" =~ (VMware|VirtualBox|QXL| Cirrus|bochs|virtio) ]]; then
      GPU_VENDOR="DRM-GPU"
      GPU_MODEL="${pci_vga:0:36}"
      GPU_DRIVER="Linux DRM Render Node (/dev/dri/renderD128)"
      GPU_BACKEND="DRM/OpenCL (-w ${GPU_WORKLOAD})"
      GPU_ACTIVE=1
      return 0
    fi
  fi

  # 5. Fallback: Multi-Core CPU Vectorized / Parallel Engine
  GPU_VENDOR="CPU-SMP"
  GPU_MODEL="CPU Parallel Engine (${CPU_CORES} Cores)"
  GPU_DRIVER="Linux Kernel SMP (No Discrete GPU Found)"
  GPU_BACKEND="CPU-SMP (${CPU_CORES}t)"
  GPU_ACTIVE=0
  return 0
}

tool_status_line() {
  local s="" t
  for t in python3 openssl hashcat john clinfo nvidia-smi; do
    if have "$t"; then
      s+="${LG}●${NC}${GRAY}${t}${NC} "
    else
      s+="${MUTED}○${t}${NC} "
    fi
  done
  printf '%s' "$s"
}

banner() {
  detect_linux_gpu
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
  printf '  %s●%s  %s%-38s%s %sv%s%s  %s·%s  %sAUTO-CRYPTO & GPU%s\n' \
    "$LG" "$NC" "$W" "MINSTREL GRAPHI — CRYPTANALYSIS ENGINE" "$NC" \
    "$LG" "$VERSION" "$NC" "$DGN" "$NC" "$CYN" "$NC"
  sep
  PRT=70
  local f_disp="${TARGET_FILE:-belum dipilih}"
  f_disp="${f_disp##*/}"
  f_disp="${f_disp:0:18}"
  local gpu_badge
  if [[ "$GPU_ACTIVE" -eq 1 ]]; then
    gpu_badge="${LG}GPU: ${GPU_VENDOR} ACTIVE${NC}"
  else
    gpu_badge="${CYN}${GPU_BACKEND}${NC}"
  fi

  pbox_top "${LG}MINSTREL GRAPHI WORKSPACE${NC}" 74
  prow "  ${DGN}File:${NC} ${W}${f_disp}${NC} ${MUTED}│${NC} ${DGN}Accel:${NC} ${gpu_badge} ${MUTED}│${NC} ${DGN}Profile:${NC} ${W}W${GPU_WORKLOAD}${NC}"
  prow "  ${DGN}Core:${NC} $(tool_status_line)"
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

    prow "  ${DGN}Navigasi:${NC} ${GRAY}↑↓ / j k / [1-${n}]${NC}  ${MUTED}·${NC}  ${GRAY}ENTER pilih${NC}  ${MUTED}·${NC}  ${GRAY}q kembali${NC}" >&2
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

# ---------------- FILE PATH INPUT & INTERACTIVE PICKER ----------------
input_file_path() {
  local raw="" err_msg="" L=0 ch line
  PRT=70
  while true; do
    if (( L > 0 )); then printf '\033[%dA\033[J' "$L" >&2; fi
    L=0
    pbox_top "${LG}INPUT LOKASI FILE — MINSTREL GRAPHI${NC}" 74 >&2; L=$((L + 1))
    prow "" >&2; L=$((L + 1))
    prow "  ${W}Masukkan Lokasi File Terenkripsi / Ciphertext / Hash / RSA${NC}" >&2; L=$((L + 1))
    prow "  ${DGN}Contoh:${NC} ${GRAY}./cipher.txt  ·  /tmp/secret.enc  ·  ~/challenge.py${NC}" >&2; L=$((L + 1))
    prow "  ${MUTED}Tips: Ketik '?' untuk memilih file dari direktori saat ini${NC}" >&2; L=$((L + 1))
    prow "" >&2; L=$((L + 1))
    if [[ -n "$err_msg" ]]; then
      prow "  ${R}✗ ${err_msg:0:64}${NC}" >&2; L=$((L + 1))
    fi
    pbox_bottom 74 >&2; L=$((L + 1))

    if is_tty; then
      line=""
      printf '\033[?25h' >&2
      printf '  %s▸ Lokasi File:%s ' "$LG" "$NC" >&2
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
      printf '  %s▸ Lokasi File:%s ' "$LG" "$NC" >&2
      if ! IFS= read -r raw; then return 1; fi
      printf '\033[%dA\033[J' "$L" >&2
      L=0
    fi

    raw="${raw#"${raw%%[![:space:]]*}"}"
    raw="${raw%"${raw##*[![:space:]]}"}"
    raw="${raw#\'}"
    raw="${raw%\'}"
    raw="${raw#\"}"
    raw="${raw%\"}"
    [[ "$raw" == "~/"* ]] && raw="${HOME}/${raw#~/}"

    if [[ "$raw" == "?" ]]; then
      shopt -s nullglob
      local local_files=(*.*)
      shopt -u nullglob
      if (( ${#local_files[@]} == 0 )); then
        err_msg="Tidak ada file di direktori kerja saat ini."
        continue
      fi
      local f_opts=("${local_files[@]:0:12}" "← Ketik Manual")
      local fc
      fc=$(menu_pick "PILIH FILE DARI DIREKTORI SAAT INI" "${f_opts[@]}") || continue
      if (( fc < ${#f_opts[@]} )); then
        raw="${f_opts[$((fc - 1))]}"
      else
        continue
      fi
    fi

    if [[ -z "$raw" ]]; then
      err_msg="Lokasi file tidak boleh kosong."
      continue
    fi
    if [[ ! -f "$raw" ]]; then
      err_msg="File tidak ditemukan: '$raw'"
      continue
    fi
    TARGET_FILE="$raw"
    echo "$raw"
    return 0
  done
}

resolve_wordlist() {
  if [[ -n "$CUSTOM_WORDLIST" && -f "$CUSTOM_WORDLIST" ]]; then
    WORDLIST="$CUSTOM_WORDLIST"
    return 0
  fi
  local candidates=(
    "$SCRIPT_DIR/wordlists/minstrel-passwords.txt"
    "$ROOT_DIR/wordlists/minstrel-passwords.txt"
    "$ROOT_DIR/MinstrelGraphi/wordlists/minstrel-passwords.txt"
    "/usr/share/wordlists/rockyou.txt"
    "/usr/share/seclists/Passwords/Common-Credentials/10k-most-common.txt"
  )
  local c
  for c in "${candidates[@]}"; do
    if [[ -f "$c" && -s "$c" ]]; then
      WORDLIST="$c"
      return 0
    fi
  done
  TMP_WORDLIST=$(mktemp /tmp/minstrel_graphi_pw.XXXXXX)
  printf '%s\n' "${BUILTIN_PASSWORDS[@]}" > "$TMP_WORDLIST"
  WORDLIST="$TMP_WORDLIST"
}

# ---------------- EMBEDDED PYTHON3 CRYPTOGRAPHIC & SCAN ENGINE ----------------
run_python_crypto_engine() {
  local action=$1 file_path=$2 mode_hint=${3:-auto} wl_path=${4:-} out_dir=${5:-}
  python3 - "$action" "$file_path" "$mode_hint" "$wl_path" "$out_dir" << 'PYEOF'
import sys, os, re, math, json, zlib, gzip, bz2, lzma, base64, binascii, urllib.parse, html, hashlib, datetime

action = sys.argv[1]
file_path = sys.argv[2]
mode_hint = sys.argv[3].lower() if len(sys.argv) > 3 else "auto"
wl_path = sys.argv[4] if len(sys.argv) > 4 else ""
out_dir = sys.argv[5] if len(sys.argv) > 5 else "."

try:
    with open(file_path, "rb") as f:
        raw_bytes = f.read()
except Exception as e:
    print(f"ERROR|Cannot read file: {e}")
    sys.exit(1)

ENG_FREQ = {
    'a': 0.08167, 'b': 0.01492, 'c': 0.02782, 'd': 0.04253, 'e': 0.12702,
    'f': 0.02228, 'g': 0.02015, 'h': 0.06094, 'i': 0.06966, 'j': 0.00153,
    'k': 0.00772, 'l': 0.04025, 'm': 0.02406, 'n': 0.06749, 'o': 0.07507,
    'p': 0.01929, 'q': 0.00095, 'r': 0.05987, 's': 0.06327, 't': 0.09056,
    'u': 0.02758, 'v': 0.00978, 'w': 0.02360, 'x': 0.00150, 'y': 0.01974, 'z': 0.00074
}

COMMON_WORDS = (
    "the", "and", "that", "have", "for", "not", "with", "you", "this", "but",
    "secret", "password", "flag", "ctf", "minstrel", "crypto", "key", "congrat",
    "welcome", "admin", "token", "attack", "cipher", "plaintext", "berhasil",
    "rahasia", "kunci", "adalah", "untuk", "dengan", "yang", "dari"
)

FLAG_RE = re.compile(r'(?:flag|ctf|minstrel|picoctf|htb|thm)\{[A-Za-z0-9_@!?$%^&*+=\-.:/]+\}', re.I)

def shannon_entropy(data: bytes) -> float:
    if not data:
        return 0.0
    counts = [0] * 256
    for b in data:
        counts[b] += 1
    n = len(data)
    ent = 0.0
    for c in counts:
        if c:
            p = c / n
            ent -= p * math.log2(p)
    return ent

def index_of_coincidence(text: str) -> float:
    letters = [c.lower() for c in text if 'a' <= c.lower() <= 'z']
    n = len(letters)
    if n <= 1:
        return 0.0
    counts = {}
    for c in letters:
        counts[c] = counts.get(c, 0) + 1
    num = sum(v * (v - 1) for v in counts.values())
    return num / (n * (n - 1))

def printable_ratio(data: bytes) -> float:
    if not data:
        return 0.0
    pr = sum(1 for b in data if b in (9, 10, 13) or 32 <= b <= 126)
    return pr / len(data)

def chi_squared_score(text: str) -> float:
    letters = [c.lower() for c in text if 'a' <= c.lower() <= 'z']
    n = len(letters)
    if n < 4:
        return 9999.0
    counts = {k: 0 for k in ENG_FREQ}
    for c in letters:
        counts[c] += 1
    chi = 0.0
    for k, exp_p in ENG_FREQ.items():
        exp = n * exp_p
        diff = counts[k] - exp
        chi += (diff * diff) / exp
    return chi / n

def plaintext_quality(data: bytes) -> float:
    if not data:
        return -1e9
    pr = printable_ratio(data)
    if pr < 0.85:
        return -1000.0 * (1.0 - pr)
    try:
        s = data.decode('utf-8', errors='ignore')
    except Exception:
        return -500.0
    s_strip = s.strip()
    if not s_strip:
        return -500.0
    score = pr * 40.0
    if FLAG_RE.search(s_strip):
        score += 250.0
    low = s_strip.lower()
    word_hits = sum(1 for w in COMMON_WORDS if re.search(r'\b' + re.escape(w) + r'\b', low) or (len(w) >= 4 and w in low))
    score += word_hits * 18.0
    chi = chi_squared_score(s_strip)
    if chi < 2.5:
        score += max(0.0, (2.5 - chi) * 25.0)
    spaces = s_strip.count(' ')
    if len(s_strip) > 10 and 0.08 <= (spaces / len(s_strip)) <= 0.28:
        score += 20.0
    if re.fullmatch(r'[0-9a-fA-F\s]+', s_strip) and len(s_strip) >= 16:
        score -= 45.0
    if re.fullmatch(r'[A-Za-z0-9+/=\s]+', s_strip) and ('=' in s_strip or len(s_strip) % 4 == 0) and ' ' not in s_strip and len(s_strip) >= 16:
        score -= 35.0
    return score

HASH_MODES = {
    32:  [("MD5", "0"), ("NTLM", "1000"), ("MD4", "900")],
    40:  [("SHA-1", "100"), ("RIPEMD-160", "6000")],
    56:  [("SHA-224", "1300"), ("SHA3-224", "17300")],
    64:  [("SHA-256", "1400"), ("SHA3-256", "17400"), ("BLAKE2s-256", "31000")],
    96:  [("SHA-384", "10800"), ("SHA3-384", "17500")],
    128: [("SHA-512", "1700"), ("SHA3-512", "17600"), ("Whirlpool", "6100")]
}

def detect_candidates(data: bytes):
    cands = []
    if data.startswith(b'\x1f\x8b\x08'):
        cands.append(("Gzip Compressed Stream", "HIGH (99%)", "Cat I.6 - Compressed Stream"))
    if len(data) > 2 and data[0] == 0x78 and data[1] in (0x01, 0x5e, 0x9c, 0xda):
        cands.append(("Zlib Compressed Stream", "HIGH (98%)", "Cat I.6 - Compressed Stream"))
    if data.startswith(b'BZh'):
        cands.append(("Bzip2 Compressed Stream", "HIGH (99%)", "Cat I.6 - Compressed Stream"))
    if data.startswith(b'\xfd7zXZ\x00'):
        cands.append(("XZ / LZMA Stream", "HIGH (99%)", "Cat I.6 - Compressed Stream"))
    if data.startswith(b'Salted__'):
        cands.append(("OpenSSL Salted Cipher (AES/DES)", "HIGH (99%)", "Cat III.6 - Symmetric Block"))
    if b'-----BEGIN ' in data:
        cands.append(("PEM Key / Certificate Structure", "HIGH (99%)", "Cat IV.7 - Asymmetric PEM"))

    text = data.decode('utf-8', errors='ignore').strip()
    compact = re.sub(r'\s+', '', text)

    rsa_keys = re.findall(r'\b(n|e|c|p|q|d|dp|dq|phi)\s*[:=]\s*(0x[0-9a-fA-F]+|[0-9]{2,})', text)
    if len(rsa_keys) >= 2:
        found_vars = ",".join(sorted({k[0] for k in rsa_keys}))
        cands.append((f"RSA Math Parameters ({found_vars})", "HIGH (98%)", "Cat IV.1 - RSA Auto-Solver"))

    if re.fullmatch(r'\$2[aby]\$\d{2}\$[./A-Za-z0-9]{53}', compact):
        cands.append(("bcrypt Slow Hash (Hashcat -m 3200)", "HIGH (99%)", "Cat V.4 - Slow KDF Hash"))
    elif compact.startswith('$6$'):
        cands.append(("sha512crypt (Hashcat -m 1800)", "HIGH (99%)", "Cat V.4 - Slow KDF Hash"))
    elif compact.startswith('$1$'):
        cands.append(("md5crypt (Hashcat -m 500)", "HIGH (99%)", "Cat V.4 - Slow KDF Hash"))
    elif compact.startswith('$argon2'):
        cands.append(("Argon2 KDF (Hashcat -m 34000)", "HIGH (99%)", "Cat V.4 - Slow KDF Hash"))
    elif re.fullmatch(r'[0-9a-fA-F]+', compact) and len(compact) in HASH_MODES:
        h_list = HASH_MODES[len(compact)]
        h_str = " / ".join(f"{n} (-m {m})" for n, m in h_list[:2])
        cands.append((f"Hash: {h_str}", "HIGH (92%)", "Cat V.1 - GPU/CPU Hash Crack"))

    if re.fullmatch(r'[01\s]+', text) and len(compact) >= 16 and len(compact) % 8 == 0:
        cands.append(("8-Bit Binary ASCII Stream", "HIGH (96%)", "Cat I.3 - Binary Decoder"))
    if re.fullmatch(r'[.\-/\s]+', text) and ('.' in text or '-' in text):
        cands.append(("International Morse Code", "HIGH (96%)", "Cat I.5 - Morse Decoder"))
    if re.fullmatch(r'[+\-<>.,\[\]\s]+', text) and '[' in text and '.' in text:
        cands.append(("Brainfuck Esoteric Code", "HIGH (97%)", "Cat I.5 - Brainfuck Engine"))
    if re.fullmatch(r'[0-9a-fA-F\s]+', text) and len(compact) % 2 == 0 and len(compact) >= 8:
        cands.append(("Hexadecimal (Base16) / XOR Hex", "HIGH (90%)", "Cat I.2 / III.1 - Hex / XOR"))
    if re.fullmatch(r'[A-Z2-7=\s]+', text) and len(compact) >= 8 and len(compact) % 8 == 0:
        cands.append(("RFC-4648 Base32 Encoding", "HIGH (91%)", "Cat I.2 - Base32 Decoder"))
    if re.fullmatch(r'[A-Za-z0-9+/=\s]+', text) and len(compact) >= 8 and len(compact) % 4 == 0:
        cands.append(("RFC-4648 Base64 Encoding", "HIGH (89%)", "Cat I.2 - Base64 Decoder"))
    if '%2' in text or '%3' in text or '%7' in text:
        cands.append(("URL Percent-Encoding", "HIGH (90%)", "Cat I.4 - URL Decoder"))

    pr = printable_ratio(data)
    ioc = index_of_coincidence(text)
    if pr > 0.90 and sum(1 for c in text if c.isalpha()) >= 12:
        if 0.056 <= ioc <= 0.085:
            cands.append((f"Monoalphabetic/Transposition (IoC {ioc:.3f})", "MED-HIGH (84%)", "Cat II - Caesar/Affine/Rail"))
        elif 0.038 <= ioc < 0.056:
            cands.append((f"Polyalphabetic / Vigenere (IoC {ioc:.3f})", "MED-HIGH (82%)", "Cat II.4 - Vigenere Cracker"))
    if pr < 0.75 and len(data) >= 4:
        cands.append(("Raw XOR / Binary Stream Cipher", "MEDIUM (78%)", "Cat III - Single/Repeat XOR"))

    if not cands:
        cands.append(("Multi-Layer / Obfuscated Ciphertext", "AUTO-DETECT", "Mode 1 - Auto-Solve All"))
    return cands

if action == "scan":
    ent = shannon_entropy(raw_bytes)
    pr = printable_ratio(raw_bytes) * 100.0
    txt = raw_bytes.decode('utf-8', errors='ignore')
    ioc = index_of_coincidence(txt)
    cands = detect_candidates(raw_bytes)
    print(f"META|File Size|{len(raw_bytes)} bytes")
    print(f"META|Shannon Entropy|{ent:.4f} bits/byte")
    print(f"META|Index of Coincidence|{ioc:.4f} (English ~0.0667)")
    print(f"META|Printable ASCII|{pr:.1f}%")
    for name, conf, rec in cands:
        print(f"CAND|{conf}|{name}|{rec}")
    sys.exit(0)

MORSE_MAP = {
    '.-':'A','-...':'B','-.-.':'C','-..':'D','.':'E','..-.':'F','--.':'G','....':'H',
    '..':'I','.---':'J','-.-':'K','.-..':'L','--':'M','-.':'N','---':'O','.--.':'P',
    '--.-':'Q','.-.':'R','...':'S','-':'T','..-':'U','...-':'V','.--':'W','-..-':'X',
    '-.--':'Y','--..':'Z','-----':'0','.----':'1','..---':'2','...--':'3','....-':'4',
    '.....':'5','-....':'6','--...':'7','---..':'8','----.':'9','.-.-.-':'.','--..--':',',
    '..--..':'?','-..-.':'/','-....-':'-','-.--.':'(','-.--.-':')','..--.-':'_',
    '---...':':','-.-.-.':';','-...-':'='
}

B58_ALPH = b'123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'

def b58_decode(s: str) -> bytes:
    s_b = re.sub(r'\s+', '', s).encode('ascii')
    if not s_b or any(c not in B58_ALPH for c in s_b):
        raise ValueError("Not Base58")
    n = 0
    for c in s_b:
        n = n * 58 + B58_ALPH.index(c)
    res = n.to_bytes((n.bit_length() + 7) // 8, 'big') if n > 0 else b''
    pad = 0
    for c in s_b:
        if c == ord('1'):
            pad += 1
        else:
            break
    return b'\x00' * pad + res

def run_brainfuck(code: str, max_steps: int = 200000) -> bytes:
    ops = [c for c in code if c in '+-<>.,[]']
    if len(ops) < 5:
        raise ValueError("Too short")
    braces = {}
    stack = []
    for i, c in enumerate(ops):
        if c == '[':
            stack.append(i)
        elif c == ']':
            if not stack:
                raise ValueError("Unbalanced")
            j = stack.pop()
            braces[i] = j
            braces[j] = i
    if stack:
        raise ValueError("Unbalanced")
    tape = [0] * 4096
    ptr = 0
    ip = 0
    steps = 0
    out = bytearray()
    while ip < len(ops) and steps < max_steps:
        c = ops[ip]
        if c == '>': ptr = (ptr + 1) % 4096
        elif c == '<': ptr = (ptr - 1) % 4096
        elif c == '+': tape[ptr] = (tape[ptr] + 1) & 0xff
        elif c == '-': tape[ptr] = (tape[ptr] - 1) & 0xff
        elif c == '.': out.append(tape[ptr])
        elif c == '[' and tape[ptr] == 0: ip = braces[ip]
        elif c == ']' and tape[ptr] != 0: ip = braces[ip]
        ip += 1
        steps += 1
    if not out:
        raise ValueError("No output")
    return bytes(out)

def single_layer_decoders(data: bytes):
    results = []
    if data.startswith(b'\x1f\x8b\x08'):
        try: results.append(("Gzip Decompress", gzip.decompress(data)))
        except Exception: pass
    if len(data) > 2 and data[0] == 0x78:
        try: results.append(("Zlib Decompress", zlib.decompress(data)))
        except Exception: pass
    if data.startswith(b'BZh'):
        try: results.append(("Bzip2 Decompress", bz2.decompress(data)))
        except Exception: pass
    if data.startswith(b'\xfd7zXZ\x00'):
        try: results.append(("XZ Decompress", lzma.decompress(data)))
        except Exception: pass

    try:
        s = data.decode('utf-8').strip()
    except Exception:
        return results
    if not s:
        return results
    compact = re.sub(r'\s+', '', s)

    if re.fullmatch(r'(?:0x)?[0-9a-fA-F\s]+', s):
        hx = re.sub(r'0x|\s+', '', s)
        if len(hx) >= 4 and len(hx) % 2 == 0:
            try: results.append(("Hex Decode", bytes.fromhex(hx)))
            except Exception: pass

    if re.fullmatch(r'[01\s]+', s) and len(compact) >= 8 and len(compact) % 8 == 0:
        try:
            b_out = bytes(int(compact[i:i+8], 2) for i in range(0, len(compact), 8))
            results.append(("Binary 8-bit Decode", b_out))
        except Exception:
            pass

    if re.fullmatch(r'[0-7]+(?:\s+[0-7]+)+', s):
        try:
            o_out = bytes(int(tok, 8) for tok in s.split() if 0 <= int(tok, 8) <= 255)
            if len(o_out) >= 3:
                results.append(("Octal ASCII Decode", o_out))
        except Exception:
            pass

    if re.fullmatch(r'\d+(?:[\s,]+\d+)+', s):
        toks = [int(t) for t in re.split(r'[\s,]+', s) if t]
        if toks and all(32 <= t <= 126 or t in (9, 10, 13) for t in toks):
            results.append(("Decimal ASCII Decode", bytes(toks)))
        if toks and all(1 <= t <= 26 for t in toks):
            a1 = "".join(chr(64 + t) for t in toks).encode()
            results.append(("A1Z26 Number-to-Letter", a1))

    if re.fullmatch(r'[A-Z2-7=]+', compact.upper()) and len(compact) >= 8:
        pad_s = compact.upper()
        if len(pad_s) % 8 != 0:
            pad_s += '=' * (8 - (len(pad_s) % 8))
        try: results.append(("Base32 Decode", base64.b32decode(pad_s)))
        except Exception: pass

    if re.fullmatch(r'[A-Za-z0-9+/=\-_]+', compact) and len(compact) >= 4:
        pad_s = compact
        if len(pad_s) % 4 != 0:
            pad_s += '=' * (4 - (len(pad_s) % 4))
        try:
            b64 = base64.urlsafe_b64decode(pad_s) if ('-' in compact or '_' in compact) else base64.b64decode(pad_s)
            if b64 and b64 != data:
                results.append(("Base64 Decode", b64))
        except Exception:
            pass

    if len(compact) >= 5:
        for fn, lbl in ((base64.b85decode, "Base85 Decode"), (base64.a85decode, "Ascii85 Decode")):
            try:
                out85 = fn(compact.encode())
                if out85 and printable_ratio(out85) > 0.7:
                    results.append((lbl, out85))
            except Exception:
                pass

    if 6 <= len(compact) <= 512:
        try:
            out58 = b58_decode(compact)
            if out58 and printable_ratio(out58) > 0.75:
                results.append(("Base58 Decode", out58))
        except Exception:
            pass

    if '%' in s and re.search(r'%[0-9a-fA-F]{2}', s):
        u_dec = urllib.parse.unquote_to_bytes(s)
        if u_dec != data:
            results.append(("URL Percent Decode", u_dec))

    if '&' in s and ';' in s:
        h_dec = html.unescape(s).encode('utf-8')
        if h_dec != data:
            results.append(("HTML Entity Decode", h_dec))

    if re.fullmatch(r'[.\-/\s]+', s) and ('.' in s or '-' in s):
        words = []
        for w_part in re.split(r'\s*/\s*|\s{3,}', s.strip()):
            chars = [MORSE_MAP.get(tok, '') for tok in w_part.split()]
            if any(chars):
                words.append("".join(chars))
        if words:
            results.append(("Morse Code Decode", " ".join(words).encode()))

    if re.fullmatch(r'[ABab\s]+', s) and len(compact) >= 15 and len(compact) % 5 == 0:
        bac = []
        for i in range(0, len(compact), 5):
            chunk = compact[i:i+5].upper().replace('A', '0').replace('B', '1')
            val = int(chunk, 2)
            if val < 26:
                bac.append(chr(65 + val))
        if len(bac) >= 3:
            results.append(("Baconian Cipher Decode", "".join(bac).encode()))

    if re.fullmatch(r'[+\-<>.,\[\]\s]+', s) and '[' in s and '.' in s:
        try:
            results.append(("Brainfuck Interpreter", run_brainfuck(s)))
        except Exception:
            pass

    return results

def solve_encodings_recursive(start_bytes: bytes, max_depth: int = 20):
    visited = {start_bytes}
    best_data = start_bytes
    best_chain = []
    best_score = plaintext_quality(start_bytes)

    queue = [(start_bytes, [])]
    while queue:
        data_item, path = queue.pop(0)
        if len(path) >= max_depth:
            continue
        for lbl, nxt in single_layer_decoders(data_item):
            if not nxt or nxt in visited:
                continue
            visited.add(nxt)
            new_path = path + [lbl]
            sc = plaintext_quality(nxt)
            if sc > best_score:
                best_score = sc
                best_data = nxt
                best_chain = new_path
            if FLAG_RE.search(nxt.decode('utf-8', errors='ignore')):
                return best_score + 100.0, nxt, new_path
            queue.append((nxt, new_path))
    return best_score, best_data, best_chain

def caesar_shift(text: str, shift: int) -> str:
    out = []
    for c in text:
        if 'a' <= c <= 'z':
            out.append(chr((ord(c) - 97 - shift) % 26 + 97))
        elif 'A' <= c <= 'Z':
            out.append(chr((ord(c) - 65 - shift) % 26 + 65))
        else:
            out.append(c)
    return "".join(out)

def rot47_transform(text: str) -> str:
    return "".join(chr(33 + ((ord(c) - 33 + 47) % 94)) if 33 <= ord(c) <= 126 else c for c in text)

def atbash_transform(text: str) -> str:
    out = []
    for c in text:
        if 'a' <= c <= 'z': out.append(chr(122 - (ord(c) - 97)))
        elif 'A' <= c <= 'Z': out.append(chr(90 - (ord(c) - 65)))
        else: out.append(c)
    return "".join(out)

def affine_decrypt(text: str, a: int, b: int) -> str:
    a_inv = pow(a, -1, 26)
    out = []
    for c in text:
        if 'a' <= c <= 'z':
            out.append(chr((a_inv * ((ord(c) - 97) - b)) % 26 + 97))
        elif 'A' <= c <= 'Z':
            out.append(chr((a_inv * ((ord(c) - 65) - b)) % 26 + 65))
        else:
            out.append(c)
    return "".join(out)

def rail_fence_decrypt(text: str, rails: int) -> str:
    n = len(text)
    if rails <= 1 or rails >= n:
        return text
    pattern = []
    r, step = 0, 1
    for _ in range(n):
        pattern.append(r)
        if r == 0: step = 1
        elif r == rails - 1: step = -1
        r += step
    rail_counts = [pattern.count(x) for x in range(rails)]
    pos = 0
    rail_strs = []
    for cnt in rail_counts:
        rail_strs.append(list(text[pos:pos+cnt]))
        pos += cnt
    idx = [0] * rails
    out = []
    for r_id in pattern:
        out.append(rail_strs[r_id][idx[r_id]])
        idx[r_id] += 1
    return "".join(out)

def vigenere_crack(text: str):
    alpha = [(i, c) for i, c in enumerate(text) if 'a' <= c.lower() <= 'z']
    if len(alpha) < 12:
        return []
    letters_only = "".join(c.lower() for _, c in alpha)
    candidates = []
    for klen in range(2, min(15, len(letters_only) // 3 + 1)):
        key_shifts = []
        for col in range(klen):
            slice_str = letters_only[col::klen]
            best_sh = min(range(26), key=lambda sh: chi_squared_score(caesar_shift(slice_str, sh)))
            key_shifts.append(best_sh)
        key_str = "".join(chr(97 + s) for s in key_shifts)
        out = list(text)
        for idx_alpha, (orig_pos, orig_ch) in enumerate(alpha):
            sh = key_shifts[idx_alpha % klen]
            if 'a' <= orig_ch <= 'z':
                out[orig_pos] = chr((ord(orig_ch) - 97 - sh) % 26 + 97)
            else:
                out[orig_pos] = chr((ord(orig_ch) - 65 - sh) % 26 + 65)
        dec = "".join(out)
        candidates.append((f"Vigenere (key='{key_str}')", dec.encode()))
    return candidates

def solve_classical(data: bytes, submode: str = "all"):
    try:
        text = data.decode('utf-8').strip()
    except Exception:
        return -1e9, data, []
    if not text:
        return -1e9, data, []

    cands = []
    if submode in ("all", "caesar", "rot"):
        for sh in range(1, 26):
            lbl = "ROT13" if sh == 13 else f"Caesar (ROT-{sh})"
            cands.append((lbl, caesar_shift(text, sh).encode()))
        cands.append(("ROT47", rot47_transform(text).encode()))
    if submode in ("all", "atbash"):
        cands.append(("Atbash Mirror", atbash_transform(text).encode()))
        cands.append(("Reverse String", text[::-1].encode()))
    if submode in ("all", "affine"):
        for a in (1, 3, 5, 7, 9, 11, 15, 17, 19, 21, 23, 25):
            for b in range(26):
                if a == 1 and b == 0:
                    continue
                cands.append((f"Affine (a={a}, b={b})", affine_decrypt(text, a, b).encode()))
    if submode in ("all", "rail", "transposition"):
        for r in range(2, min(16, len(text))):
            cands.append((f"Rail Fence ({r} rails)", rail_fence_decrypt(text, r).encode()))
    if submode in ("all", "vigenere"):
        cands.extend(vigenere_crack(text))

    best_sc = -1e9
    best_out = data
    best_lbl = []
    orig_sc = plaintext_quality(data)
    for lbl, out_b in cands:
        if out_b == data:
            continue
        sc = plaintext_quality(out_b)
        if sc > best_sc and (sc > orig_sc + 8.0 or FLAG_RE.search(out_b.decode('utf-8', errors='ignore'))):
            best_sc = sc
            best_out = out_b
            best_lbl = [lbl]
    return best_sc, best_out, best_lbl

def solve_xor(data: bytes, submode: str = "all"):
    target_bytes = data
    prefix_chain = []
    s_txt = data.decode('utf-8', errors='ignore').strip()
    if re.fullmatch(r'(?:0x)?[0-9a-fA-F\s]+', s_txt):
        hx = re.sub(r'0x|\s+', '', s_txt)
        if len(hx) >= 4 and len(hx) % 2 == 0:
            try:
                target_bytes = bytes.fromhex(hx)
                prefix_chain = ["Hex Decode"]
            except Exception:
                pass

    best_sc = -1e9
    best_out = target_bytes
    best_chain = []

    if submode in ("all", "single"):
        for k in range(1, 256):
            dec = bytes(b ^ k for b in target_bytes)
            sc = plaintext_quality(dec)
            if sc > best_sc:
                best_sc = sc
                best_out = dec
                best_chain = prefix_chain + [f"Single-Byte XOR (key=0x{k:02x})"]

    if submode in ("all", "crib", "repeating") and len(target_bytes) >= 6:
        for crib in (b"flag{", b"FLAG{", b"ctf{", b"CTF{", b"minstrel{"):
            k_derived = bytes(target_bytes[i] ^ crib[i] for i in range(len(crib)))
            for klen in range(2, len(crib) + 1):
                key_cand = k_derived[:klen]
                dec = bytes(target_bytes[i] ^ key_cand[i % klen] for i in range(len(target_bytes)))
                sc = plaintext_quality(dec)
                if sc > best_sc:
                    best_sc = sc
                    best_out = dec
                    k_repr = key_cand.decode('ascii', errors='ignore') or key_cand.hex()
                    best_chain = prefix_chain + [f"Known-Plaintext XOR (key='{k_repr}')"]

    orig_target_sc = plaintext_quality(target_bytes)
    if submode in ("all", "repeating") and len(target_bytes) >= 12:
        for klen in range(2, min(17, len(target_bytes) // 2 + 1)):
            key_bytes = bytearray()
            for col in range(klen):
                col_b = target_bytes[col::klen]
                best_k = max(range(1, 256), key=lambda k: plaintext_quality(bytes(b ^ k for b in col_b)))
                key_bytes.append(best_k)
            dec = bytes(target_bytes[i] ^ key_bytes[i % klen] for i in range(len(target_bytes)))
            sc = plaintext_quality(dec)
            if sc > best_sc and (sc > orig_target_sc + 15.0 or len(prefix_chain) > 0):
                best_sc = sc
                best_out = dec
                k_disp = key_bytes.decode('ascii', errors='ignore') if all(32 <= x <= 126 for x in key_bytes) else key_bytes.hex()
                best_chain = prefix_chain + [f"Repeating-Key XOR (key='{k_disp}')"]

    return best_sc, best_out, best_chain

def iroot(k: int, n: int):
    if n <= 0:
        return 0, False
    lo, hi = 1, 1 << ((n.bit_length() + k - 1) // k + 1)
    while lo <= hi:
        mid = (lo + hi) // 2
        p = mid ** k
        if p == n:
            return mid, True
        elif p < n:
            lo = mid + 1
        else:
            hi = mid - 1
    return hi, (hi ** k == n)

def fermat_factor(n: int, max_iter: int = 100000):
    if n % 2 == 0:
        return 2, n // 2
    a = math.isqrt(n)
    if a * a < n:
        a += 1
    for _ in range(max_iter):
        b2 = a * a - n
        b = math.isqrt(b2)
        if b * b == b2:
            p, q = a - b, a + b
            if p > 1 and q > 1 and p * q == n:
                return p, q
        a += 1
    return None, None

def wiener_attack(e: int, n: int):
    cf = []
    num, den = e, n
    while den != 0:
        q = num // den
        cf.append(q)
        num, den = den, num - q * den
    p_prev, p_curr = 1, 0
    q_prev, q_curr = 0, 1
    for a in cf:
        k = a * p_curr + p_prev
        d = a * q_curr + q_prev
        p_prev, p_curr = p_curr, k
        q_prev, q_curr = q_curr, d
        if k == 0 or d == 0 or (e * d - 1) % k != 0:
            continue
        phi = (e * d - 1) // k
        s = n - phi + 1
        disc = s * s - 4 * n
        if disc >= 0:
            sq = math.isqrt(disc)
            if sq * sq == disc and (s + sq) % 2 == 0:
                return d
    return None

def pollard_rho(n: int, max_steps: int = 120000):
    if n % 2 == 0:
        return 2
    for p in (3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47):
        if n % p == 0:
            return p
    x, y, d, c = 2, 2, 1, 1
    steps = 0
    while d == 1 and steps < max_steps:
        x = (x * x + c) % n
        y = (y * y + c) % n
        y = (y * y + c) % n
        d = math.gcd(abs(x - y), n)
        steps += 1
        if d == n:
            x = steps + 2
            y = x
            c += 1
            d = 1
    return d if 1 < d < n else None

def solve_rsa(data: bytes):
    text = data.decode('utf-8', errors='ignore')
    params = {}
    for m in re.finditer(r'\b(n|e|c|p|q|d|dp|dq|phi)\s*[:=]\s*(0x[0-9a-fA-F]+|[0-9]+)', text, re.I):
        k = m.group(1).lower()
        v_str = m.group(2)
        params[k] = int(v_str, 16) if v_str.lower().startswith('0x') else int(v_str)

    if 'c' not in params:
        return -1e9, data, []

    c = params['c']
    e = params.get('e', 65537)
    n = params.get('n')
    p = params.get('p')
    q = params.get('q')
    d = params.get('d')
    attack_used = ""

    if p and q and not n:
        n = p * q

    if d and n:
        m_int = pow(c, d, n)
        attack_used = "RSA Direct Private Exponent (d)"
    elif p and q:
        phi = (p - 1) * (q - 1)
        d = pow(e, -1, phi)
        m_int = pow(c, d, p * q)
        attack_used = "RSA Prime Factors (p, q)"
    elif n:
        m_int = None
        if e in (3, 5):
            for k_mul in range(0, 2000):
                rt, exact = iroot(e, c + k_mul * n)
                if exact:
                    m_int = rt
                    attack_used = f"RSA Small Exponent Root Attack (e={e}, k={k_mul})"
                    break
        if m_int is None:
            w_d = wiener_attack(e, n)
            if w_d:
                m_int = pow(c, w_d, n)
                attack_used = "RSA Wiener's Continued Fractions Attack"
        if m_int is None and n.bit_length() <= 2048:
            fp, fq = fermat_factor(n)
            if fp and fq:
                phi = (fp - 1) * (fq - 1)
                d = pow(e, -1, phi)
                m_int = pow(c, d, n)
                attack_used = "RSA Fermat Close-Primes Factorization"
        if m_int is None and n.bit_length() <= 512:
            pr_p = pollard_rho(n)
            if pr_p and n % pr_p == 0:
                pr_q = n // pr_p
                phi = (pr_p - 1) * (pr_q - 1)
                d = pow(e, -1, phi)
                m_int = pow(c, d, n)
                attack_used = "RSA Pollard's Rho Factorization"
        if m_int is None:
            return -1e9, data, []
    else:
        return -1e9, data, []

    m_bytes = m_int.to_bytes((m_int.bit_length() + 7) // 8, 'big')
    return plaintext_quality(m_bytes) + 300.0, m_bytes, [attack_used]

def solve_hash(data: bytes, wl_file: str):
    target_h = re.sub(r'\s+', '', data.decode('utf-8', errors='ignore')).lower()
    if not re.fullmatch(r'[0-9a-f]{32,128}', target_h):
        return -1e9, data, []
    hlen = len(target_h)
    algos = []
    if hlen == 32: algos = [("MD5", hashlib.md5)]
    elif hlen == 40: algos = [("SHA-1", hashlib.sha1)]
    elif hlen == 56: algos = [("SHA-224", hashlib.sha224), ("SHA3-224", hashlib.sha3_224)]
    elif hlen == 64: algos = [("SHA-256", hashlib.sha256), ("SHA3-256", hashlib.sha3_256)]
    elif hlen == 96: algos = [("SHA-384", hashlib.sha384), ("SHA3-384", hashlib.sha3_384)]
    elif hlen == 128: algos = [("SHA-512", hashlib.sha512), ("SHA3-512", hashlib.sha3_512)]
    else:
        return -1e9, data, []

    words = []
    if wl_file and os.path.isfile(wl_file):
        with open(wl_file, "r", errors="ignore") as wf:
            for line in wf:
                w = line.strip()
                if w:
                    words.append(w)

    candidates = []
    seen = set()
    for w in words:
        for variant in (w, w.capitalize(), w.upper(), w + "123", w + "!", w + "1", w + "2025", w + "2026", f"flag{{{w}}}", f"CTF{{{w}}}"):
            if variant not in seen:
                seen.add(variant)
                candidates.append(variant)

    for pw in candidates:
        pw_b = pw.encode('utf-8')
        for alg_name, fn in algos:
            if fn(pw_b).hexdigest() == target_h:
                return 300.0, pw_b, [f"Hash Cracked ({alg_name})"]
    return -1e9, data, []

candidates_pool = []

if mode_hint in ("auto", "cat1", "encoding", "base", "radix", "web", "esoteric", "compress"):
    sc, out_b, ch = solve_encodings_recursive(raw_bytes)
    if ch:
        candidates_pool.append((sc, out_b, ch))
        sc2, out_b2, ch2 = solve_classical(out_b, "all")
        if ch2 and sc2 > sc + 8.0:
            candidates_pool.append((sc2, out_b2, ch + ch2))
        sc3, out_b3, ch3 = solve_xor(out_b, "all")
        if ch3 and sc3 > sc + 8.0:
            candidates_pool.append((sc3, out_b3, ch + ch3))

if mode_hint in ("auto", "cat2", "classical", "caesar", "affine", "vigenere", "atbash", "rail", "transposition"):
    sub = mode_hint if mode_hint in ("caesar", "affine", "vigenere", "atbash", "rail", "transposition") else "all"
    sc, out_b, ch = solve_classical(raw_bytes, sub)
    if ch:
        candidates_pool.append((sc, out_b, ch))

if mode_hint in ("auto", "cat3", "xor", "single", "repeating", "crib"):
    sub = mode_hint if mode_hint in ("single", "repeating", "crib") else "all"
    sc, out_b, ch = solve_xor(raw_bytes, sub)
    if ch:
        candidates_pool.append((sc, out_b, ch))

if mode_hint in ("auto", "cat4", "rsa"):
    sc, out_b, ch = solve_rsa(raw_bytes)
    if ch:
        candidates_pool.append((sc, out_b, ch))

if mode_hint in ("auto", "cat5", "hash"):
    sc, out_b, ch = solve_hash(raw_bytes, wl_path)
    if ch:
        candidates_pool.append((sc, out_b, ch))

if not candidates_pool:
    print("STATUS|UNSOLVED")
    sys.exit(0)

candidates_pool.sort(key=lambda x: x[0], reverse=True)
best_sc, best_bytes, best_chain = candidates_pool[0]
pt_str = best_bytes.decode('utf-8', errors='replace').strip()
pt_single_line = re.sub(r'[\r\n]+', ' ', pt_str)
flag_match = FLAG_RE.search(pt_str)
flag_str = flag_match.group(0) if flag_match else "NONE"
recipe_str = " -> ".join(best_chain)

print("STATUS|SOLVED")
print(f"RECIPE|{recipe_str}")
print(f"SCORE|{best_sc:.1f}")
print(f"FLAG|{flag_str}")
print(f"PLAINTEXT|{pt_single_line}")
for idx, step in enumerate(best_chain, 1):
    print(f"STEP|{idx}|{step}")

if out_dir and os.path.isdir(out_dir):
    with open(os.path.join(out_dir, "plaintext.txt"), "wb") as pf:
        pf.write(best_bytes)
    rep = {
        "framework": "Minstrel",
        "tool": "Minstrel Graphi",
        "version": "2.1.0",
        "target_file": file_path,
        "status": "SOLVED",
        "recipe": best_chain,
        "confidence_score": round(best_sc, 2),
        "flag_detected": flag_str,
        "plaintext_preview": pt_single_line[:256],
        "timestamp": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    }
    with open(os.path.join(out_dir, "report.json"), "w") as jf:
        json.dump(rep, jf, indent=2)
PYEOF
}

try_gpu_hashcat() {
  local file_path=$1
  have hashcat || return 1
  local raw_h
  raw_h=$(tr -d '[:space:]' < "$file_path" 2>/dev/null || true)
  local h_mode=""
  case "${#raw_h}" in
    32)  h_mode=0 ;;
    40)  h_mode=100 ;;
    56)  h_mode=1300 ;;
    64)  h_mode=1400 ;;
    96)  h_mode=10800 ;;
    128) h_mode=1700 ;;
  esac
  [[ "$raw_h" == \$2[aby]\$* ]] && h_mode=3200
  [[ "$raw_h" == \$6\$* ]] && h_mode=1800
  [[ "$raw_h" == \$1\$* ]] && h_mode=500
  [[ -z "$h_mode" ]] && return 1

  local hc_args=(-m "$h_mode" -a 0 -O -w "$GPU_WORKLOAD" --potfile-disable --quiet "$file_path" "$WORDLIST")
  [[ "$GPU_ACTIVE" -eq 0 ]] && hc_args+=(--force)
  log "Meluncurkan GPU/OpenCL Hashcat Engine (mode -m ${h_mode} · workload -w ${GPU_WORKLOAD})…"
  local hc_out
  hc_out=$(hashcat "${hc_args[@]}" 2>/dev/null | head -1 || true)
  if [[ -n "$hc_out" && "$hc_out" == *:* ]]; then
    local cracked="${hc_out#*:}"
    frow "[GPU-HASHCAT]" "CRACKED" "$cracked" "$G"
    return 0
  fi
  return 1
}

# ---------------- SCAN & SOLVE WORKFLOWS ----------------
do_scan_file() {
  local target=${1:-}
  if [[ -z "$target" ]]; then
    banner
    target=$(input_file_path) || return 1
  fi
  [[ -f "$target" ]] || die "File tidak ditemukan: $target"
  TARGET_FILE="$target"

  banner
  log "Scanning struktur & tanda tangan kriptografi: ${W}${TARGET_FILE}${NC}"
  sep
  row "METRIK TELEMETRI FILE" "NILAI ANALISIS STATISTIK"
  sep

  local line kind k v c_conf c_name c_rec
  while IFS= read -r line; do
    kind="${line%%|*}"
    if [[ "$kind" == "META" ]]; then
      IFS='|' read -r _ k v <<< "$line"
      row "$k" "$v"
    fi
  done < <(run_python_crypto_engine "scan" "$TARGET_FILE")

  sep
  printf '\n'
  sep
  frow "CONFIDENCE" "CATEGORY" "DETECTED CRYPTO / ENCODING TYPE" "$W"
  sep

  while IFS= read -r line; do
    kind="${line%%|*}"
    if [[ "$kind" == "CAND" ]]; then
      IFS='|' read -r _ c_conf c_name c_rec <<< "$line"
      frow "[$c_conf]" "${c_rec%% -*}" "$c_name" "$G"
    fi
  done < <(run_python_crypto_engine "scan" "$TARGET_FILE")
  sep

  if is_tty; then
    printf '\n' >&2
    MENU_DESC=(
      "Jalankan Auto-Cryptanalysis Engine sekarang untuk membuka file ini"
      "Kembali ke menu utama Minstrel Graphi"
    )
    local act
    act=$(menu_pick "TINDAK LANJUT HASIL SCAN" \
      "Langsung Auto-Solve / Crack File Ini Sekarang" \
      "← Kembali ke Menu Utama") || return 0
    if [[ "$act" == "1" ]]; then
      do_solve_file "$TARGET_FILE" "auto"
    fi
  fi
}

do_solve_file() {
  local target=${1:-} mode_hint=${2:-auto}
  if [[ -z "$target" ]]; then
    banner
    target=$(input_file_path) || return 1
  fi
  [[ -f "$target" ]] || die "File tidak ditemukan: $target"
  TARGET_FILE="$target"
  resolve_wordlist

  local base_name="${TARGET_FILE##*/}"
  base_name="${base_name//[^A-Za-z0-9._-]/_}"
  OUTDIR="${CLI_OUTDIR:-minstrel_graphi_${base_name}}"
  mkdir -p "$OUTDIR"

  banner
  log "Target File: ${W}${TARGET_FILE}${NC} · Engine Mode: ${CYN}${mode_hint^^}${NC} · Accel: ${G}${GPU_BACKEND}${NC}"

  if [[ "$DRY_ON" == "1" ]]; then
    dry "run_python_crypto_engine solve '$TARGET_FILE' '$mode_hint' '$WORDLIST' '$OUTDIR'"
    return 0
  fi

  local status="UNSOLVED" recipe="" score="" flag_val="NONE" pt="" line kind s_idx s_lbl
  local -a steps=()

  while IFS= read -r line; do
    kind="${line%%|*}"
    case "$kind" in
      STATUS)    status="${line#STATUS|}" ;;
      RECIPE)    recipe="${line#RECIPE|}" ;;
      SCORE)     score="${line#SCORE|}" ;;
      FLAG)      flag_val="${line#FLAG|}" ;;
      PLAINTEXT) pt="${line#PLAINTEXT|}" ;;
      STEP)
        IFS='|' read -r _ s_idx s_lbl <<< "$line"
        steps+=("${s_idx}|${s_lbl}")
        ;;
    esac
  done < <(run_python_crypto_engine "solve" "$TARGET_FILE" "$mode_hint" "$WORDLIST" "$OUTDIR")

  if [[ "$status" != "SOLVED" && ( "$mode_hint" == "auto" || "$mode_hint" == "cat5" || "$mode_hint" == "hash" ) ]]; then
    try_gpu_hashcat "$TARGET_FILE" && status="SOLVED"
  fi

  sep
  frow "LAYER / STEP" "STATUS" "DECRYPTION / CRACKING TRANSFORMATION" "$W"
  sep
  if [[ "$status" == "SOLVED" ]]; then
    local st_entry
    for st_entry in "${steps[@]}"; do
      IFS='|' read -r s_idx s_lbl <<< "$st_entry"
      frow "[LAYER #${s_idx}]" "DECODED" "$s_lbl" "$G"
    done
    sep
    printf '\n'
    row "MINSTREL GRAPHI RESULT" "DECRYPTED OUTPUT & METRICS"
    sep
    row "Target File" "$TARGET_FILE"
    row "Hardware Acceleration" "$GPU_BACKEND ($GPU_VENDOR)"
    row "Decryption Recipe" "$recipe"
    [[ "$flag_val" != "NONE" ]] && row "Flag Extracted" "$flag_val"
    row "Plaintext Preview" "$pt"
    row "Saved Output File" "$OUTDIR/plaintext.txt"
    row "Executive JSON Report" "$OUTDIR/report.json"
    sep
    printf '  %s» CRYPTO SOLVED FLAWLESSLY. [ MINSTREL GRAPHI v%s ]%s\n' "$LG" "$VERSION" "$NC"
  else
    frow "[HIGH-ENTROPY]" "LOCKED" "Requires External Key / Larger Wordlist" "$Y"
    sep
    warn "File membutuhkan Key/Passphrase eksternal — gunakan '-w <wordlist>' atau cek parameter."
  fi
}

# ---------------- CATEGORY & SUB-CATEGORY INTERACTIVE MENUS ----------------
menu_cat_encoding() {
  while true; do
    banner
    MENU_DESC=(
      "Kupas otomatis 1-25 lapis semua kombinasi encoding (Base/Hex/Bin/Zlib/Morse/ROT)"
      "Decode keluarga Base: Base16, Base32, Base58 (Bitcoin), Base64, Base64URL, Base85, Ascii85"
      "Decode numerik: Hexadecimal, Binary 8-bit, Octal, Decimal ASCII, A1Z26"
      "Decode format web: URL Percent-Encoding (%xx) & HTML Entities (&amp;)"
      "Decode sandi sinyal & esoterik: Morse Code, Baconian 5-bit & Brainfuck Interpreter"
      "Decompress stream terkompresi: Gzip, Zlib, Bzip2 & XZ/LZMA"
      "Kembali ke daftar kategori utama kriptografi"
    )
    local c
    c=$(menu_pick "KATEGORI I — MULTI-LAYER ENCODING & REPRESENTATION" \
      "Auto-Solve Multi-Layer Encoding (Recursive 25x)" \
      "Base Family (Base16 / 32 / 58 / 64 / 85 / Ascii85)" \
      "Radix & Numeric (Hex / Binary / Octal / Decimal / A1Z26)" \
      "Web & Transport (URL Percent / HTML Entities)" \
      "Esoteric & Signal (Morse Code / Baconian / Brainfuck)" \
      "Compressed Stream (Gzip / Zlib / Bzip2 / XZ)" \
      "← Kembali ke Kategori") || return 0
    case "$c" in
      1|2|3|4|5|6)
        local tgt
        if tgt=$(input_file_path); then
          do_solve_file "$tgt" "cat1"
          press_enter
        fi
        ;;
      *) return 0 ;;
    esac
  done
}

menu_cat_classical() {
  while true; do
    banner
    MENU_DESC=(
      "Crack otomatis semua sandi klasik menggunakan Chi-Squared & Index of Coincidence"
      "Bruteforce seluruh 25 geseran Caesar (ROT1-25), ROT13, dan ASCII ROT47"
      "Crack Affine Cipher E(x)=(ax+b) mod 26 pada seluruh 312 pasangan kunci (a,b)"
      "Crack Vigenere & Polialfabetik otomatis (deteksi panjang kunci IoC + analisis frekuensi)"
      "Substitusi cermin alfabet Atbash (A<->Z) & pembalikan string (Reverse)"
      "Crack Rail Fence Zig-Zag (2-16 rel) & Transposisi Kolom"
      "Kembali ke daftar kategori utama kriptografi"
    )
    local c
    c=$(menu_pick "KATEGORI II — CLASSICAL & POLYALPHABETIC CIPHERS" \
      "Auto-Crack Classical Cipher (All Engines + IoC)" \
      "Caesar / Shift Cipher (ROT1-25 / ROT13 / ROT47)" \
      "Affine Cipher Full Keyspace Cracker" \
      "Vigenere Polyalphabetic Auto-Key Cracker" \
      "Atbash Mirror & Reverse Substitution" \
      "Rail Fence & Transposition Cracker (2-16 Rails)" \
      "← Kembali ke Kategori") || return 0
    local sub="cat2"
    case "$c" in
      1) sub="cat2" ;;
      2) sub="caesar" ;;
      3) sub="affine" ;;
      4) sub="vigenere" ;;
      5) sub="atbash" ;;
      6) sub="rail" ;;
      *) return 0 ;;
    esac
    local tgt
    if tgt=$(input_file_path); then
      do_solve_file "$tgt" "$sub"
      press_enter
    fi
  done
}

menu_cat_xor() {
  while true; do
    banner
    MENU_DESC=(
      "Jalankan seluruh teknik XOR (Single-Byte + Repeating-Key + Known-Plaintext Crib)"
      "Bruteforce 256 kunci Single-Byte XOR (0x00-0xFF) pada file raw maupun hex"
      "Crack Repeating-Key XOR multi-byte dengan analisis frekuensi tiap kolom kunci"
      "Known-Plaintext / Crib-Drag XOR menggunakan header flag{, CTF{, minstrel{"
      "Kembali ke daftar kategori utama kriptografi"
    )
    local c
    c=$(menu_pick "KATEGORI III — XOR, STREAM & SYMMETRIC CIPHERS" \
      "Auto-Crack XOR & Stream Cipher (Full Suite)" \
      "Single-Byte XOR Bruteforce (256 Keys)" \
      "Repeating-Key Multi-Byte XOR Cracker" \
      "Known-Plaintext Crib XOR (flag{ / CTF{ / minstrel{)" \
      "← Kembali ke Kategori") || return 0
    local sub="cat3"
    case "$c" in
      1) sub="cat3" ;;
      2) sub="single" ;;
      3) sub="repeating" ;;
      4) sub="crib" ;;
      *) return 0 ;;
    esac
    local tgt
    if tgt=$(input_file_path); then
      do_solve_file "$tgt" "$sub"
      press_enter
    fi
  done
}

menu_cat_rsa() {
  while true; do
    banner
    MENU_DESC=(
      "Ekstrak otomatis (n, e, c, p, q, d) dari file & jalankan seluruh serangan matematika RSA"
      "Serangan Small Public Exponent (e=3 / e=5) dengan pencarian akar bulat (c + k*n)^(1/e)"
      "Faktorisasi Fermat untuk bilangan prima p dan q yang berdekatan (|p - q| kecil)"
      "Serangan pecahan berlanjut Wiener untuk Private Exponent kecil (d < 1/3 N^0.25)"
      "Faktorisasi Pollard's Rho (Brent) & dekripsi langsung jika p, q, atau d diketahui"
      "Kembali ke daftar kategori utama kriptografi"
    )
    local c
    c=$(menu_pick "KATEGORI IV — ASYMMETRIC & RSA PUBLIC-KEY SOLVER" \
      "Auto-Solve RSA Suite (All Mathematical Attacks)" \
      "Small Public Exponent Attack (e=3 / e=5 Root)" \
      "Fermat's Close-Primes Factorization Attack" \
      "Wiener's Continued Fractions Attack (Small d)" \
      "Pollard's Rho & Direct (p, q, d) Decryptor" \
      "← Kembali ke Kategori") || return 0
    case "$c" in
      1|2|3|4|5)
        local tgt
        if tgt=$(input_file_path); then
          do_solve_file "$tgt" "cat4"
          press_enter
        fi
        ;;
      *) return 0 ;;
    esac
  done
}

menu_cat_hash() {
  while true; do
    banner
    MENU_DESC=(
      "Deteksi otomatis tipe hash & crack via GPU Hashcat (-O -w 3) + Native Rule Engine"
      "Crack hash cepat: MD5 (-m 0), MD4 (-m 900), NTLM (-m 1000)"
      "Crack keluarga SHA: SHA-1, SHA-224, SHA-256, SHA-384, SHA-512, SHA3-256/512"
      "Crack hash lambat ber-salt via GPU Hashcat: bcrypt (-m 3200), sha512crypt (-m 1800)"
      "Kembali ke daftar kategori utama kriptografi"
    )
    local c
    c=$(menu_pick "KATEGORI V — HASH IDENTIFICATION & GPU CRACKING" \
      "Auto-Identify & GPU/CPU Crack Hash" \
      "Fast Hashes (MD5 / MD4 / NTLM)" \
      "SHA Family (SHA-1 / SHA-224 / SHA-256 / SHA-384 / SHA-512 / SHA3)" \
      "Salted & Slow KDF (bcrypt / sha512crypt / md5crypt)" \
      "← Kembali ke Kategori") || return 0
    case "$c" in
      1|2|3|4)
        local tgt
        if tgt=$(input_file_path); then
          do_solve_file "$tgt" "cat5"
          press_enter
        fi
        ;;
      *) return 0 ;;
    esac
  done
}

menu_categories() {
  while true; do
    banner
    MENU_DESC=(
      "Sub-menu: Base16/32/58/64/85, Hex, Binary, Octal, URL, HTML, Morse, Brainfuck, Zlib/Gzip"
      "Sub-menu: Caesar, ROT13/47, Affine, Vigenere, Atbash, Rail Fence & Transposition"
      "Sub-menu: Single-Byte XOR, Repeating-Key XOR, Known-Plaintext Crib & Stream Cipher"
      "Sub-menu: RSA Small-e, Fermat Factorization, Wiener Attack, Pollard Rho & Direct p/q/d"
      "Sub-menu: MD5, NTLM, SHA-1/256/512, SHA3, bcrypt & GPU-Accelerated Hashcat Engine"
      "Kembali ke menu utama Minstrel Graphi"
    )
    local c
    c=$(menu_pick "PILIH KATEGORI KRIPTOGRAFI UTAMA — MINSTREL GRAPHI" \
      "Kategori I   · Multi-Layer Encoding & Representation" \
      "Kategori II  · Classical & Polyalphabetic Ciphers" \
      "Kategori III · XOR, Stream & Symmetric Ciphers" \
      "Kategori IV  · Asymmetric & RSA Mathematical Solver" \
      "Kategori V   · Hash Identification & GPU Cracking" \
      "← Kembali ke Menu Utama") || return 0
    case "$c" in
      1) menu_cat_encoding ;;
      2) menu_cat_classical ;;
      3) menu_cat_xor ;;
      4) menu_cat_rsa ;;
      5) menu_cat_hash ;;
      *) return 0 ;;
    esac
  done
}

# ---------------- LINUX GPU STATUS & TUNING PANEL ----------------
view_gpu_status() {
  while true; do
    banner
    PRT=70
    pbox_top "${LG}STATUS DRIVER GPU LINUX & AKSELERASI HARDWARE${NC}" 74 >&2
    prow "" >&2
    prow "  ${DGN}Vendor Hardware :${NC} ${W}${GPU_VENDOR}${NC}" >&2
    prow "  ${DGN}Model Perangkat :${NC} ${G}${GPU_MODEL}${NC}" >&2
    prow "  ${DGN}Driver Kernel   :${NC} ${GRAY}${GPU_DRIVER}${NC}" >&2
    prow "  ${DGN}Backend Aktif   :${NC} ${CYN}${GPU_BACKEND}${NC}" >&2
    prow "  ${DGN}CPU SMP Threads :${NC} ${W}${CPU_CORES} Logical Cores${NC}" >&2
    prow "" >&2
    pbox_div 74 >&2

    local t st
    for t in nvidia-smi rocm-smi clinfo hashcat openssl python3; do
      if have "$t"; then
        st="${LG}INSTALLED & READY${NC}"
      else
        st="${MUTED}NOT FOUND (auto-fallback active)${NC}"
      fi
      prow "$(printf '  %-15s : %s' "${W}${t}${NC}" "$st")" >&2
    done
    prow "" >&2
    pbox_bottom 74 >&2
    printf '\n' >&2

    MENU_DESC=(
      "Profil seimbang untuk penggunaan standar (-w 2)"
      "Optimasi performa tinggi GPU CUDA/OpenCL (-O -w 3) — Rekomendasi Default"
      "Throughput GPU maksimum / Insane (-O -w 4)"
      "Matikan offload GPU dan paksa gunakan CPU Multi-Core Parallel"
      "Kembali ke menu utama Minstrel Graphi"
    )
    local c
    c=$(menu_pick "TUNING WORKLOAD GPU / CPU — MINSTREL GRAPHI" \
      "Set GPU Workload: Standard (-w 2)" \
      "Set GPU Workload: High-Performance (-O -w 3) [DEFAULT]" \
      "Set GPU Workload: Insane / Max Throughput (-O -w 4)" \
      "Force CPU Multi-Core Fallback Mode (Disable GPU)" \
      "← Kembali ke Menu Utama") || return 0
    case "$c" in
      1) GPU_WORKLOAD=2 ;;
      2) GPU_WORKLOAD=3 ;;
      3) GPU_WORKLOAD=4 ;;
      4) GPU_WORKLOAD=0 ;;
      *) return 0 ;;
    esac
  done
}

view_reports() {
  banner
  shopt -s nullglob
  local dirs=(minstrel_graphi_*/)
  shopt -u nullglob
  if (( ${#dirs[@]} == 0 )); then
    warn "Belum ada direktori hasil dekripsi (minstrel_graphi_<file>/)."
    press_enter
    return
  fi

  local opts=() d
  for d in "${dirs[@]}"; do opts+=("${d%/}"); done
  opts+=("← Kembali")

  local c
  c=$(menu_pick "RIWAYAT HASIL DEKRIPSI — MINSTREL GRAPHI" "${opts[@]}") || return
  (( c == ${#opts[@]} )) && return
  local chosen="${opts[$((c - 1))]}"

  banner
  row "LAPORAN: $chosen" "HASIL DEKRIPSI"
  sep
  if [[ -f "$chosen/plaintext.txt" ]]; then
    local pt_preview
    pt_preview=$(tr '\r\n' '  ' < "$chosen/plaintext.txt" | cut -c1-38)
    row "Plaintext Preview" "$pt_preview"
    row "Lokasi File Plaintext" "$chosen/plaintext.txt"
    row "Lokasi Laporan JSON" "$chosen/report.json"
  else
    row "Status" "Belum ada plaintext tersimpan"
  fi
  sep
  press_enter
}

view_info() {
  banner
  PRT=70
  pbox_top "${LG}DOKUMENTASI & ARSITEKTUR — MINSTREL GRAPHI${NC}" 74 >&2
  prow "" >&2
  prow "  ${W}Minstrel Graphi v${VERSION}${NC} ${GRAY}(Auto-Cryptanalysis & GPU Engine)${NC}" >&2
  prow "  ${GRAY}Cukup masukkan lokasi file — deteksi & dekripsi berjalan otomatis.${NC}" >&2
  prow "" >&2
  prow "  ${GRN}1. Auto-Scan${NC}      ${GRAY}Analisis Entropy, IoC, Magic Bytes, RSA & Hash ID${NC}" >&2
  prow "  ${GRN}2. 5 Kategori${NC}     ${GRAY}Encoding (25x), Classical, XOR, RSA Math & Hash${NC}" >&2
  prow "  ${GRN}3. Linux GPU${NC}      ${GRAY}Deteksi otomatis NVIDIA CUDA, AMD ROCm & OpenCL${NC}" >&2
  prow "  ${GRN}4. Zero-Crash${NC}     ${GRAY}Auto-fallback ke CPU Multi-Core jika tanpa GPU${NC}" >&2
  prow "" >&2
  pbox_div 74 >&2
  prow "  ${CYN}Auto Solve:${NC} ${W}minstrel-graphi -f <file>${NC}" >&2
  prow "  ${CYN}Scan Tipe:${NC}  ${W}minstrel-graphi -f <file> --scan${NC}" >&2
  prow "  ${CYN}Kategori:${NC}   ${W}minstrel-graphi -f <file> -m <auto|cat1..cat5>${NC}" >&2
  prow "" >&2
  pbox_bottom 74 >&2
  press_enter
}

# ---------------- MAIN INTERACTIVE LOOP ----------------
app_loop() {
  while true; do
    banner
    MENU_DESC=(
      "Masukkan lokasi file -> otomatis deteksi dan bobol berlapis sampai keluar Plaintext/Flag"
      "Pilih dari 5 Kategori Utama Kriptografi -> buka seluruh sub-kategori spesifik"
      "Scan tipe enkripsi/encoding/hash file (Entropy, IoC, Confidence & Rekomendasi)"
      "Lihat status driver GPU Linux (NVIDIA CUDA / AMD ROCm / OpenCL) & atur profil"
      "Lihat riwayat plaintext, flag, dan laporan JSON dari sesi sebelumnya"
      "Lihat dokumentasi arsitektur, daftar algoritma, dan contoh perintah CLI"
      "Keluar dari workspace Minstrel Graphi"
    )
    local c
    c=$(menu_pick "MENU UTAMA — MINSTREL GRAPHI" \
      "Auto-Solve File Kriptografi (1-Click Full Automatic)" \
      "Kategori Kriptografi (5 Kategori Utama & Sub-Menu)" \
      "Scan & Deteksi Tipe Enkripsi File (Crypto Scanner)" \
      "Status Driver GPU Linux & Akselerasi Hardware" \
      "Lihat Hasil & Laporan Dekripsi Terakhir" \
      "Info, Dokumentasi & Metodologi" \
      "Keluar") || c=7

    case "$c" in
      1)
        local tgt
        if tgt=$(input_file_path); then
          do_solve_file "$tgt" "auto"
          press_enter
        fi
        ;;
      2) menu_categories ;;
      3)
        do_scan_file ""
        press_enter
        ;;
      4) view_gpu_status ;;
      5) view_reports ;;
      6) view_info ;;
      ""|7|*)
        leave_tui
        printf '  %s✓%s %sSampai jumpa! [ MINSTREL GRAPHI v%s ]%s\n' "$LG" "$NC" "$W" "$VERSION" "$NC"
        exit 0
        ;;
    esac
  done
}

usage_cli() {
  banner
  PRT=70
  pbox_top "${LG}PENGGUNAAN CLI — MINSTREL GRAPHI${NC}" 74
  prow ""
  prow "  ${W}Interaktif (TUI):${NC}  ${LG}minstrel-graphi${NC}"
  prow "  ${W}1-Click Solve:${NC}     ${LG}minstrel-graphi -f <file_terenkripsi>${NC}"
  prow "  ${W}Scan Tipe File:${NC}    ${LG}minstrel-graphi -f <file_terenkripsi> --scan${NC}"
  prow ""
  prow "  ${DGN}-f <file>${NC}    ${GRAY}Lokasi file target (ciphertext / encoding / RSA / hash)${NC}"
  prow "  ${DGN}--scan${NC}       ${GRAY}Scan & identifikasi tipe kriptografi tanpa crack${NC}"
  prow "  ${DGN}-m <mode>${NC}    ${GRAY}auto | cat1(Encoding) | cat2(Classical) | cat3(XOR)${NC}"
  prow "               ${GRAY}cat4(RSA) | cat5(Hash) | caesar | vigenere | affine${NC}"
  prow "  ${DGN}-w <file>${NC}    ${GRAY}Custom wordlist untuk Hash / Key cracking${NC}"
  prow "  ${DGN}--gpu-status${NC} ${GRAY}Tampilkan diagnostik driver GPU Linux (CUDA/ROCm/OpenCL)${NC}"
  prow "  ${DGN}--cpu${NC}        ${GRAY}Paksa mode CPU Multi-Core (matikan offload GPU)${NC}"
  prow "  ${DGN}-o <dir>${NC}     ${GRAY}Direktori output hasil dekripsi & report.json${NC}"
  prow ""
  pbox_bottom 74
}

cleanup() {
  [[ -n "${TMP_WORDLIST:-}" && -f "${TMP_WORDLIST:-}" ]] && rm -f "$TMP_WORDLIST"
  leave_tui
}
trap cleanup EXIT INT TERM

# ---------------- CLI ARGUMENT PARSER & ENTRYPOINT ----------------
if (( $# > 0 )); then
  CLI_ACTION="solve"
  while (( $# > 0 )); do
    case "$1" in
      -f|--file) TARGET_FILE="${2:-}"; shift ;;
      -m|--mode) CIPHER_HINT="${2:-auto}"; shift ;;
      -w|--wordlist) CUSTOM_WORDLIST="${2:-}"; shift ;;
      -o|--output) CLI_OUTDIR="${2:-}"; shift ;;
      --scan|-s) CLI_ACTION="scan" ;;
      --gpu-status)
        detect_linux_gpu
        banner
        row "GPU PARAMETER" "DETECTED LINUX HARDWARE STATUS"
        sep
        row "GPU Vendor" "$GPU_VENDOR"
        row "Device Model" "$GPU_MODEL"
        row "Kernel / ICD Driver" "$GPU_DRIVER"
        row "Acceleration Backend" "$GPU_BACKEND"
        row "CPU Logical Cores" "$CPU_CORES Cores"
        sep
        exit 0
        ;;
      --cpu) GPU_WORKLOAD=0 ;;
      -v|--version) printf 'Minstrel Graphi v%s (Minstrel Framework)\n' "$VERSION"; exit 0 ;;
      -h|--help) usage_cli; exit 0 ;;
      *)
        if [[ -z "$TARGET_FILE" && -f "$1" ]]; then
          TARGET_FILE="$1"
        else
          usage_cli >&2
          exit 1
        fi
        ;;
    esac
    shift
  done

  if [[ -z "$TARGET_FILE" ]]; then
    usage_cli >&2
    exit 1
  fi

  detect_linux_gpu
  if [[ "$CLI_ACTION" == "scan" ]]; then
    do_scan_file "$TARGET_FILE"
  else
    do_solve_file "$TARGET_FILE" "$CIPHER_HINT"
  fi
else
  enter_tui
  app_loop
fi
