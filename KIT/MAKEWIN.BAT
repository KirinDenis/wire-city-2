@echo off
REM ============================================================================
REM MAKEWIN.BAT - build one program of the kit from Windows.
REM
REM   KIT\MAKEWIN TEST T_VGA
REM
REM It starts DOSBox (silent: no sound, no speaker), runs KIT\MAKE.BAT with
REM EXIT so the emulator closes itself, then shows FASM's log and whether the
REM .COM came out with a size above zero (a killed DOSBox leaves 0 bytes).
REM ============================================================================
cd /d %~dp0..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
if "%2"=="" goto usage

if exist KIT\%1\%2.COM del KIT\%1\%2.COM
"%DOSBOX%" -noautoexec -noconsole -set "mixer nosound=true" -set "speaker pcspeaker=false" -c "mount c %CD%" -c "c:" -c "cd KIT" -c "MAKE.BAT %1 %2 EXIT"
if exist KIT\%1\%2.LOG type KIT\%1\%2.LOG
for %%F in (KIT\%1\%2.COM) do if %%~zF GTR 0 (echo BUILT KIT\%1\%2.COM %%~zF bytes) else (echo FAILED KIT\%1\%2)
if not exist KIT\%1\%2.COM echo FAILED KIT\%1\%2
goto end

:usage
echo Usage: KIT\MAKEWIN FOLDER NAME   - KIT\MAKEWIN TEST T_VGA
:end
