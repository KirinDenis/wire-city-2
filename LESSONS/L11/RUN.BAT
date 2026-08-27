@echo off
REM ============================================================================
REM RUN.BAT - run lesson 11.
REM
REM The port, the BIOS pair and its buffer trap, the DOS line - and the
REM square that drives on our own INT 9. ESC moves the listening frames
REM on; a key moves the still ones; ESC leaves the square.
REM ============================================================================
if not exist KEYS.COM goto nothing
echo KEYS.COM
KEYS.COM
goto end
:nothing
echo.
echo KEYS.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
