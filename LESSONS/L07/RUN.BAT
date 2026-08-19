@echo off
REM ============================================================================
REM RUN.BAT - run lesson 7.
REM
REM Four screens: the toy memory explained, the run across, the run down, and
REM then the real thing in mode 13h. Any key moves on.
REM ============================================================================
if not exist LINE.COM goto nothing
echo LINE.COM
LINE.COM
goto end
:nothing
echo.
echo LINE.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
