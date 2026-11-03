@echo off
REM ============================================================================
REM RUN.BAT - run lesson 24: RUN 1, RUN 2, RUN 3 or RUN 4 (4 if nothing said).
REM
REM   RUN 1   the flags register, as it is
REM   RUN 2   written and read back: 8086, 286 or 386
REM   RUN 3   the 32-bit EFLAGS: 386 or 486
REM   RUN 4   CPUID: the processor says its own name
REM
REM Each prints and is back at the prompt. The answer depends on the PC:
REM on the course page, DOS > Settings > CPU picks 386, 486 or Pentium -
REM switch, and run it again.
REM ============================================================================
set P=CPU4
if "%1"=="1" set P=CPU1
if "%1"=="2" set P=CPU2
if "%1"=="3" set P=CPU3
if not exist %P%.COM goto nothing
%P%.COM
goto end
:nothing
echo.
echo %P%.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
set P=
