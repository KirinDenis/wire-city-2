@echo off
REM ============================================================================
REM RUN.BAT - run lesson 6.
REM
REM   RUN           the clocks     (CLOCK.COM)
REM   RUN CIRCLE    the circle     (CIRCLE.COM)
REM   RUN PIVOT     the square     (PIVOT.COM)
REM
REM Any key moves from one frame to the next; ESC leaves the moving ones.
REM ============================================================================
if not "%1"=="" goto named
if not exist CLOCK.COM goto nothing
CLOCK.COM
goto end

:named
if not exist %1.COM goto nothing1
%1.COM
goto end

:nothing
echo.
echo CLOCK.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
goto end

:nothing1
echo.
echo %1.COM is not built yet. Type MAKE first.
:end
