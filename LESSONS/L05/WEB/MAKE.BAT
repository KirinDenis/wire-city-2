@echo off
REM ============================================================================
REM MAKE.BAT - the BROWSER copy. Same build, flat paths.
REM
REM This is not the lesson's MAKE.BAT. The one a folder up reaches the
REM assembler through ..\..\TOOLS\FASM, because in the repository that is
REM where it lives. Inside the .jsdos bundle there is no repository: every
REM file sits in one directory, which is the whole of drive C:. The COMMANDS
REM are identical, and that is what matters - whichever machine you type MAKE
REM on, the same assembler produces the same 771 bytes.
REM
REM SINT.INC IS NOT BUILT HERE and cannot be. It is the output of MKSIN.C,
REM which needs a C compiler and floating point - neither is in this bundle,
REM and that is the lesson's own argument: the modern tool prepares the data
REM on another machine, and the 8086 never meets it. MKSIN.C travels along
REM so you can read what made the table.
REM ============================================================================
if exist TURN.COM del TURN.COM
echo Assembling TURN.ASM ...
CWSDPMI.EXE
FASM.EXE TURN.ASM TURN.COM
if not exist TURN.COM goto failed
echo.
echo Built TURN.COM - you just assembled it. Type RUN.
echo A key moves to the next frame; there are four.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. Nothing was
echo overwritten with a broken build. Type HELP for the way back.
:end
