@echo off
REM ============================================================================
REM RUN.BAT - run lesson 9.
REM
REM Five screens: the bytes of an instruction, the two crosses, the trap of
REM the prefetch queue, the debt walk, and the fan. Any key moves on.
REM ============================================================================
if not exist SMC.COM goto nothing
echo SMC.COM
SMC.COM
goto end
:nothing
echo.
echo SMC.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
