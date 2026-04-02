@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

:: ================================================================
::  COLPRESS  v2.0  |  Portable Windows Toolkit
::  No install. No admin. USB-ready. Click colpress.bat to start.
::
::  Layout:
::    Colpress\
::        colpress.bat         <- this launcher
::        colpress-dupe.bat    <- duplicate finder  (BLAKE3 engine)
::        colpress-wipe.bat    <- secure erasure    (no exe needed)
::        README.md
::        tools\
::            b3sum.exe        BLAKE3 hasher (fastest hash available)
::            cavif.exe        AVIF image converter
::            innoextract.exe  Inno Setup unpacker
::            sdelete64.exe    Sysinternals secure erase (exe fallback)
::            7za.exe          7-Zip command-line
::
::  Changes vs PortableToolkit v1.2:
::    NEW  Rebranded as Colpress v2.0
::    NEW  colpress-dupe.bat: BLAKE3 Phase-3 engine (b3sum, 3x faster)
::    NEW  colpress-dupe.bat: /virus flag — SHA-256 + VT links per group
::    NEW  colpress-dupe.bat: small-file opt — skips re-read for <=64KB files
::    NEW  colpress-dupe.bat: HTML export (auto-detected from .html extension)
::    NEW  VT menu: SHA-256 direct link (opens exact VT result, no copy/paste)
::    NEW  VT menu: batch scan a directory -> clickable HTML report
::    REM  hashfile.bat removed (b3sum covers BLAKE3; certutil covers SHA-*)
::    FIX  CHOICE key list corrected (V was duplicated in v1.2, breaking Q=11)
:: ================================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "T=%ROOT%\tools"
set "DF=%ROOT%\colpress-dupe.bat"
set "SW=%ROOT%\colpress-wipe.bat"

title  COLPRESS  v2.0  ^|  Portable Windows Toolkit

:MAIN
cls
echo.
echo  +=========================================================+
echo  ^|            C O L P R E S S   v2.0                     ^|
echo  ^|               Portable Windows Toolkit                 ^|
echo  +=========================================================+
echo  ^|  [1]  b3sum        BLAKE3 file checksum                ^|
echo  ^|  [2]  cavif        Convert images to AVIF              ^|
echo  ^|  [3]  dupefind     Find/remove duplicate files         ^|
echo  ^|  [4]  innoextract  Unpack Inno Setup installers        ^|
echo  ^|  [5]  sdelete64    Secure file erasure (Sysinternals)  ^|
echo  ^|  [6]  7za          7-Zip command-line archiver         ^|
echo  ^|  [7]  securewipe   Secure erase, no exe (built-in)     ^|
echo  ^|---------------------------------------------------------^|
echo  ^|  [V]  VirusTotal   Hash + direct online virus scan     ^|
echo  ^|  [H]  Help         Quick reference for all tools       ^|
echo  ^|  [Q]  Quit                                             ^|
echo  +=========================================================+
echo.
choice /c 1234567VHQ /n /m "  Enter option: "
set "OPT=!errorlevel!"

if "!OPT!"=="10" goto :EXIT
if "!OPT!"=="9"  goto :HELP
if "!OPT!"=="8"  goto :MENU_VT
if "!OPT!"=="7"  goto :MENU_SW
if "!OPT!"=="6"  goto :MENU_7ZA
if "!OPT!"=="5"  goto :MENU_SDEL
if "!OPT!"=="4"  goto :MENU_INNO
if "!OPT!"=="3"  goto :MENU_DUPE
if "!OPT!"=="2"  goto :MENU_CAVIF
if "!OPT!"=="1"  goto :MENU_B3SUM
goto :MAIN


