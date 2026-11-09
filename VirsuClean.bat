@echo off
setlocal EnableExtensions EnableDelayedExpansion
title System Cleanup Helper
color 0A

:: ---- admin check ----
net session >nul 2>&1
if errorlevel 1 (
    echo [!] Run as Administrator. Right-click ^> Run as administrator.
    pause & exit /b 1
)

set "LOG=%~dp0clean_log_%DATE:~-4%%DATE:~3,2%%DATE:~0,2%.txt"
echo Cleanup started %DATE% %TIME% > "%LOG%"

echo ============================================
echo   SYSTEM CLEANUP HELPER  (log: %LOG%)
echo   Deletes only: user TEMP, Windows TEMP,
echo   Prefetch, Recycle Bin. Nothing else.
echo ============================================
echo.
choice /c YN /m "Create a restore point first"
if errorlevel 2 goto skip_rp
powershell -NoProfile -Command "Checkpoint-Computer -Description 'PreCleanup' -RestorePointType MODIFY_SETTINGS" 2>nul
echo [i] Restore point requested. >> "%LOG%"
:skip_rp

:: ---- 1. temp folders ----
echo.
echo [1/6] Clearing temp folders...
for %%D in ("%TEMP%" "%SystemRoot%\Temp" "%LOCALAPPDATA%\Temp") do (
    if exist "%%~D" (
        echo   - %%~D
        del /f /s /q "%%~D\*.*" >nul 2>&1
        for /d %%d in ("%%~D\*") do rd /s /q "%%d" >nul 2>&1
    )
)
echo [1] temp cleared >> "%LOG%"

:: ---- 2. prefetch ----
echo [2/6] Clearing Prefetch...
del /f /q "%SystemRoot%\Prefetch\*.pf" >nul 2>&1
echo [2] prefetch cleared >> "%LOG%"

:: ---- 3. recycle bin ----
echo [3/6] Emptying Recycle Bin...
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"
echo [3] recycle bin emptied >> "%LOG%"

:: ---- 4. DNS / ARP cache ----
echo [4/6] Flushing DNS and ARP cache...
ipconfig /flushdns >nul 2>&1
arp -d * >nul 2>&1
echo [4] caches flushed >> "%LOG%"

:: ---- 5. autorun audit (read-only) ----
echo [5/6] Auditing autoruns -> autoruns.txt
set "AR=%~dp0autoruns.txt"
>  "%AR%" echo === Run keys ===
>> "%AR%" reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" 2>nul
>> "%AR%" reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" 2>nul
>> "%AR%" reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce" 2>nul
>> "%AR%" echo. & >> "%AR%" echo === Scheduled tasks (non-Microsoft) ===
>> "%AR%" schtasks /query /fo table /v 2>nul | findstr /i /v "Microsoft\\Windows"
>> "%AR%" echo. & >> "%AR%" echo === Startup folders ===
>> "%AR%" dir /b "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Startup" 2>nul
>> "%AR%" dir /b "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup" 2>nul
echo   - wrote %AR%
echo [5] autoruns audited >> "%LOG%"

:: ---- 6. Defender quick scan ----
echo [6/6] Starting Defender quick scan (may take several minutes)...
set "MP=%ProgramFiles%\Windows Defender\MpCmdRun.exe"
if exist "%MP%" (
    "%MP%" -Scan -ScanType 1
    echo [6] Defender scan exit=%errorlevel% >> "%LOG%"
) else (
    echo   [!] MpCmdRun.exe not found - Defender may be replaced by another AV.
    echo [6] Defender not found >> "%LOG%"
)

echo.
echo ============================================
echo  Done. Review:
echo    %AR%      ^(autoruns - delete suspicious entries manually^)
echo    %LOG%     ^(run log^)
echo.
echo  Optional deep checks (run manually, slow):
echo    sfc /scannow
echo    DISM /Online /Cleanup-Image /RestoreHealth
echo ============================================
pause
endlocal