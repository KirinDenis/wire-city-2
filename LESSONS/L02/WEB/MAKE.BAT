@echo off
REM ============================================================================
REM MAKE.BAT - the BROWSER copy. Same build, flat paths.
REM
REM This is not the lesson's MAKE.BAT. The one a folder up reaches the
REM assembler through ..\..\TOOLS\FASM, because in the repository that is
REM where it lives. Inside the .jsdos bundle there is no repository: every
REM file sits in one directory, which is the whole of drive C:, so the paths
REM have to be different. The COMMANDS are identical, and that matters -
REM whichever machine you type MAKE on, the same assembler produces the same
REM bytes.
REM
REM CWSDPMI is loaded before each assembly for the same reason as always: FASM
REM is a 32-bit program, DOS is not, and with no arguments CWSDPMI stays
REM resident for exactly one program and then unloads itself.
REM ============================================================================
if exist HELLO.COM del HELLO.COM
if exist HELLO2.EXE del HELLO2.EXE
if exist HEX.COM del HEX.COM

echo Assembling HELLO.ASM ...
CWSDPMI.EXE
FASM.EXE HELLO.ASM HELLO.COM
if not exist HELLO.COM goto failed

echo Assembling HELLO2.ASM ...
CWSDPMI.EXE
FASM.EXE HELLO2.ASM HELLO2.EXE
if not exist HELLO2.EXE goto failed

echo Assembling HEX.ASM ...
CWSDPMI.EXE
FASM.EXE HEX.ASM HEX.COM
if not exist HEX.COM goto failed

echo.
echo Built HELLO.COM, HELLO2.EXE and HEX.COM - you just assembled them.
echo.
echo    HEX HELLO.COM     look at the eighteen bytes
echo    HELLO             run it
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. Nothing was
echo overwritten with a broken build. Type HELP for the way back.
:end
