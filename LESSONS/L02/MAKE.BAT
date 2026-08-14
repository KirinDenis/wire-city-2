@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 2, from inside DOS.
REM
REM   cd LESSONS\L02
REM   MAKE
REM
REM Three programs, and the point of the lesson is the difference between the
REM first two:
REM
REM   HELLO.COM    18 bytes. No header at all - the file IS the program, and
REM                DOS loads it at offset 100h and jumps to the first byte.
REM   HELLO2.EXE   the same program as a real MZ executable: a header, a
REM                relocation table, a stack of its own, and DOS deciding at
REM                load time where the segments actually land.
REM   HEX.COM      our own tool, so the lesson can look at those bytes and
REM                change them without a file manager. Written in the language
REM                the lesson is about, built by the assembler the lesson uses.
REM
REM Paths are relative on purpose: mount the folder ABOVE the repository - a
REM perfectly normal thing to do - and any absolute \TOOLS\... path points at
REM nothing.
REM
REM WHY IT LOADS CWSDPMI. FASM is a 32-bit program and DOS is a 16-bit system,
REM so something has to own protected mode on its behalf. CWSDPMI with no
REM arguments stays resident FOR ONE PROGRAM and unloads itself when that
REM program exits - so it is loaded once per assembly, three times here, and
REM leaves nothing behind.
REM
REM   MAKE EXIT   assemble and then close DOSBox, for MAKEWIN.BAT. A batch
REM               file started from a DOSBox -c line swallows the -c lines
REM               after it, so the emulator has to be closed from in here.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist HELLO.ASM goto nosource

if exist HELLO.COM del HELLO.COM
if exist HELLO2.EXE del HELLO2.EXE
if exist HEX.COM del HEX.COM

echo Assembling HELLO.ASM ...
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE HELLO.ASM HELLO.COM
if not exist HELLO.COM goto failed

echo Assembling HELLO2.ASM ...
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE HELLO2.ASM HELLO2.EXE
if not exist HELLO2.EXE goto failed

echo Assembling HEX.ASM ...
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE HEX.ASM HEX.COM
if not exist HEX.COM goto failed

echo.
echo Built HELLO.COM, HELLO2.EXE and HEX.COM.
echo.
echo Now look at what you made:   HEX HELLO.COM
echo And change it without assembling anything:
echo.
echo    HEX HELLO.COM 12 WORLD
echo    HELLO
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson's own folder - cd LESSONS\L02 - and make sure
echo you mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo HELLO.ASM is not here. Run MAKE from LESSONS\L02.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. Nothing was
echo overwritten with a broken build.
:end
if "%1"=="EXIT" exit
