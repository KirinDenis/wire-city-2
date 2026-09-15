@echo off
REM ============================================================================
REM RUN.BAT - run lesson 11.
REM
REM The generator, walked. A key moves it on one step.
REM
REM   1        four anchors, and 4092 nodes of nothing
REM   2..11    five octaves: diamond, then square, ten steps. What each step
REM            wrote burns orange and cools to grey on the next one.
REM   12       the histogram stretch - same map, contrast opened up
REM   13       the island: six height bands
REM   then     any key mints another world. HOLD SPACE DOWN.
REM   ESC      back to DOS, from any of them
REM ============================================================================
if not exist TERRAIN.COM goto nothing
echo TERRAIN.COM
TERRAIN.COM
goto end
:nothing
echo.
echo TERRAIN.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
