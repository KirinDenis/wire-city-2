@echo off
REM ============================================================================
REM MAKEWIN.BAT - build lesson 5 from Windows, without opening DOSBox.
REM
REM   MAKEWIN         TURN.COM and PIVOT.COM, as MAKE does inside DOS
REM
REM Same shape as GAMES\OWLFLY2\MAKEWIN.BAT, and for the same reason: the
REM assembly happens in DOS either way. What changes is only who types it.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT

REM DOSBOX-X, NOT PLAIN DOSBOX, and this is not a preference. FASM.EXE is a
REM 32-bit program and plain DOSBox 0.74 grants no 32-bit DPMI, so CWSDPMI
REM cannot host it: the assembly silently does nothing and the emulator sits
REM at its own prompt for ever. LOCAL.BAT says so in as many words; this
REM file was written against %DOSBOX% anyway and hung for five minutes.
set DBX=%DOSBOXX%
if "%DBX%"=="" set DBX=%DOSBOX%
if "%DBX%"=="" set DBX=dosbox-x.exe

REM   MAKEWIN RECON   assembles LESSONS\L05\RECON.ASM alone - the lecture
REM                   script replayed into a file, for the check in LESSON.md
REM
REM It runs a DIFFERENT BATCH rather than passing an argument. A batch started
REM from a -c line arrives with %2 empty however it is written, so
REM "MAKE.BAT EXIT RECON" assembles nothing and hangs at the DOS prompt.
set RUN=MAKE.BAT EXIT
if /i "%~1"=="RECON" set RUN=RECON.BAT

echo Assembling in DOS...
"%DBX%" -noautoexec -c "mount c %CD%" -c "c:" -c "cd LESSONS\L05" -c "%RUN%"
if /i "%~1"=="RECON" goto one
if not exist LESSONS\L05\TURN.COM goto failed
REM ZERO BYTES IS NOT A BUILD. A killed or starved assembler leaves the file
REM created and empty, "if exist" is happy with it, and the next thing along
REM reads a program with no instructions in it. This happened.
for %%F in (LESSONS\L05\TURN.COM) do if %%~zF EQU 0 goto empty
echo.
echo Built LESSONS\L05\TURN.COM
goto end

:empty
echo.
echo TURN.COM came out ZERO BYTES - the assembler did not finish. Open
echo DOSBox-X and run MAKE from LESSONS\L05 to see what it said.
goto end

:one
if not exist LESSONS\L05\RECON.COM goto failed
echo.
echo Built LESSONS\L05\RECON.COM
goto end

:failed
echo.
echo Build failed - open DOSBox and run MAKE from LESSONS\L05 to see why.
:end
