@echo off
REM ============================================================================
REM RUNWIN.BAT - play MULTIPLAY SOKO II from Windows: opens DOSBox and starts
REM the game. Inside DOS the equivalent is simply RUN, in this folder.
REM
REM   RUNWIN         on the DOSBox machine LOCAL.BAT or dosbox.conf gives (a VGA)
REM   RUNWIN EGA     on a real EGA card       (DOSBox -machine ega)
REM   RUNWIN CGA     on a real CGA card       (DOSBox -machine cga)
REM   RUNWIN HGC     on a Hercules card       (DOSBox -machine hercules)
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

set MACHINE=
if /i "%~1"=="EGA" set MACHINE=-machine ega
if /i "%~1"=="CGA" set MACHINE=-machine cga
if /i "%~1"=="HGC" set MACHINE=-machine hercules

if not exist GAMES\MULTSOK2\MULTSOK2.COM goto missing
echo Starting MULTIPLAY SOKO II
"%DOSBOX%" -noautoexec %MACHINE% -c "mount c %CD%" -c "c:" -c "cd GAMES\MULTSOK2" -c "RUN.BAT" -c "exit"
goto end

:missing
echo GAMES\MULTSOK2\MULTSOK2.COM is not built. Build it with MAKEWIN.BAT in this folder.
:end
