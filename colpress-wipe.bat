@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

:: ================================================================
::  colpress-wipe.bat  v2.0  —  Secure File/Folder Erasure
::  Part of Colpress v2.0. No exe required.
::
::  Engine : PowerShell 5.1+ (.NET streaming — built into Windows 10+)
::  Free space: cipher /w: (built-in since Windows XP)
::
::  Wipe passes (DoD 5220.22-M inspired):
::    Pass 1 — 0x00 bytes
::    Pass 2 — 0xFF bytes
::    Pass 3 — RNGCryptoServiceProvider (cryptographically random)
::    Passes 4-7 repeat the cycle for 7-pass mode.
::
::  SSD note: All file-level tools (including sdelete64) cannot
::  guarantee physical erasure on SSDs due to wear-levelling.
::  For SSDs, use ATA Secure Erase (drive firmware) or full-disk
::  encryption before deletion. This tool matches sdelete64 in that regard.
::
::  Usage (standalone):
::    colpress-wipe.bat <file>          (3-pass wipe + delete)
::    colpress-wipe.bat <file> /p:1     (1-pass zeros)
::    colpress-wipe.bat <file> /p:7     (7-pass)
::    colpress-wipe.bat <dir>  /s       (recursive, 3-pass)
::    colpress-wipe.bat <drive:> /z     (wipe free space via cipher /w:)
::    colpress-wipe.bat /?
:: ================================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

if not "%~1"=="" (
    if /i "%~1"=="/?" goto :HELP
    set "DIRECT_PATH=%~1"
    set "DIRECT_FLAGS=%~2"
    goto :RUN_DIRECT
)

:MAIN
cls
echo.
echo  +-- colpress-wipe  Secure Erasure (no exe) --------------------+
echo  ^|  Engine: PowerShell .NET streaming  ^|  Requires: Win 10+    ^|
echo  ^|  Free-space: cipher /w: (built-in since XP)                 ^|
echo  ^|                                                              ^|
echo  ^|  [1] Wipe a file  (1 pass — zeros)                          ^|
echo  ^|  [2] Wipe a file  (3 passes — zeros / 0xFF / random)        ^|
echo  ^|  [3] Wipe a file  (7 passes)                                ^|
echo  ^|  [4] Wipe all files in a directory recursively  (3 passes)  ^|
echo  ^|  [5] Wipe free space on a drive  (cipher /w:)               ^|
echo  ^|  [0] Back / Exit                                             ^|
echo  +--------------------------------------------------------------+
echo.
choice /c 123450 /n /m "  Enter option: "
set "OPT=!errorlevel!"

if "!OPT!"=="6" goto :EXIT_SW
if "!OPT!"=="5" goto :WIPE_FREE
if "!OPT!"=="4" goto :WIPE_DIR
if "!OPT!"=="3" goto :WIPE_7
if "!OPT!"=="2" goto :WIPE_3
if "!OPT!"=="1" goto :WIPE_1
goto :MAIN

:WIPE_1
set /p "SW_FILE=  Drag in or type file path: "
echo.  & echo  Target : !SW_FILE!  & echo  Passes : 1  (zeros)
set /p "SW_C=  Confirm? (Y/N): "
if /i not "!SW_C!"=="Y" goto :MAIN
call :DO_WIPE "!SW_FILE!" 1
goto :SW_PAUSE

:WIPE_3
set /p "SW_FILE=  Drag in or type file path: "
echo.  & echo  Target : !SW_FILE!  & echo  Passes : 3  (zeros, 0xFF, random)
set /p "SW_C=  Confirm? (Y/N): "
if /i not "!SW_C!"=="Y" goto :MAIN
call :DO_WIPE "!SW_FILE!" 3
goto :SW_PAUSE

:WIPE_7
set /p "SW_FILE=  Drag in or type file path: "
echo.  & echo  Target : !SW_FILE!  & echo  Passes : 7  (zeros, 0xFF, random x5)
set /p "SW_C=  Confirm? (Y/N): "
if /i not "!SW_C!"=="Y" goto :MAIN
call :DO_WIPE "!SW_FILE!" 7
goto :SW_PAUSE

:WIPE_DIR
set /p "SW_DIR=  Drag in or type directory path: "
echo.
echo  WARNING: All files inside !SW_DIR! will be securely wiped.
set /p "SW_C=  Confirm? (Y/N): "
if /i not "!SW_C!"=="Y" goto :MAIN
echo.  & echo  Wiping all files in: !SW_DIR!
for /r "!SW_DIR!" %%F in (*) do (
    echo  Wiping: %%F
    call :DO_WIPE "%%F" 3
)
echo.  & echo  All files wiped. Directory structure left intact.
goto :SW_PAUSE

:WIPE_FREE
echo.
set /p "SW_DRV=  Enter drive letter (e.g. C: or D:): "
echo.
echo  cipher /w: writes zeros, 0xFF, then random data to all free
echo  clusters on !SW_DRV! — preventing software recovery.
echo  This may take a long time on large drives.
set /p "SW_C=  Confirm? (Y/N): "
if /i not "!SW_C!"=="Y" goto :MAIN
echo.
echo  Wiping free space on !SW_DRV! (may take minutes to hours)...
cipher /w:!SW_DRV!
echo.  & echo  Free-space wipe complete.
goto :SW_PAUSE

