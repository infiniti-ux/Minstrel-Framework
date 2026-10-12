# Minstrel Graphi — Auto-Cryptanalysis & Linux GPU Acceleration Engine

<p align="center">
  <img src="https://img.shields.io/badge/Version-2.1.0-brightgreen?style=for-the-badge">
  <img src="https://img.shields.io/badge/Framework-Minstrel-00d787?style=for-the-badge">
  <img src="https://img.shields.io/badge/Engine-Bash%20%2B%20Python3%20%2B%20GPU-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white">
  <img src="https://img.shields.io/badge/GPU%20Backend-NVIDIA%20CUDA%20%7C%20AMD%20ROCm%20%7C%20OpenCL-76B900?style=for-the-badge&logo=nvidia&logoColor=white">
  <img src="https://img.shields.io/badge/Categories-5%20Major%20%7C%2030%2B%20Sub--Engines-00bfff?style=for-the-badge">
</p>

**Minstrel Graphi** adalah modul *Auto-Cryptanalysis*, *Deep Crypto File Scanner*, dan *Linux GPU-Accelerated Cracking* dari ekosistem **Minstrel Penetration Testing Framework**. Cukup berikan lokasi file terenkripsi, *ciphertext*, parameter RSA, atau *hash* — **Minstrel Graphi** akan memindai struktur statistiknya, memilih algoritma pembobol yang tepat, dan mengupas enkripsi berlapis secara otomatis hingga mengeluarkan *Plaintext / Flag*.

---

## Fitur Utama & Keunggulan Arsitektur (v2.1.0)

### 1. 1-Click Auto-Solve (`minstrel-graphi -f <lokasi_file>`)
- Cukup berikan lokasi file (atau *drag-and-drop* path file ke dalam kotak input TUI / pilih dengan `?`).
- Mesin *Recursive Best-First Search (BFS)* otomatis mengupas hingga **25 lapis** kombinasi *encoding*, kompresi, sandi klasik, XOR, matematika RSA, maupun *hash*.

### 2. Menu Kategori Kriptografi & Sub-Kategori Lengkap di TUI
Klik **[02] Kategori Kriptografi** pada menu utama untuk membuka 5 kategori utama beserta seluruh sub-kategorinya:
- **Kategori I · Multi-Layer Encoding & Representation**
  - Auto-Solve Multi-Layer Encoding (Recursive 25x)
  - Base Family (`Base16`, `Base32`, `Base58`, `Base64`, `Base64URL`, `Base85`, `Ascii85`)
  - Radix & Numeric (`Hexadecimal`, `Binary 8-bit`, `Octal`, `Decimal ASCII`, `A1Z26`)
  - Web & Transport (`URL Percent-Encoding`, `HTML Entities`)
  - Esoteric & Signal (`International Morse Code`, `Baconian 5-bit`, `Brainfuck Interpreter`)
  - Compressed Stream (`Gzip`, `Zlib`, `Bzip2`, `XZ / LZMA`)
- **Kategori II · Classical & Polyalphabetic Ciphers**
  - Auto-Crack Classical Cipher (*Chi-Squared* + *Index of Coincidence*)
  - Caesar / Shift Cipher (`ROT1–25`, `ROT13`, `ROT47`)
  - Affine Cipher Full Keyspace Cracker ($E(x) = (ax + b) \bmod 26$, 312 kunci)
  - Vigenère Polyalphabetic Auto-Key Cracker (deteksi panjang kunci & frekuensi kolom otomatis)
  - Atbash Mirror & Reverse Substitution
  - Rail Fence Zig-Zag (`2–16 Rails`) & Transposition Cracker
- **Kategori III · XOR, Stream & Symmetric Ciphers**
  - Auto-Crack XOR & Stream Cipher (Full Suite)
  - Single-Byte XOR Bruteforce (`256 Keys`, mendukung input *raw* maupun *hex*)
  - Repeating-Key Multi-Byte XOR Cracker (analisis frekuensi per kolom byte)
  - Known-Plaintext / Crib-Drag XOR (`flag{`, `CTF{`, `minstrel{`)
- **Kategori IV · Asymmetric & RSA Mathematical Solver**
  - Auto-Solve RSA Suite (otomatis mengekstrak `n, e, c, p, q, d, dp, dq` desimal maupun `0x` hex)
  - Small Public Exponent Attack ($e=3 / e=5$ *Exact Integer Root* $\sqrt[e]{c + k \cdot n}$)
  - Fermat's Close-Primes Factorization Attack ($|p - q|$ berdekatan)
  - Wiener's Continued Fractions Attack ($d < \frac{1}{3}N^{1/4}$)
  - Pollard's Rho (Brent) Factorization & Direct $(p, q, d)$ Decryptor
- **Kategori V · Hash Identification & GPU Cracking**
  - Auto-Identify & GPU/CPU Crack Hash (`Hashcat -O -w 3` + *Native Multi-Mutation Engine*)
  - Fast Hashes (`MD5`, `MD4`, `NTLM`)
  - SHA Family (`SHA-1`, `SHA-224`, `SHA-256`, `SHA-384`, `SHA-512`, `SHA3-224/256/384/512`)
  - Salted & Slow KDF (`bcrypt`, `sha512crypt`, `md5crypt`, `Argon2`)

