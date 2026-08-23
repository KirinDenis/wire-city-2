@echo off
REM ============================================================================
REM RUN.BAT - run lesson 8.
REM
REM Five screens: the bytes of an instruction, the two crosses, the trap of
REM the prefetch queue, the debt walk, and the fan. Any key moves on.
REM ============================================================================
if not exist SLANT.COM goto nothing
echo SLANT.COM
SLANT.COM
goto end
:nothing
echo.
echo SLANT.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
