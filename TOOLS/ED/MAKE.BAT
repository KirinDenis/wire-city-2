@echo off
REM ============================================================================
REM MAKE.BAT - build ED, from inside DOS.
REM
REM   cd TOOLS\ED
REM   MAKE            ->  ED.EXE
REM
REM Open Watcom, the same compiler and the same three switches as lesson 1:
REM
REM   -0            an 8086 build. This editor runs on the machine the course
REM                 is about, not on something newer.
REM   -ml           large model - the file being edited lives in far memory
REM                 and a 64K data segment is not enough for a real lesson.
REM   -bcl=dos      a plain DOS executable, no extender, no DPMI host.
REM
REM WATCOM IS NOT IN THIS REPOSITORY and never will be - see THIRD-PARTY.md.
REM It is mounted as F: by the lecture machine, and WCENV.BAT sets WATCOM and
REM INCLUDE at boot. From a bare DOSBox, mount it yourself first.
REM
REM   MAKE EXIT     builds and then closes DOSBox, for MAKEWIN.BAT.
REM ============================================================================
if not exist ED.C goto nosource
if "%WATCOM%"=="" goto nowatcom

echo Building ED.EXE ...
if exist ED.EXE del ED.EXE
wcl -0 -ml -bcl=dos ED.C
if not exist ED.EXE goto failed
echo.
echo Built ED.EXE.  Try:  ED TURN.ASM
goto end

:nosource
echo ED.C not found - run this from TOOLS\ED.
goto end
:nowatcom
echo WATCOM is not set. This needs Open Watcom mounted; the lecture machine
echo does it in WCENV.BAT. Outside it, mount the compiler and set WATCOM and
echo INCLUDE before building.
goto end
:failed
echo.
echo Build failed - the compiler's messages are above.
:end
if /i "%~1"=="EXIT" exit
