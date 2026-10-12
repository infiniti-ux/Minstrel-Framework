# Minstrel Recon (Minstrel Reconnaisance)

**Surface & CVE Intelligence Automation Module** untuk **Minstrel Framework** — cepat, senyap, ringan, reliabel.  
**v2.0.0 — Dedicated TUI Workspace & Modern CVE Engine**

```text
          ░█▄█░▀█▀░█▀█░█▀▀░▀█▀░█▀▄░█▀▀░█░░░░░█▀▄░█▀▀░█▀▀░█▀█░█▀█
          ░█░█░░█░░█░█░▀▀█░░█░░█▀▄░█▀▀░█░░░░░█▀▄░█▀▀░█░░░█░█░█░█
          ░▀░▀░▀▀▀░▀░▀░▀▀▀░░▀░░▀░▀░▀▀▀░▀▀▀░░░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀░▀
```

---

## Fitur Utama (v2.0.0)

1. **Dedicated Full-Screen TUI Workspace (`\033[?1049h`)**
   - Saat dijalankan tanpa argumen, **Minstrel Recon** langsung masuk ke antarmuka terminal khususnya sendiri (*Alternate Screen Buffer*) dengan kursor tersembunyi, status bar engine *real-time*, dan kembali bersih ke terminal awal saat keluar.
   - Navigasi responsif menggunakan **panah `↑`/`↓`**, **vim keys `j`/`k`**, **angka langsung `1`–`7`**, **`ENTER`**, atau **`q`** untuk kembali/keluar.
   - Dilengkapi **Contextual Description Footer** di setiap menu serta **Interactive Report Inspector** untuk menelusuri hasil *Ports*, *Subdomains*, *Tech Stack*, dan *CVE Findings* langsung di dalam UI.

2. **Pembaruan Teknik Recon & Audit CVE Terkini (2025/2026)**
   - **Port & Service Discovery Adaptif:** Mendeteksi hak akses secara otomatis (`-sS` TCP SYN Stealth saat `root`, atau fallback otomatis ke `-sT` TCP Connect saat *unprivileged*), dilengkapi deteksi versi ringan (`-sV --version-light`), NSE script (`banner,http-title,ssl-cert`), serta *built-in TCP socket scanner* jika `nmap` belum terpasang.
   - **Subdomain & Certificate Transparency (CT) OSINT:** Menggabungkan enumerasi pasif `subfinder -all` dengan kueri langsung ke log Certificate Transparency **`crt.sh`** serta deduplikasi dan sanitasi wildcard.
   - **Multi-Scheme HTTP/TLS Probe & Security Headers Audit:** Melakukan *probing* paralel dengan *fallback* otomatis `https://` ke `http://`, mendeteksi *technology stack* (`whatweb -a 1`), mengidentifikasi **WAF/CDN** (Cloudflare, CloudFront, Vercel, Fastly), dan mengaudit **Missing Security Headers** (`HSTS`, `CSP`, `X-Frame-Options`, `X-Content-Type-Options`).
   - **Modern CVE & CISA KEV Scanning:** Menggunakan sintaks terbaru **Nuclei v3** (`-tags cve,kev,misconfig,exposure,takeover,panel,default-login -nc -silent`) ditambah *built-in Passive CVE & Exposure Verifier* (mendeteksi pola CVE kritis seperti OpenSSH *regreSSHion* `CVE-2024-6387`, Apache `CVE-2021-41773` / `CVE-2024-38476`, Nginx advisories `CVE-2024-7347`, Next.js `CVE-2025-29927`, serta verifikasi ketat eksposur `.git/HEAD` dan `.env`).

3. **Optimisasi Kode & Performa**
   - Kalkulasi panjang string ANSI dan *box rendering* **zero-subshell** menggunakan *parameter expansion* murni Bash (`extglob`) dan *pre-computed buffer*.
   - Mode terminal `stty -icanon -echo` (*cbreak*) menggantikan `stty raw` sehingga output baris baru (`\n`) dan sinyal interupsi (`SIGINT`) tetap presisi.
   - Validasi ketat domain RFC-1123 dan batas oktet IPv4 (`0–255`).

---

## Instalasi & Penggunaan (Interaktif TUI)

```bash
sudo chmod +x MinstrelRecon/minstrel-recon.sh
sudo ln -sf "$(pwd)/MinstrelRecon/minstrel-recon.sh" /usr/local/bin/minstrel-recon

minstrel-recon
```

Jalankan `minstrel-recon` tanpa argumen untuk langsung masuk ke **TUI Workspace**:
- **Menu Utama:**
  1. `Jalankan Recon (Wizard Interaktif)` — Pilih Mode → Pilih Profil Kecepatan → Input Target → Konfirmasi → Eksekusi
  2. `Lihat Hasil & Laporan Terakhir` — Inspeksi interaktif `report.json`, tabel Port, Subdomain, Tech Stack & CVE
  3. `Diagnostik Engine & Update CVE` — Cek kesiapan `nmap`, `subfinder`, `whatweb`, `nuclei`, `curl`, `jq` & update template CVE (`nuclei -ut`)
  4. `Info, Dokumentasi & Metodologi`
  5. `Keluar`

---

## Penggunaan CLI (Otomasi & Backward Compatible)

```bash
minstrel-recon -i <target> -t <I-VI> [-s <I-V>] [-u]
```

- `-i <target>` : Domain (`example.com`) atau IPv4 (`203.0.113.10`) — URL penuh otomatis dinormalisasi
- `-t <mode>` :
  - `I` / `1` / `ports` — Port & Service Discovery
  - `II` / `2` / `subs` — Subdomain & CT Enumeration
  - `III` / `3` / `tech` — Tech & Security Header Audit
  - `IV` / `4` / `vulns` — CVE & Vulnerability Scan
  - `V` / `5` / `auto` — Auto-Pipeline (Full Suite)
  - `VI` / `6` / `cve` — Critical CVE & CISA KEV Focus
- `-s <speed>` : `I` Paranoid | `II` Stealth | `III` Normal | `IV` Aggressive | `V` Insane
- `-u` : Perbarui template CVE Nuclei (`nuclei -ut`) sebelum pemindaian
- `-v` : Tampilkan versi
- `-h` : Tampilkan bantuan CLI

---

## Environment Variables

- `MINSTREL_RECON_DRY=1` — Mode *dry-run* (tampilkan perintah tanpa eksekusi jaringan)
- `MINSTREL_RECON_QUIET=1` — Mode senyap (output hanya disimpan ke file laporan)
- `MINSTREL_RECON_UPDATE_TEMPLATES=1` — Otomatis jalankan `nuclei -ut` saat pemeriksaan dependensi

Hasil disimpan di `minstrel_recon_<target>/` mencakup **`report.json`** (dengan rincian tingkat keparahan CVE) dan **`report.md`**.
