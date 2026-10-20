@echo off
REM ============================================================================
REM RUNWIN.BAT - play MULTSOKO from Windows: opens DOSBox and starts the game.
REM Inside DOS the equivalent is simply RUN, in this folder.
REM
REM   RUNWIN         on the DOSBox machine LOCAL.BAT or dosbox.conf gives
REM   RUNWIN CGA     on a real CGA card (DOSBox -machine cga)
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

set MACHINE=
if /i "%~1"=="CGA" set MACHINE=-machine cga

if not exist GAMES\MULTSOKO\MULTSOKO.COM goto missing
echo Starting MULTSOKO
"%DOSBOX%" -noautoexec %MACHINE% -c "mount c %CD%" -c "c:" -c "cd GAMES\MULTSOKO" -c "MULTSOKO.COM" -c "exit"
goto end

:missing
echo GAMES\MULTSOKO\MULTSOKO.COM is not built. Build it with MAKEWIN.BAT in this folder.
:end
