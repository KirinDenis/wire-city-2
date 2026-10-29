@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 22, from inside DOS.
REM
REM   cd LESSONS\L34
REM   MAKE
REM
REM GUNS.ASM is lesson 20's TRAFFIC.ASM, armed: your gun and theirs, rounds
REM that are real moving things, and lesson 21's breakup in the sky. The
REM source travels from lesson to lesson: each one starts as a copy of the
REM last and grows. The island, the sine, the rotate, the projection and the
REM rasterizer still come out of ..\..\ENGINE.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist GUNS.ASM goto nosource

echo Assembling GUNS.ASM ...
if exist GUNS.COM del GUNS.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE GUNS.ASM GUNS.COM
if not exist GUNS.COM goto failed

echo.
echo Built GUNS.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L34 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo GUNS.ASM is not here. Run MAKE from LESSONS\L34.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. GUNS.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
