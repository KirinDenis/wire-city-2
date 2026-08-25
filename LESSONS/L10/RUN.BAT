@echo off
REM ============================================================================
REM RUN.BAT - run lesson 10.
REM
REM Words, one vector, four, edges, the turn, wireframe, translate, scale,
REM words again. A key moves the still frames on; a key STOPS the moving
REM ones - the picture turns until told not to.
REM ============================================================================
if not exist SQUARE.COM goto nothing
echo SQUARE.COM
SQUARE.COM
goto end
:nothing
echo.
echo SQUARE.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
