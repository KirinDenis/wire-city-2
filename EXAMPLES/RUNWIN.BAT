@echo off
REM ============================================================================
REM RUNWIN.BAT - run one of the teaching machines from Windows: opens DOSBox,
REM starts it, and closes again when it exits.
REM
REM   RUNWIN JET
REM   RUNWIN JET.COM      the same - Tab completion hands you the extension,
REM                       and being told "JET.COM.COM is not built" is a poor
REM                       reward for using it. %~n1 takes the name off a path
REM                       whether or not one is there.
REM
REM Inside DOS the equivalent is RUN JET, in this folder. See RUN.BAT for what
REM each of the thirteen demonstrates.
REM ============================================================================
if "%~1"=="" goto usage
set WHAT=%~n1
cd /d %~dp0..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if not exist EXAMPLES\%WHAT%.COM goto missing
echo Starting %WHAT%
"%DOSBOX%" -noautoexec -c "mount c %CD%" -c "c:" -c "cd EXAMPLES" -c "%WHAT%.COM" -c "exit"
goto end

:missing
echo EXAMPLES\%WHAT%.COM is not built. Run MAKEWIN %WHAT% first.
goto end

:usage
echo Which one? RUNWIN JET, for instance. The thirteen are
echo   TERRA RING SPOOL FLIGHT LAND LNDPHYS TKOFF TKPHYS SMOKE AVIO JET SOLO BBS

:end
