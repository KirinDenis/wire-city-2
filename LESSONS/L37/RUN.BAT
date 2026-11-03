@echo off
REM ============================================================================
REM RUN.BAT - run lesson 25: RUN 1, RUN 2, RUN 3 or RUN 4 (4 if nothing said).
REM
REM   RUN 1   the registers: 32 bits, the low half keeps its 8086 name
REM   RUN 2   the addresses: any register, times 1, 2, 4 or 8
REM   RUN 3   the new instructions: one where the 8086 needed several
REM   RUN 4   what did not change: one address an instruction
REM
REM Each prints the 8086's way and the 386's side by side and is back at the
REM prompt. On an 8086 or a 286 each says it needs an 80386, and stops.
REM ============================================================================
set P=R4
if "%1"=="1" set P=R1
if "%1"=="2" set P=R2
if "%1"=="3" set P=R3
if not exist %P%.COM goto nothing
%P%.COM
goto end
:nothing
echo.
echo %P%.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
set P=
