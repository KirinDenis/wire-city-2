@echo off
REM ============================================================================
REM RUN.BAT - run lesson 0E.
REM
REM Nine stages. A key moves the still ones on; a key STOPS the moving ones.
REM
REM   1 the origin and one corner      2 all eight corner-vectors
REM   3 the edge list joins them       4 the scaffolding hidden
REM   5 turned, one axis then two      6 moved in X and Y
REM   7 moved in Z - and NOTHING happens: that is "no perspective"
REM   8 turned slowly - you can see straight through it: WIREFRAME
REM   9 the two turns, swapped: they do not land in the same place
REM ============================================================================
if not exist CUBE.COM goto nothing
echo CUBE.COM
CUBE.COM
goto end
:nothing
echo.
echo CUBE.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
