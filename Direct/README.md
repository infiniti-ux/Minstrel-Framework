# Minstrel Direct — Enterprise Web Content Discovery, Smart Proxy/TOR & CVE Engine

<p align="center">
  <img src="https://img.shields.io/badge/Version-2.1.0-brightgreen?style=for-the-badge">
  <img src="https://img.shields.io/badge/Framework-Minstrel-00d787?style=for-the-badge">
  <img src="https://img.shields.io/badge/Bash-5.0%2B-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white">
  <img src="https://img.shields.io/badge/Routing-Smart%20Proxy%20%2B%20TOR%20SOCKS5h-7D4698?style=for-the-badge&logo=tor-project&logoColor=white">
  <img src="https://img.shields.io/badge/CVE%20Coverage-2024--2026%20%2F%20CISA%20KEV-red?style=for-the-badge">
</p>

**Minstrel Direct** adalah modul *Enterprise Web Content Discovery*, *Smart Auto-Proxy / TOR Stealth Routing*, dan *Active CVE Endpoint Audit* dari ekosistem **Minstrel Penetration Testing Framework**. Tool ini menyatukan dan mengoptimalkan arsitektur ganda terdahulu (*Smart Engine* + *Full TOR Stealth*) ke dalam satu *engine* terpadu berkinerja tinggi dengan antarmuka TUI 72 kolom bebas kedip (*flicker-free*).

---

## Mandatory Notice for TOR Stealth Mode (English)

> **WARNING — MANDATORY REQUIREMENTS FOR TOR STEALTH MODE:**
> - **You MUST be connected to the Internet** (`An active Internet connection is REQUIRED to establish TOR circuits`).
> - **You MUST have `tor` installed and running on your system** (`127.0.0.1:9050`).
> - Before activating TOR Stealth Mode (`--tor`, `-t 0`, or `./minstrel-direct.sh 0`), **Minstrel Direct** automatically verifies:
>   1. The `tor` binary is installed (`sudo apt update && sudo apt install -y tor proxychains4`).
>   2. An active Internet connection is reachable.
>   3. The TOR SOCKS5 daemon is listening on `127.0.0.1:9050` (using `socks5h://127.0.0.1:9050` for full **DNS Leak Protection**).
>   4. Your anonymized TOR Exit Node IP via `https://check.torproject.org/api/ip`.

---

## Fitur Utama & Pembaruan Enterprise (v2.1.0)

### 1. Unified Smart Auto-Proxy & Full TOR Stealth Engine
- **Smart Auto-Proxy Mode (Default):** Melakukan pemindaian kecepatan tinggi secara langsung (*Direct High-Speed*) dan memantau respons HTTP target. Apabila terdeteksi pemblokiran WAF / *Rate-Limit* (`HTTP 403`, `429`, atau `503`), engine secara otomatis melakukan *failover* dan mengalihkan seluruh trafik melalui jaringan **TOR SOCKS5h (`127.0.0.1:9050`)**.
- **Full TOR Stealth Mode (`--tor` / Mode `0`):** Memaksa seluruh proses *fuzzing*, *directory bruteforce*, dan audit CVE berjalan 100% di balik *tunnel* `socks5h://127.0.0.1:9050` serta pembungkus `proxychains4 -q` / `torsocks`.

### 2. Soft-404 Canary Auto-Calibration & Batched Connection-Reuse
- **Anti False-Positive (Soft-404 Calibration):** Melakukan *pre-flight canary probe* (`/.minstrel-canary-<random>`) untuk mendeteksi website modern / SPA yang mengembalikan `HTTP 200 OK` pada seluruh URL tidak valid, lalu otomatis mengecualikan ukuran *byte* tersebut pada **FFUF** (`-ac`), **Gobuster** (`--exclude-length`), maupun **Native Fuzzer**.
- **Batched Keep-Alive Workers:** Engine internal menggunakan *connection reuse* (`--keepalive-time 30`) secara paralel tanpa mem-*fork* proses baru untuk setiap baris wordlist, mampu memindai 125+ *endpoint* + 25+ *probe* CVE hanya dalam **~2.5 detik**.

### 3. Enterprise CVE, CISA KEV & Modern API Security Audit (2024–2026)
- **Active CVE & Exposure Probes (Body-Verified):**
  - `CVE-2025-29927` — Next.js Middleware Authorization Bypass (`x-middleware-subrequest`)
  - `CVE-2024-4577` — PHP-CGI Argument Injection RCE
  - `CVE-2024-38476` — Apache HTTP Server `< 2.4.62` Backend Output Handling
  - `CVE-2024-27198` — JetBrains TeamCity Authentication Bypass (`/app/rest/server`)
  - `CVE-2023-46805` — Ivanti Connect Secure Authentication Bypass
  - `CVE-2021-41773 / 42013` — Apache `2.4.49 / 2.4.50` Path Traversal & RCE
- **Cloud, DevSecOps & API Security Checks:**
  - **CORS Reflection Audit (`CWE-942`):** Menguji refleksi `Origin: https://evil.minstrel.invalid` beserta `Access-Control-Allow-Credentials: true`.
  - **GraphQL Introspection Check:** Menguji kebocoran skema `__schema` pada `/graphql`.
  - **Sensitive Secrets & Actuator:** `/.env`, `/.env.production`, `/.git/HEAD`, `/.aws/credentials`, `/actuator/env`, `/actuator/mappings`, `/swagger.json`, `/openapi.json`, `/docker-compose.yml`, `/debug/pprof/`.
  - **Nuclei v3 Integration:** Otomatis menjalankan template `cve,kev,exposures,misconfig,takeover,panel,default-login` jika `nuclei` terinstal.

---

## Persyaratan Sistem (Dependencies)

Instal seluruh dependensi pada distribusi berbasis Debian / Ubuntu / Kali Linux:

```bash
sudo apt update && sudo apt install -y curl tor proxychains4 ffuf gobuster dirb nikto nuclei jq
sudo systemctl enable --now tor
