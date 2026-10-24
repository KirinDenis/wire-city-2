@echo off
REM ============================================================================
REM PLAY.BAT - play one of the experiment's games in DOSBox, from Windows.
REM
REM   MY\PLAY LANDA      Sonnet, without the kit
REM   MY\PLAY LANDB      Sonnet, with the kit
REM   MY\PLAY LANDC      Haiku, with the kit
REM   MY\PLAY LANDD      Haiku, with the kit after its rules were made rules
REM
REM With sound. DOSBox closes when the game quits to DOS (Esc).
REM ============================================================================
cd /d %~dp0..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
if "%1"=="" goto usage
if not exist MY\%1\%1.COM goto nocom
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd MY\%1" -c "%1" -c "exit"
goto end
:nocom
echo MY\%1\%1.COM is not here.
goto end
:usage
echo Usage: MY\PLAY LANDA   (or LANDB, LANDC)
:end
