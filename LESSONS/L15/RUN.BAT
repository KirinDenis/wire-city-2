@echo off
REM ============================================================================
REM RUN.BAT - run lesson 0F.
REM
REM Six stages. A key moves the still ones on; a key STOPS the moving ones.
REM
REM   1 flat, as lesson 0E left it     2 the divide: the far face shrinks
REM   3 it comes towards you and GROWS 4 the table, on top of the divide
REM   5 the near plane: it comes, and it STOPS
REM   6 the divide with no guard. It does not stop. IDIV overflows, the
REM     machine raises INT 0, and the program's OWN handler ends it with
REM     three lines saying why. That is the lesson. ESC AT STAGE 5 SKIPS IT.
REM ============================================================================
if not exist PERSP.COM goto nothing
echo PERSP.COM
PERSP.COM
goto end
:nothing
echo.
echo PERSP.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