### 3. Deep Crypto Scanner (`[03] Scan & Deteksi Tipe Enkripsi File` / `--scan`)
- Menghitung **Shannon Entropy** ($0.00 - 8.00$ bits/byte), **Index of Coincidence (IoC)**, rasio **Printable ASCII**, **Magic Bytes**, **Hashcat Mode ID (`-m`)**, serta daftar kandidat tipe enkripsi lengkap dengan persentase *Confidence* dan tombol tindak lanjut **1-Click Langsung Auto-Solve**.

### 4. Optimasi Driver GPU Linux Otomatis (`[04] Status Driver GPU Linux` / `--gpu-status`)
- Mendeteksi secara otomatis ketersediaan driver GPU Linux:
  - **NVIDIA CUDA / NVML** (`nvidia-smi` — nama GPU, versi driver, kapasitas VRAM)
  - **AMD ROCm / AMDGPU** (`rocm-smi` / `rocminfo`)
  - **Intel / Mesa OpenCL ICD** (`clinfo` & `/dev/dri/renderD128`)
- Mengatur profil *workload* **Hashcat** (`-O -w 2`, `-O -w 3 High-Performance`, `-O -w 4 Insane`) dan otomatis melakukan **Zero-Crash Fallback ke CPU Multi-Core SMP** jika dijalankan pada mesin tanpa GPU diskrit.

---

## Persyaratan Sistem (Dependencies)

```bash
# Debian / Ubuntu / Kali Linux
sudo apt update && sudo apt install -y python3 openssl hashcat clinfo
```

---

## Struktur Direktori

```text
MinstrelGraphi/
├── minstrel-graphi.sh              # Script utama Minstrel Graphi (TUI & CLI)
├── main/
│   └── minstrel-graphi.sh          # Salinan modul utama
├── setup/
│   └── setup-minstrel-graphi.sh    # Installer symlink ke /usr/local/bin/minstrel-graphi
├── wordlists/
│   └── minstrel-passwords.txt      # Wordlist bawaan untuk Hash & Key Cracking
└── README.md                       # Dokumentasi resmi Minstrel Graphi
```

---

## Instalasi

```bash
chmod +x minstrel-graphi.sh setup/setup-minstrel-graphi.sh
./setup/setup-minstrel-graphi.sh
```

---

## Panduan Penggunaan (TUI & CLI)

### 1. Mode Interaktif (Full-Screen TUI)
```bash
./minstrel-graphi.sh
# atau setelah menjalankan setup:
minstrel-graphi
```

### 2. Mode Baris Perintah (1-Click CLI)
```bash
# 1. Auto-Solve: tinggal berikan lokasi file, langsung didekripsi otomatis!
./minstrel-graphi.sh -f ./secret_cipher.txt

# 2. Scan Tipe Kriptografi File (Entropy, IoC, Confidence & Rekomendasi Kategori)
./minstrel-graphi.sh -f ./mystery.bin --scan

# 3. Cek Status Driver GPU Linux & Akselerasi Hardware
./minstrel-graphi.sh --gpu-status

# 4. Solve dengan Kategori Spesifik & Custom Wordlist
./minstrel-graphi.sh -f ./rsa_challenge.txt -m cat4
./minstrel-graphi.sh -f ./hashes.txt -m cat5 -w /usr/share/wordlists/rockyou.txt -o ./hasil_crack
```

---

## Daftar Flag & Opsi CLI

| Flag | Argumen | Deskripsi |
| :--- | :--- | :--- |
| `-f`, `--file` | `<path>` | Lokasi file target terenkripsi / *ciphertext* / *hash* / parameter RSA |
| `--scan`, `-s` | *(tanpa arg)* | Pindai & identifikasi jenis kriptografi file beserta *Entropy* & *IoC* |
| `-m`, `--mode` | `<mode>` | `auto` (default) · `cat1` (Encoding) · `cat2` (Classical) · `cat3` (XOR) · `cat4` (RSA) · `cat5` (Hash) · `caesar` · `vigenere` · `affine` · `rail` |
| `-w`, `--wordlist` | `<path>` | Gunakan file *custom wordlist* untuk *Hash / Key cracking* |
| `--gpu-status` | *(tanpa arg)* | Tampilkan diagnostik driver GPU Linux (`NVIDIA CUDA`, `AMD ROCm`, `OpenCL`, `CPU SMP`) |
| `--cpu` | *(tanpa arg)* | Paksa gunakan mode **CPU Multi-Core Fallback** (matikan offload GPU) |
| `-o`, `--output` | `<folder>` | Direktori penyimpanan hasil (`plaintext.txt` & `report.json`) |
| `-v`, `--version` | *(tanpa arg)* | Tampilkan versi **Minstrel Graphi** |
| `-h`, `--help` | *(tanpa arg)* | Tampilkan panel bantuan CLI |
