@echo off
REM ============================================================================
REM RUNWIN.BAT - play WIRE CITY from Windows: opens DOSBox and starts the game.
REM
REM   RUNWIN          the game as it is built now, with FASM
REM   RUNWIN TASM     the Turbo Assembler version in TASM\WIRECITY, for
REM                   comparison. Needs TASM to have built it - MAKEWIN.BAT
REM                   in the repository root, target WIRECITY.
REM
REM Inside DOS the equivalent is simply RUN, in this folder.
REM
REM   Arrows  turn and climb        SPACE  restart after a crash
REM   ESC     quit
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

set DIR=GAMES\WIRECITY
set WHICH=FASM
if /i "%~1"=="TASM" set DIR=TASM\WIRECITY& set WHICH=TASM

if not exist %DIR%\CITY.COM goto missing
echo Starting WIRE CITY [%WHICH%]
"%DOSBOX%" -noautoexec -c "mount c %CD%" -c "c:" -c "cd %DIR%" -c "CITY.COM" -c "exit"
goto end

:missing
echo %DIR%\CITY.COM is not built.
if /i "%~1"=="TASM" echo Build it with MAKEWIN.BAT WIRECITY from the repository root ^(needs TASM^).
if not "%~1"=="TASM" echo Build it with MAKEWIN.BAT in this folder.
:end
