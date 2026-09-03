@echo off
REM ============================================================================
REM RUN.BAT - run lesson 12.
REM
REM Words, Sun and Earth, the Moon, the whole sky writing its lace, the
REM planetarium with its green arms, words again. A key moves the still
REM frames on; a key STOPS the moving ones - the sky turns until told not to.
REM ============================================================================
if not exist ORBITS.COM goto nothing
echo ORBITS.COM
ORBITS.COM
goto end
:nothing
echo.
echo ORBITS.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