:SW_PAUSE
echo.  & echo  ----------------------------------------------------------------
pause
goto :MAIN

:EXIT_SW
exit /b 0

:: ── Subroutine: DO_WIPE <path> <passes> ──────────────────────────
:DO_WIPE
setlocal
set "WP_FILE=%~1"
set "WP_PASSES=%~2"
if "!WP_PASSES!"=="" set "WP_PASSES=3"
echo.
echo  Wiping: !WP_FILE!  (!WP_PASSES! pass(es))...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "& { ^
    $f = '!WP_FILE!'.Trim('\"'); ^
    if (-not [IO.File]::Exists($f)) { Write-Host '  ERROR: File not found.'; exit 1 } ^
    $size = (Get-Item -LiteralPath $f).Length; ^
    if ($size -eq 0) { Remove-Item -LiteralPath $f -Force; Write-Host '  Deleted (empty file).'; exit 0 } ^
    $rng = [Security.Cryptography.RNGCryptoServiceProvider]::new(); ^
    $buf = [byte[]]::new([Math]::Min($size, 1048576)); ^
    $passes = !WP_PASSES!; ^
    for ($p = 0; $p -lt $passes; $p++) { ^
        $label = switch ($p %% 3) { 0 {'zeros'} 1 {'0xFF'} 2 {'random'} }; ^
        Write-Host ('  Pass ' + ($p+1) + '/' + $passes + ': ' + $label + '...') -NoNewline; ^
        $s = [IO.File]::Open($f, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::None); ^
        $s.Seek(0, [IO.SeekOrigin]::Begin) ^| Out-Null; ^
        $written = [long]0; ^
        while ($written -lt $size) { ^
            $n = [Math]::Min($buf.Length, $size - $written); ^
            switch ($p %% 3) { ^
                0 { [Array]::Clear($buf, 0, $n) } ^
                1 { for ($i=0; $i -lt $n; $i++) { $buf[$i] = 0xFF } } ^
                2 { $rng.GetBytes($buf); if ($n -lt $buf.Length) { $tmp=[byte[]]::new($n); [Array]::Copy($buf,0,$tmp,0,$n); $buf=$tmp } } ^
            } ^
            $s.Write($buf, 0, $n); ^
            $written += $n; ^
        } ^
        $s.Flush(); $s.Close(); ^
        Write-Host ' done.'; ^
    } ^
    $rng.Dispose(); ^
    Remove-Item -LiteralPath $f -Force; ^
    Write-Host '  Deleted.'; ^
  }"
if errorlevel 1 (
    echo.
    echo  [ERROR] Wipe failed. File may be in use or PowerShell unavailable.
    echo  Fallback: use sdelete64.exe from tools\ if PowerShell is blocked.
)
endlocal
goto :eof

:: ── Direct / CLI mode ─────────────────────────────────────────────
:RUN_DIRECT
set "SW_PASSES=3"
set "SW_RECURSE=0"
set "SW_FREE=0"
for %%A in (%DIRECT_FLAGS%) do (
    if /i "%%A"=="/p:1" set "SW_PASSES=1"
    if /i "%%A"=="/p:3" set "SW_PASSES=3"
    if /i "%%A"=="/p:7" set "SW_PASSES=7"
    if /i "%%A"=="/s"   set "SW_RECURSE=1"
    if /i "%%A"=="/z"   set "SW_FREE=1"
)
if "!SW_FREE!"=="1" (
    echo  Wiping free space on !DIRECT_PATH!...
    cipher /w:!DIRECT_PATH!
    goto :eof
)
if "!SW_RECURSE!"=="1" (
    for /r "!DIRECT_PATH!" %%F in (*) do call :DO_WIPE "%%F" !SW_PASSES!
) else (
    call :DO_WIPE "!DIRECT_PATH!" !SW_PASSES!
)
goto :eof

:HELP
echo.
echo  colpress-wipe.bat v2.0  —  Secure File Erasure (no exe)
echo  Part of Colpress v2.0. Requires: Windows 10+ / PowerShell 5.1+
echo.
echo  USAGE:
echo    colpress-wipe.bat                        (interactive menu)
echo    colpress-wipe.bat ^<file^>                 (3-pass wipe + delete)
echo    colpress-wipe.bat ^<file^> /p:1            (1 pass, zeros only)
echo    colpress-wipe.bat ^<file^> /p:7            (7 passes)
echo    colpress-wipe.bat ^<directory^> /s         (recurse all files, 3 passes)
echo    colpress-wipe.bat ^<drive:^> /z            (wipe free space via cipher /w:)
echo.
echo  NOTES:
echo    Random bytes use RNGCryptoServiceProvider (cryptographically secure).
echo    On SSDs, use ATA Secure Erase or full-disk encryption for maximum assurance.
echo.
goto :eof
