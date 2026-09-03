@echo off
REM ============================================================================
REM RUN.BAT - run lesson 0D.
REM
REM Six stages. A key moves the still ones on; a key STOPS the moving ones.
REM
REM   1 standing   2 the shoulder   3 the elbow   4 the wrist
REM   5 the reach - the workspace inking itself
REM   6 the job    - pick, carry, place, and round again, for ever
REM ============================================================================
if not exist ARM.COM goto nothing
echo ARM.COM
ARM.COM
goto end
:nothing
echo.
echo ARM.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
