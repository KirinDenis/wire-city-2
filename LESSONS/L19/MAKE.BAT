@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 13, from inside DOS.
REM
REM   cd LESSONS\L19
REM   MAKE
REM
REM CLIP.ASM is the lesson, and it is the first one that assembles nothing of
REM its own but the lesson. The island, the sine, the rotate, the projection,
REM the line and its clipper all come out of ..\..\ENGINE - the same five
REM files the game is built from - and the near-plane clip is copied verbatim
REM out of GAMES\WIRECITY\CITY.ASM. Nothing here is a lesson version of
REM anything.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist CLIP.ASM goto nosource

echo Assembling CLIP.ASM ...
if exist CLIP.COM del CLIP.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE CLIP.ASM CLIP.COM
if not exist CLIP.COM goto failed

echo.
echo Built CLIP.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L19 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo CLIP.ASM is not here. Run MAKE from LESSONS\L19.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. CLIP.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
