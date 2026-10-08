@echo off
REM ============================================================================
REM MAKEINFO.BAT - build the lesson 19 OPENING INFOGRAPHIC from Windows.
REM
REM   MAKEINFO        compile INFOGR.PAS with Borland Pascal, in DOSBox
REM   MAKEINFO RUN    ...and leave DOSBox open on it, ready to look at
REM
REM The infographic is PRODUCTION, not lesson: the video opens on it because
REM a black DOS prompt loses the viewer in five seconds. Its source lives
REM here so a stranger can rebuild it, but the lesson never types it.
REM
REM Borland Pascal is NOT in this repository (THIRD-PARTY.md manners, same
REM as Watcom): LOCAL.BAT says where it lives, and it is mounted as D:.
REM
REM THE BGI DRIVER GOES INTO THE EXE. BINOBJ turns D:\BGI\EGAVGA.BGI into
REM EGAVGA.OBJ (not kept: *.OBJ is in .gitignore), and INFOGR.PAS links it
REM with {$L}. The INFOGR.EXE this makes needs no D: and no BGI folder, so
REM it runs on the course disk and in the browser - the first notebook that
REM does.
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
if exist LESSONS\L25\INFOGR.EXE del LESSONS\L25\INFOGR.EXE
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "mount d %TASMDIR%" -c "c:" -c "cd LESSONS\L25" -c "D:\BIN\BINOBJ.EXE D:\BGI\EGAVGA.BGI EGAVGA.OBJ EgaVgaDriverProc > TPC.LOG" -c "D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS >> TPC.LOG" -c "exit"
if not exist LESSONS\L25\INFOGR.EXE goto failed
echo.
echo Built LESSONS\L25\INFOGR.EXE.  MAKEINFO RUN shows it.
goto end

:run
"%DOSBOX%" -noautoexec -c "mount c %CD%" -c "c:" -c "cd LESSONS\L25" -c "INFOGR.EXE %2"
goto end

:failed
echo.
echo Compile failed - the reason is in LESSONS\L25\TPC.LOG.
type LESSONS\L25\TPC.LOG
:end
