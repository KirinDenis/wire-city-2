@echo off
REM ============================================================================
REM RUNWIN.BAT - play a story from Windows: opens DOSBox, runs it, closes.
REM
REM   RUNWIN                        plays ..\STORY\NIGHT
REM   RUNWIN ..\STORY\NIGHT /AUTO   plays itself, writes SHOTnn.OWV, closes
REM
REM It starts DOSBox and runs this folder's own RUN.BAT with EXIT. CYCLES
REM 30000 is the figure the video player was measured at.
REM
REM -noautoexec is not optional: without it DOSBox runs the machine's own
REM autoexec and every -c below is buried under it. It also means no memory
REM manager is loaded, which is what makes the engine's habit of simply
REM taking the memory above 1 MB safe here.
REM ============================================================================
cd /d %~dp0..\..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

set VTDIR=%1
if "%VTDIR%"=="" set VTDIR=..\STORY\NIGHT
set VTRUN=RUN.BAT %VTDIR% %2 EXIT

echo Running under DOSBox ...
"%DOSBOX%" -noautoexec -c "config -set cycles=30000" -c "mount c %CD%" -c "c:" -c "cd LAB\OWLFLY4\ENGINE" -c "%VTRUN%" -c "exit"