:: ================================================================
:MENU_B3SUM
:: ================================================================
cls
echo.
echo  +-- b3sum  BLAKE3 Checksum ------------------------------------+
echo  ^|  Fastest cryptographic hash. Great for integrity checks.    ^|
echo  ^|  [1] Hash a single file                                     ^|
echo  ^|  [2] Hash all files in a directory (recursive)              ^|
echo  ^|  [3] Verify a checksum list (*.b3)                          ^|
echo  ^|  [4] Custom command                                          ^|
echo  ^|  [0] Back                                                    ^|
echo  +--------------------------------------------------------------+
echo.
choice /c 01234 /n /m "  Option: "
set "B3C=!errorlevel!"
if "!B3C!"=="1" goto :MAIN

if "!B3C!"=="2" (
    set /p "ARG=  Drag in or type file path: "
    echo.
    "%T%\b3sum.exe" "!ARG!"
    goto :PAUSE_BACK
)
if "!B3C!"=="3" (
    set /p "ARG=  Drag in or type directory path: "
    echo.
    for /r "!ARG!" %%F in (*) do "%T%\b3sum.exe" "%%F"
    goto :PAUSE_BACK
)
if "!B3C!"=="4" (
    set /p "ARG=  Drag in checksum list (*.b3): "
    echo.
    "%T%\b3sum.exe" --check "!ARG!"
    goto :PAUSE_BACK
)
if "!B3C!"=="5" (
    set /p "ARG=  Enter full arguments: "
    echo.
    "%T%\b3sum.exe" !ARG!
    goto :PAUSE_BACK
)
goto :MENU_B3SUM


:: ================================================================
:MENU_CAVIF
:: ================================================================
cls
echo.
echo  +-- cavif  Image to AVIF Converter ----------------------------+
echo  ^|  AVIF = better ratio than WebP and JPEG at same quality.    ^|
echo  ^|  [1] Convert one image  (quality 80)                        ^|
echo  ^|  [2] Convert one image  (custom quality 1-100)              ^|
echo  ^|  [3] Batch convert all PNG/JPG in a directory (recursive)   ^|
echo  ^|  [4] Custom command                                          ^|
echo  ^|  [0] Back                                                    ^|
echo  +--------------------------------------------------------------+
echo.
choice /c 01234 /n /m "  Option: "
set "CVC=!errorlevel!"
if "!CVC!"=="1" goto :MAIN

if "!CVC!"=="2" (
    set /p "ARG=  Drag in image file: "
    echo.
    "%T%\cavif.exe" -Q 80 "!ARG!"
    goto :PAUSE_BACK
)
if "!CVC!"=="3" (
    set /p "ARG=  Drag in image file: "
    set /p "Q=  Quality (1-100, higher = better): "
    echo.
    "%T%\cavif.exe" -Q !Q! "!ARG!"
    goto :PAUSE_BACK
)
if "!CVC!"=="4" (
    set /p "ARG=  Drag in or type directory path: "
    echo.
    echo  Converting PNG/JPG/JPEG files (recursive)...
    for /r "!ARG!" %%F in (*.png *.jpg *.jpeg) do (
        echo  Converting: %%~nxF
        "%T%\cavif.exe" -Q 80 "%%F"
    )
    echo.
    echo  Batch conversion complete.
    goto :PAUSE_BACK
)
if "!CVC!"=="5" (
    set /p "ARG=  Enter full arguments: "
    echo.
    "%T%\cavif.exe" !ARG!
    goto :PAUSE_BACK
)
goto :MENU_CAVIF


:: ================================================================
:MENU_DUPE
:: ================================================================
cls
echo.
echo  +-- dupefind  Duplicate File Finder ---------------------------+
echo  ^|  Engine: BLAKE3 b3sum (primary) > certutil SHA-256 > FNV    ^|
echo  ^|  3-phase scan: size group -> head hash -> full hash         ^|
echo  ^|                                                              ^|
echo  ^|  [1] Scan directory  (default settings)                     ^|
echo  ^|  [2] Scan, skip files below a size threshold                ^|
echo  ^|  [3] Scan + export results to CSV                           ^|
echo  ^|  [4] Scan + export results to HTML (clickable VT links!)    ^|
echo  ^|  [5] Scan + interactive delete mode                         ^|
echo  ^|  [6] Scan + VirusTotal links for each unique file           ^|
echo  ^|  [7] Custom arguments                                        ^|
echo  ^|  [0] Back                                                    ^|
echo  +--------------------------------------------------------------+
echo.
choice /c 01234567 /n /m "  Option: "
set "DPC=!errorlevel!"
if "!DPC!"=="1" goto :MAIN

