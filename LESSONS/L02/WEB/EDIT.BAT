@echo off
REM ============================================================================
REM EDIT.BAT - open a source in FASM's own DOS editor.
REM
REM   EDIT HELLO.ASM
REM
REM FASMD.EXE is the editor and assembler that ship together in the flat
REM assembler package - so the browser lesson needs no file manager, no
REM EDIT.COM and nothing else borrowed. Ctrl+F9 assembles what is on screen.
REM
REM CWSDPMI is loaded first for the same reason MAKE.BAT loads it: FASMD is a
REM 32-bit program. With no arguments CWSDPMI serves exactly one program and
REM unloads itself when that program exits, so leaving the editor leaves the
REM machine as it was.
REM ============================================================================
if "%1"=="" goto nofile
if not exist %1 goto missing
CWSDPMI.EXE
FASMD.EXE %1
goto end

:nofile
echo.
echo Which file? Try:  EDIT HELLO.ASM
goto end

:missing
echo.
echo There is no %1 here. Type DIR to see what there is.
:end
