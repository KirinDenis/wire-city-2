@echo off
REM ============================================================================
REM RUNWB.BAT - boot the staged WORKBENCH disk under DOSBox, from Windows.
REM
REM   TOOLS\packwb.ps1 stages DISK\ in the repo root; this file boots it the
REM   way the browser will: mount DISK as C:, run BOOT.BAT (PATH, the DPMI
REM   host, MENU). Test here BEFORE packing - a bundle that has never been
REM   booted looks exactly like one that has.
REM
REM BOOT.BAT is the last -c line on purpose: a batch started from a DOSBox
REM -c line swallows every -c line after it.
REM ============================================================================
cd /d %~dp0..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
if not exist DISK\BOOT.BAT goto nostage
"%DOSBOX%" -noautoexec -c "mount c %CD%\DISK" -c "c:" -c "BOOT.BAT"
goto end
:nostage
echo DISK\ is not staged. Run:  powershell -ExecutionPolicy Bypass -File TOOLS\packwb.ps1
:end