if not exist "%DF%" (
    echo.
    echo  [ERROR] colpress-dupe.bat not found in: %ROOT%
    goto :PAUSE_BACK
)

if "!DPC!"=="2" (
    set /p "ARG=  Drag in or type directory to scan: "
    echo.
    call "%DF%" "!ARG!"
    goto :PAUSE_BACK
)
if "!DPC!"=="3" (
    set /p "ARG=  Drag in or type directory to scan: "
    set /p "MIN=  Min size in bytes (e.g. 102400 = 100 KB, 0 = all): "
    echo.
    call "%DF%" "!ARG!" /min:!MIN!
    goto :PAUSE_BACK
)
if "!DPC!"=="4" (
    set /p "ARG=  Drag in or type directory to scan: "
    set /p "CSV=  CSV output path (e.g. C:\report.csv): "
    echo.
    call "%DF%" "!ARG!" /export:"!CSV!"
    goto :PAUSE_BACK
)
if "!DPC!"=="5" (
    set /p "ARG=  Drag in or type directory to scan: "
    set /p "HTML=  HTML output path (e.g. C:\report.html): "
    echo.
    call "%DF%" "!ARG!" /export:"!HTML!"
    goto :PAUSE_BACK
)
if "!DPC!"=="6" (
    set /p "ARG=  Drag in or type directory to scan: "
    echo.
    echo  [WARNING] Interactive delete: permanent, may bypass Recycle Bin.
    echo  Use securewipe [7] or sdelete64 [5] for secure erasure.
    set /p "CONFIRM=  Proceed? (Y/N): "
    if /i "!CONFIRM!"=="Y" call "%DF%" "!ARG!" /delete
    goto :PAUSE_BACK
)
if "!DPC!"=="7" (
    set /p "ARG=  Drag in or type directory to scan: "
    echo.
    echo  Scan will also compute SHA-256 + VirusTotal links per unique file.
    call "%DF%" "!ARG!" /virus
    goto :PAUSE_BACK
)
if "!DPC!"=="8" (
    echo.
    echo  /min:^<bytes^>        Skip files below this size
    echo  /export:^<path.csv^>  Write CSV results
    echo  /export:^<path.html^> Write HTML results (clickable VT links)
    echo  /delete             Interactive deletion mode
    echo  /virus              SHA-256 + VirusTotal links per unique file
    echo.
    set /p "ARG=  Enter full arguments (starting with path): "
    echo.
    call "%DF%" !ARG!
    goto :PAUSE_BACK
)
goto :MENU_DUPE


:: ================================================================
:MENU_INNO
:: ================================================================
cls
echo.
echo  +-- innoextract  Unpack Inno Setup Installers -----------------+
echo  ^|  [1] Unpack to same directory as installer                  ^|
echo  ^|  [2] Unpack to a specified output directory                 ^|
echo  ^|  [3] List files inside the installer (no extraction)        ^|
echo  ^|  [4] Custom command                                          ^|
echo  ^|  [0] Back                                                    ^|
echo  +--------------------------------------------------------------+
echo.
choice /c 01234 /n /m "  Option: "
set "INC=!errorlevel!"
if "!INC!"=="1" goto :MAIN

