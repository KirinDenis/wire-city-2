@echo off
REM ============================================================================
REM RUN.BAT - run lesson 1A.
REM
REM   1 the island from above, and the mark where you are about to stand:
REM     five squares short of the island's biggest town, facing it.
REM     SPACE takes off.
REM   2 the flight - lesson 19's, all three axes - and the numbers in the
REM     corner are written in letters the program draws itself.
REM
REM   T              the next kind of letters, named at the bottom of the
REM                  screen: the ROM's 8x8, the game's 4x6, the 4x6 with
REM                  a grey ring that keeps it readable on any background
REM   LEFT / RIGHT   roll
REM   DOWN / UP      pull / push
REM   1 / 3          the pedals (and 7 / 9 on the number pad)
REM   W / S          throttle up / down
REM   A              the afterburner, while it is held
REM   N              night, and N again for day - watch the ring at night
REM   F              FAST or CLASSIC arithmetic, flipped in flight
REM   SPACE          after a crash: another aeroplane
REM   ESC            land
REM
REM Top left: frames a second, then THR, SPD, ALT, HDG, and the pitch and
REM bank with their signs.
REM ============================================================================
if not exist LETTERS.COM goto nothing
echo LETTERS.COM
LETTERS.COM
goto end
:nothing
echo.
echo LETTERS.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
