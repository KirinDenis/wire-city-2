@echo off
REM ============================================================================
REM RUN.BAT - run lesson 23: RUN MUL or RUN NOMUL (NOMUL if nothing is said).
REM
REM   1 the island from above - the SAME island every time in this lesson,
REM     so the two programs can be compared. SPACE takes off.
REM   2 the flight, lesson 22's, with the meter:
REM
REM   M              count the multiplies and divides of the NEXT frame. That
REM                  frame is slow - every instruction stops for the counter
REM                  - and the numbers stay under the frame rate
REM   SPACE          the gun, while it is held; after a crash, another aeroplane
REM   LEFT / RIGHT   roll
REM   DOWN / UP      pull / push
REM   1 / 3          the pedals (and 7 / 9 on the number pad)
REM   W / S          throttle up / down
REM   A              the afterburner, while it is held
REM   B              a target to practise on
REM   T, N, F        the letters, night, the arithmetic
REM   F4             the eye outside
REM   ESC            land
REM
REM Fly MUL, press M; fly NOMUL the same way, press M; compare.
REM ============================================================================
set P=NOMUL
if /i "%1"=="MUL" set P=MUL
if not exist %P%.COM goto nothing
echo %P%.COM
%P%.COM
goto end
:nothing
echo.
echo %P%.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
set P=