if "!INC!"=="2" (
    set /p "ARG=  Drag in .exe installer: "
    echo.
    "%T%\innoextract.exe" "!ARG!"
    goto :PAUSE_BACK
)
if "!INC!"=="3" (
    set /p "ARG=  Drag in .exe installer: "
    set /p "OUT=  Drag in or type output directory: "
    echo.
    "%T%\innoextract.exe" -d "!OUT!" "!ARG!"
    goto :PAUSE_BACK
)
if "!INC!"=="4" (
    set /p "ARG=  Drag in .exe installer: "
    echo.
    "%T%\innoextract.exe" -l "!ARG!"
    goto :PAUSE_BACK
)
if "!INC!"=="5" (
    set /p "ARG=  Enter full arguments: "
    echo.
    "%T%\innoextract.exe" !ARG!
    goto :PAUSE_BACK
)
goto :MENU_INNO


:: ================================================================
:MENU_SDEL
:: ================================================================
cls
echo.
echo  +-- sdelete64  Secure File Erasure (Sysinternals) -------------+
echo  ^|  WARNING: Erased files are NOT recoverable!                 ^|
echo  ^|  TIP: colpress-wipe [7] does the same without any exe.     ^|
echo  ^|                                                              ^|
echo  ^|  [1] Delete a file (1 overwrite pass)                       ^|
echo  ^|  [2] Delete a file (7 passes, DoD-style)                    ^|
echo  ^|  [3] Recursively erase all files in a directory             ^|
echo  ^|  [4] Wipe free space on a drive                             ^|
echo  ^|  [5] Custom command                                          ^|
echo  ^|  [0] Back                                                    ^|
echo  +--------------------------------------------------------------+
echo.
choice /c 012345 /n /m "  Option: "
set "SDC=!errorlevel!"
if "!SDC!"=="1" goto :MAIN

if "!SDC!"=="2" (
    set /p "ARG=  Drag in file to erase: "
    echo.
    echo  Target: !ARG!
    set /p "CONFIRM=  Confirm? (Y/N): "
    if /i "!CONFIRM!"=="Y" "%T%\sdelete64.exe" -p 1 -nobanner "!ARG!"
    goto :PAUSE_BACK
)
if "!SDC!"=="3" (
    set /p "ARG=  Drag in file to erase: "
    echo.
    echo  Target (7-pass): !ARG!
    set /p "CONFIRM=  Confirm? (Y/N): "
    if /i "!CONFIRM!"=="Y" "%T%\sdelete64.exe" -p 7 -nobanner "!ARG!"
    goto :PAUSE_BACK
)
if "!SDC!"=="4" (
    set /p "ARG=  Drag in or type directory: "
    echo.
    echo  Will recursively erase ALL files in: !ARG!
    set /p "CONFIRM=  Confirm? (Y/N): "
    if /i "!CONFIRM!"=="Y" "%T%\sdelete64.exe" -p 1 -s -nobanner "!ARG!"
    goto :PAUSE_BACK
)
if "!SDC!"=="5" (
    set /p "ARG=  Enter drive letter (e.g. C:): "
    echo.
    echo  Wiping free space on !ARG! — may take a long time.
    set /p "CONFIRM=  Confirm? (Y/N): "
    if /i "!CONFIRM!"=="Y" "%T%\sdelete64.exe" -p 1 -z -nobanner "!ARG!"
    goto :PAUSE_BACK
)
if "!SDC!"=="6" (
    set /p "ARG=  Enter full arguments: "
    echo.
    "%T%\sdelete64.exe" !ARG!
    goto :PAUSE_BACK
)
goto :MENU_SDEL


:: ================================================================
:MENU_7ZA
:: ================================================================
cls
echo.
echo  +-- 7za  7-Zip Command-Line Archiver --------------------------+
echo  ^|  [1] Extract archive to current directory                   ^|
echo  ^|  [2] Extract archive to a specified directory               ^|
echo  ^|  [3] Compress file/folder to .7z                            ^|
echo  ^|  [4] Compress file/folder to .zip                           ^|
echo  ^|  [5] List contents of an archive                            ^|
echo  ^|  [6] Test archive integrity                                  ^|
echo  ^|  [7] Custom command                                          ^|
echo  ^|  [0] Back                                                    ^|
echo  +--------------------------------------------------------------+
echo.
choice /c 01234567 /n /m "  Option: "
set "Z7C=!errorlevel!"
if "!Z7C!"=="1" goto :MAIN

