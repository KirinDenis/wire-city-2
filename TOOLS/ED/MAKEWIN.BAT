@echo off
REM ============================================================================
REM MAKEWIN.BAT - build ED from Windows, without opening DOSBox by hand.
REM
REM   MAKEWIN         ->  TOOLS\ED\ED.EXE
REM
REM Mounts the repository as C: and Open Watcom as F:, exactly as the lecture
REM machine does, then runs MAKE.BAT inside. WCDIR comes from LOCAL.BAT -
REM Watcom lives outside this repository and its path is nobody else's
REM business.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
if "%WCDIR%"=="" goto nowc

REM The environment is set in BUILD.BAT, not on -c lines. A -c string that
REM ends in a backslash escapes its own closing quote and eats the next -c,
REM so "set WATCOM=f:\" silently swallowed "set INCLUDE=f:\h" and the
REM compiler could not find stdio.h. See BUILD.BAT's header.
echo Building ED in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "mount f %WCDIR%" -c "c:" -c "cd TOOLS\ED" -c "BUILD.BAT EXIT"
if not exist TOOLS\ED\ED.EXE goto failed
echo.
for %%F in (TOOLS\ED\ED.EXE) do echo Built TOOLS\ED\ED.EXE  %%~zF bytes
goto end

:nowc
echo WCDIR is not set in LOCAL.BAT - point it at your Open Watcom folder.
goto end
:failed
echo.
echo Build failed - open DOSBox and run MAKE from TOOLS\ED to see why.
:end
