@echo off
REM ============================================================================
REM RECON.BAT - assemble RECON.ASM, and nothing else.
REM
REM The reconstruction check: the episode script's typed lines are replayed
REM into RECON.ASM by the director and put through the same assembler, to
REM prove the take will build what the repository holds BEFORE ninety
REM minutes of typing are spent finding out that it will not. Lesson 4 was
REM recorded without this check and broke at step 45.
REM
REM RECON.ASM is scratch: gitignored, safe to delete. Byte-compare the
REM RECON.COM this produces against MENU.COM - identical or the script and
REM the program have diverged.
REM ============================================================================
if not exist ..\FASM\FASM.EXE goto nofasm
if not exist RECON.ASM goto nosource

echo Assembling RECON.ASM ...
if exist RECON.COM del RECON.COM
..\CWSDPMI\CWSDPMI.EXE
..\FASM\FASM.EXE RECON.ASM RECON.COM
if not exist RECON.COM goto failed
echo.
echo Built RECON.COM
goto end

:nofasm
echo ..\FASM\FASM.EXE not found - run this from TOOLS\MENU.
goto end
:nosource
echo RECON.ASM not found - the checker writes it before calling this.
goto end
:failed
echo.
echo RECON.ASM did NOT assemble - the script and the program have diverged.
:end
exit