if "!Z7C!"=="2" (
    set /p "ARG=  Drag in archive: "
    echo.
    "%T%\7za.exe" x "!ARG!"
    goto :PAUSE_BACK
)
if "!Z7C!"=="3" (
    set /p "ARG=  Drag in archive: "
    set /p "OUT=  Drag in or type output directory: "
    echo.
    "%T%\7za.exe" x "!ARG!" -o"!OUT!"
    goto :PAUSE_BACK
)
if "!Z7C!"=="4" (
    set /p "ARG=  Drag in file or folder to compress: "
    set /p "OUT=  Output filename (e.g. output.7z): "
    echo.
    "%T%\7za.exe" a -t7z "!OUT!" "!ARG!"
    goto :PAUSE_BACK
)
if "!Z7C!"=="5" (
    set /p "ARG=  Drag in file or folder to compress: "
    set /p "OUT=  Output filename (e.g. output.zip): "
    echo.
    "%T%\7za.exe" a -tzip "!OUT!" "!ARG!"
    goto :PAUSE_BACK
)
if "!Z7C!"=="6" (
    set /p "ARG=  Drag in archive: "
    echo.
    "%T%\7za.exe" l "!ARG!"
    goto :PAUSE_BACK
)
if "!Z7C!"=="7" (
    set /p "ARG=  Drag in archive: "
    echo.
    "%T%\7za.exe" t "!ARG!"
    goto :PAUSE_BACK
)
if "!Z7C!"=="8" (
    set /p "ARG=  Enter full arguments: "
    echo.
    "%T%\7za.exe" !ARG!
    goto :PAUSE_BACK
)
goto :MENU_7ZA


:: ================================================================
:MENU_SW
:: ================================================================
if not exist "%SW%" (
    echo.
    echo  [ERROR] colpress-wipe.bat not found in: %ROOT%
    goto :PAUSE_BACK
)
call "%SW%"
goto :MAIN


:: ================================================================
:MENU_VT
:: ================================================================
cls
echo.
echo  +-- VirusTotal  Hash + Virus Scan -----------------------------+
echo  ^|  No upload = no privacy risk. Hash lookup is anonymous.     ^|
echo  ^|                                                              ^|
echo  ^|  [1] Hash file (SHA-256) + open VT result directly          ^|
echo  ^|      ^ Opens exact result page — no copy/paste needed        ^|
echo  ^|  [2] Hash file (BLAKE3) + open VT search                    ^|
echo  ^|  [3] Batch scan directory -> HTML report (clickable links)  ^|
echo  ^|  [4] Upload file to VirusTotal (opens browser, max 650 MB)  ^|
echo  ^|                                                              ^|
echo  ^|  [0] Back                                                    ^|
echo  +--------------------------------------------------------------+
echo.
choice /c 01234 /n /m "  Option: "
set "VTC=!errorlevel!"
if "!VTC!"=="1" goto :MAIN

if "!VTC!"=="2" (
    set /p "ARG=  Drag in file to check: "
    echo.
    echo  Computing SHA-256...
    for /f "tokens=*" %%H in ('certutil -hashfile "!ARG!" SHA256 2^>nul ^| findstr /r "^[0-9a-fA-F]"') do set "VT_H=%%H"
    set "VT_H=!VT_H: =!"
    if "!VT_H!"=="" (
        echo  [ERROR] Could not compute hash. File may be locked or not found.
        goto :PAUSE_BACK
    )
    echo  SHA-256: !VT_H!
    echo  Opening VirusTotal result page...
    start "" "https://www.virustotal.com/gui/file/!VT_H!"
    goto :PAUSE_BACK
)
if "!VTC!"=="3" (
    set /p "ARG=  Drag in file to check: "
    echo.
    echo  Computing BLAKE3 hash (b3sum)...
    echo  ---------------------------------------------------------------
    "%T%\b3sum.exe" "!ARG!"
    echo  ---------------------------------------------------------------
    echo  NOTE: VirusTotal search accepts SHA-256/MD5/SHA-1, not BLAKE3.
    echo  Copy the hash above and paste into the VT search box.
    echo.
    set /p "OPEN=  Open VirusTotal search now? (Y/N): "
    if /i "!OPEN!"=="Y" start "" "https://www.virustotal.com/gui/home/search"
    goto :PAUSE_BACK
)
if "!VTC!"=="4" (
    call :VT_BATCH_SCAN
    goto :PAUSE_BACK
)
if "!VTC!"=="5" (
    echo.
    echo  Opening VirusTotal upload page...
    start "" "https://www.virustotal.com/gui/home/upload"
    goto :PAUSE_BACK
)
goto :MENU_VT

