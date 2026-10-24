@echo off
REM ============================================================================
REM RUN.BAT - run lesson 1F: only the palette moves.
REM
REM   The Mandelbrot set is drawn once, row by row - watch it fill - and then
REM   its colours turn, and not one pixel is written again.
REM
REM   SPACE          stop the colours, and start them again
REM   LEFT / RIGHT   turn them slower, faster, the other way
REM   R              draw the picture again, and time it again
REM   ESC            back to DOS (even while it draws)
REM
REM The foot of the screen says what the picture cost in BIOS clock ticks,
REM and what a thousand turns of the whole palette cost.
REM ============================================================================
if not exist MANDEL.COM goto nothing
echo MANDEL.COM
MANDEL.COM
goto end
:nothing
echo.
echo MANDEL.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end