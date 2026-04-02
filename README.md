# Colpress v1.0 — Portable Windows Toolkit

> No install. No admin required. USB-ready. Just unzip and double-click `colpress.bat`.

---

## Quick Start

```
Colpress\
    colpress.bat         ← double-click this
    colpress-dupe.bat
    colpress-wipe.bat
    README.md
    tools\
        b3sum.exe
        cavif.exe
        innoextract.exe
        sdelete64.exe
        7za.exe
```

1. Download and unzip `Colpress.zip`
2. Double-click `colpress.bat`
3. Pick a tool from the menu

---

## Tools

### [1] b3sum — BLAKE3 Checksum
Hash files with BLAKE3, the fastest modern cryptographic hash.

```
b3sum file.exe
b3sum --check checksums.b3
```

### [2] cavif — Image to AVIF Converter
Convert PNG/JPEG to AVIF — smaller than WebP at the same quality.

```
cavif -Q 80 photo.png
cavif --overwrite *.jpg
```

### [3] dupefind — Duplicate File Finder ⚡
Built-in, **no exe required**. Uses a 3-phase algorithm to minimise disk I/O:

| Phase | Method | Purpose |
|-------|--------|---------|
| 1 | Exact size grouping | Zero I/O — filters unique sizes instantly |
| 2 | Head hash (64 KB, JScript FNV) | Filters ~95% of non-dupes |
| 3 | Full hash (BLAKE3 / SHA-256 / FNV) | Zero false positives |

**Hash engine priority (v2.0):**
1. **BLAKE3** via `tools\b3sum.exe` — primary, ~3× faster than SHA-256
2. **SHA-256** via `certutil` — built into Windows 7+
3. **JScript FNV-1a** — XP fallback, no dependencies

**v2.0 new features:**
- `/virus` — computes SHA-256 per group and prints a direct VirusTotal URL (no copy/paste)
- `/export:out.html` — clickable HTML report with VT links for each duplicate group
- Small-file optimisation: files ≤ 64 KB are fully read in Phase 2; Phase 3 reuses that result with no second disk read

```bat
colpress-dupe.bat D:\Photos
colpress-dupe.bat D:\ /min:1048576 /export:C:\dupes.csv
colpress-dupe.bat D:\ /export:C:\dupes.html
colpress-dupe.bat C:\Downloads /delete
colpress-dupe.bat C:\Downloads /virus
```

### [4] innoextract — Inno Setup Unpacker
Unpack Inno Setup `.exe` installers without running them.

```
innoextract setup.exe
innoextract -d out\ setup.exe
innoextract -l setup.exe   # list contents only
```

### [5] sdelete64 — Secure File Erasure (Sysinternals)
Sysinternals-grade secure deletion. Kept as a robust exe fallback.

```
sdelete64 -p 1 file.txt    # 1 pass
sdelete64 -p 7 file.txt    # 7 passes (DoD-style)
sdelete64 -z D:            # wipe free space
```

### [6] 7za — 7-Zip Command-Line
Full 7-Zip archiver: extract, compress, list, test.

```
7za x archive.7z
7za a -t7z  out.7z  folder\
7za a -tzip out.zip file
7za l archive.zip
7za t archive.7z
```

### [7] colpress-wipe — Secure Erase (no exe)
Multi-pass file overwrite using PowerShell `.NET` streaming. No exe needed.

- Pass pattern: `0x00` → `0xFF` → random (RNGCryptoServiceProvider), cycling
- Free-space wipe via `cipher /w:` (built-in since Windows XP)
- Equivalent to sdelete64 at the file level

```bat
colpress-wipe.bat file.txt           # 3-pass wipe
colpress-wipe.bat file.txt /p:7      # 7-pass
colpress-wipe.bat dir\ /s            # recursive
colpress-wipe.bat C: /z              # wipe free space
```

> **SSD note:** File-level overwrite tools (including sdelete64) cannot guarantee physical erasure on SSDs due to wear-levelling. For maximum assurance on SSDs, use ATA Secure Erase (drive firmware) or full-disk encryption.

---

## [V] VirusTotal Integration

| Option | What it does |
|--------|-------------|
| Hash (SHA-256) + open VT directly | Computes SHA-256, opens `virustotal.com/gui/file/<hash>` — exact result, no copy/paste |
| Hash (BLAKE3) + open VT search | BLAKE3 for speed; opens VT search page (paste hash) |
| Batch scan directory → HTML | Hashes every file with SHA-256, saves a dark-themed HTML with a clickable VT link per file |
| Upload to VT | Opens VT upload page in browser (max 650 MB) |

The **batch HTML scan** (`[V] > [3]`) is great for auditing a Downloads folder — open one report, click individual results. No repeated typing.

---

## Requirements

| Feature | Requirement |
|---------|-------------|
| All tools | Windows 7+ (64-bit recommended) |
| dupefind BLAKE3 engine | `tools\b3sum.exe` present (included) |
| dupefind SHA-256 engine | Windows 7+ (certutil built-in) |
| colpress-wipe | Windows 10+ / PowerShell 5.1+ |
| VirusTotal direct link | Windows 7+ (certutil for SHA-256) |
| Free-space wipe | Any Windows (cipher /w: built-in) |

---

## Performance Notes

- **dupefind on 100,000 files:** Phase 1 (size grouping) runs in under 1 second.
  Phase 3 with BLAKE3 is roughly 3× faster than SHA-256 on modern CPUs.
- **cavif batch conversion:** Recursive by default; handles nested directories.
- **colpress-wipe:** Speed is limited by disk write throughput, same as sdelete64.

---

## File Size Comparison vs v1.2

| Removed | Saved |
|---------|-------|
| `hashfile.bat` | ~4 KB — SHA-256/MD5/SHA-512 via certutil; covered by VT menu + b3sum |

All `.exe` files are unchanged.

---

## License

MIT. Tools in `tools\` are subject to their own licenses:
- **b3sum** — Apache 2.0 / MIT ([github.com/BLAKE3-team/BLAKE3](https://github.com/BLAKE3-team/BLAKE3))
- **cavif** — MIT ([github.com/kornelski/cavif-rs](https://github.com/kornelski/cavif-rs))
- **innoextract** — zlib ([constexpr.at/innoextract](https://constexpr.at/innoextract/))
- **sdelete64** — Sysinternals EULA ([learn.microsoft.com](https://learn.microsoft.com/en-us/sysinternals/downloads/sdelete))
- **7za** — LGPL + unRAR ([7-zip.org](https://www.7-zip.org/))
