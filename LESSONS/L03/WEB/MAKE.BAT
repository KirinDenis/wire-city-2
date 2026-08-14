@echo off
REM ============================================================================
REM MAKE.BAT - the BROWSER copy. Same build, flat paths.
REM
REM This is not the lesson's MAKE.BAT. The one a folder up reaches the
REM assembler through ..\..\TOOLS\FASM, because in the repository that is
REM where it lives. Inside the .jsdos bundle there is no repository: every
REM file sits in one directory, which is the whole of drive C:. The COMMANDS
REM are identical, and that is what matters - whichever machine you type MAKE
REM on, the same assembler produces the same 257 bytes.
REM ============================================================================
if exist PIXEL.COM del PIXEL.COM
echo Assembling PIXEL.ASM ...
CWSDPMI.EXE
FASM.EXE PIXEL.ASM PIXEL.COM
if not exist PIXEL.COM goto failed
echo.
echo Built PIXEL.COM - you just assembled it. Type RUN.
echo A key moves to the next frame; there are six.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. Nothing was
echo overwritten with a broken build. Type HELP for the way back.
:end
