@echo off
REM ============================================================================
REM MAKEINFO.BAT - build the lesson 10 OPENING INFOGRAPHIC from Windows.
REM
REM   MAKEINFO        compile INFOGR.PAS with Borland Pascal, in DOSBox
REM   MAKEINFO RUN    ...and leave DOSBox open on it, ready to film
REM
REM The infographic is PRODUCTION, not lesson: the video opens on it because
REM a black DOS prompt loses the viewer in five seconds. Its source lives
REM here so a stranger can rebuild it, but the lesson never types it.
REM
REM Borland Pascal is NOT in this repository (THIRD-PARTY.md manners, same
REM as Watcom): LOCAL.BAT says where it lives, and it is mounted as D: -
REM the program loads EGAVGA.BGI from D:\BGI at start.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
if "%TASMDIR%"=="" (
  echo LOCAL.BAT did not set TASMDIR - point it at Borland Pascal.
  goto end
)

if /i "%~1"=="RUN" goto run

echo Compiling with Borland Pascal in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "mount d %TASMDIR%" -c "c:" -c "cd LESSONS\L10" -c "D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS" -c "exit"
if not exist LESSONS\L10\INFOGR.EXE goto failed
echo.
echo Built LESSONS\L10\INFOGR.EXE.  MAKEINFO RUN films it.
goto end

:run
"%DOSBOX%" -noautoexec -c "mount c %CD%" -c "mount d %TASMDIR%" -c "c:" -c "cd LESSONS\L10" -c "INFOGR.EXE"
goto end

:failed
echo.
echo Compile failed - the reason is printed above.
:end