:VT_BATCH_SCAN
echo.
set /p "VTB_DIR=  Drag in directory to scan: "
if not exist "!VTB_DIR!" (
    echo  [ERROR] Directory not found: !VTB_DIR!
    goto :eof
)
set "VTB_OUT=!VTB_DIR!\colpress-vtscan.html"
echo.
echo  Scanning: !VTB_DIR!
echo  Output  : !VTB_OUT!
echo.

:: Write HTML header
(
echo ^<!DOCTYPE html^>
echo ^<html lang="en"^>^<head^>^<meta charset="UTF-8"^>
echo ^<title^>Colpress VT Scan^</title^>
echo ^<style^>
echo   body{font-family:Consolas,monospace;background:#111;color:#ddd;padding:24px;margin:0}
echo   h2{color:#4af;margin-bottom:4px} p{color:#888;margin:0 0 16px}
echo   table{border-collapse:collapse;width:100%%} th,td{padding:7px 12px;border-bottom:1px solid #2a2a2a;text-align:left;word-break:break-all}
echo   th{color:#aaa;background:#1a1a1a} tr:hover{background:#1c1c1c}
echo   .hash{font-size:.82em;color:#777} a{color:#4af;text-decoration:none} a:hover{text-decoration:underline}
echo ^</style^>^</head^>^<body^>
echo ^<h2^>Colpress v2.0 — VirusTotal Batch Scan^</h2^>
echo ^<p^>Directory: !VTB_DIR!^</p^>
echo ^<table^>
echo ^<tr^>^<th^>#^</th^>^<th^>File^</th^>^<th^>SHA-256^</th^>^<th^>VirusTotal^</th^>^</tr^>
) > "!VTB_OUT!" 2>nul

if not exist "!VTB_OUT!" (
    echo  [ERROR] Cannot write output file. Check path permissions.
    goto :eof
)

set "VTB_N=0"
for /r "!VTB_DIR!" %%F in (*) do (
    if /i not "%%F"=="!VTB_OUT!" (
        set /a VTB_N+=1
        set "VTB_H="
        for /f "tokens=*" %%H in ('certutil -hashfile "%%F" SHA256 2^>nul ^| findstr /r "^[0-9a-fA-F]"') do set "VTB_H=%%H"
        set "VTB_H=!VTB_H: =!"
        echo  [!VTB_N!] %%~nxF
        if not "!VTB_H!"=="" (
            >> "!VTB_OUT!" (
                echo ^<tr^>^<td^>!VTB_N!^</td^>
                echo ^<td^>%%F^</td^>
                echo ^<td class="hash"^>!VTB_H!^</td^>
                echo ^<td^>^<a href="https://www.virustotal.com/gui/file/!VTB_H!" target="_blank"^>Check on VT^</a^>^</td^>^</tr^>
            )
        ) else (
            >> "!VTB_OUT!" echo ^<tr^>^<td^>!VTB_N!^</td^>^<td^>%%F^</td^>^<td^>—^</td^>^<td^>(locked/unreadable)^</td^>^</tr^>
        )
    )
)

>> "!VTB_OUT!" (
    echo ^</table^>
    echo ^<p style="margin-top:16px"^>Files scanned: !VTB_N!^</p^>
    echo ^</body^>^</html^>
)

echo.
echo  Done. !VTB_N! file(s) scanned.
echo  Report: !VTB_OUT!
echo.
set /p "VTB_OPEN=  Open HTML report in browser? (Y/N): "
if /i "!VTB_OPEN!"=="Y" start "" "!VTB_OUT!"
goto :eof


:: ================================================================
:HELP
:: ================================================================
cls
echo.
echo  +=========================================================+
echo  ^|          Quick Reference — COLPRESS v2.0               ^|
echo  +=========================================================+
echo  ^|                                                         ^|
echo  ^|  b3sum — BLAKE3 hash (fastest, strongest)              ^|
echo  ^|    b3sum file.exe                                       ^|
echo  ^|    b3sum --check checksums.b3                           ^|
echo  ^|                                                         ^|
echo  ^|  cavif — Convert to AVIF (smaller than WebP)           ^|
echo  ^|    cavif -Q 80 photo.png                                ^|
echo  ^|    cavif --overwrite *.jpg                              ^|
echo  ^|                                                         ^|
echo  ^|  dupefind — Duplicate finder (BLAKE3 engine)            ^|
echo  ^|    colpress-dupe.bat D:\Photos                          ^|
echo  ^|    colpress-dupe.bat D:\ /min:1048576 /export:out.csv   ^|
echo  ^|    colpress-dupe.bat D:\ /export:out.html               ^|
echo  ^|    colpress-dupe.bat D:\ /delete                        ^|
echo  ^|    colpress-dupe.bat D:\ /virus                         ^|
echo  ^|                                                         ^|
echo  ^|  innoextract — Unpack Inno Setup .exe                  ^|
echo  ^|    innoextract setup.exe                                ^|
echo  ^|    innoextract -d out\ setup.exe                        ^|
echo  ^|    innoextract -l setup.exe  (list only)               ^|
echo  ^|                                                         ^|
echo  ^|  securewipe — Secure erase (no exe, built-in)          ^|
echo  ^|    colpress-wipe.bat file.txt        (3 passes)         ^|
echo  ^|    colpress-wipe.bat file.txt /p:7   (7 passes)         ^|
echo  ^|    colpress-wipe.bat dir\ /s         (recursive)        ^|
echo  ^|    colpress-wipe.bat C: /z           (free space)       ^|
echo  ^|                                                         ^|
echo  ^|  sdelete64 — Sysinternals secure erase (exe)           ^|
echo  ^|    sdelete64 -p 1 file.txt     (1 pass)                 ^|
echo  ^|    sdelete64 -p 7 file.txt     (7 passes)               ^|
echo  ^|    sdelete64 -z D:             (wipe free space)        ^|
echo  ^|                                                         ^|
echo  ^|  7za — 7-Zip command-line                               ^|
echo  ^|    7za x archive.7z            (extract)                ^|
echo  ^|    7za a -t7z out.7z folder\   (compress to .7z)        ^|
echo  ^|    7za a -tzip out.zip file    (compress to .zip)       ^|
echo  ^|    7za l archive.zip           (list)                   ^|
echo  ^|    7za t archive.7z            (test integrity)         ^|
echo  ^|                                                         ^|
echo  ^|  VirusTotal — Hash + direct scan link                   ^|
echo  ^|    [V] > [1]: SHA-256 -> opens VT result page directly  ^|
echo  ^|    [V] > [3]: Batch scan dir -> HTML report w/ VT links ^|
echo  ^|                                                         ^|
echo  +=========================================================+
echo.
pause
goto :MAIN


:: ================================================================
:PAUSE_BACK
:: ================================================================
echo.
echo  ---------------------------------------------------------------
pause
goto :MAIN


:: ================================================================
:EXIT
:: ================================================================
echo.
echo  Goodbye!
timeout /t 1 >nul
exit /b 0
