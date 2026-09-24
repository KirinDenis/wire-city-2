@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 14, from inside DOS.
REM
REM   cd LESSONS\L20
REM   MAKE
REM
REM FLY.ASM is lesson 13's program with the game's flight physics added to it.
REM From here on the source travels from lesson to lesson: each one starts as
REM a copy of the last and grows. The island, the sine, the rotate, the
REM projection, the line and its clipper still come out of ..\..\ENGINE - the
REM same five files the game is built from - and the near-plane clip and the
REM flight model are copied out of GAMES\WIRECITY\CITY.ASM.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist FLY.ASM goto nosource

echo Assembling FLY.ASM ...
if exist FLY.COM del FLY.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE FLY.ASM FLY.COM
if not exist FLY.COM goto failed

echo.
echo Built FLY.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L20 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo FLY.ASM is not here. Run MAKE from LESSONS\L20.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. FLY.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
