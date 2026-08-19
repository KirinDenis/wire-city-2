@echo off
REM ============================================================================
REM RECON.BAT - assemble RECON.ASM, and nothing else.
REM
REM The lecture script typed lines are replayed into RECON.ASM by the director
REM and put through the same assembler, to prove the lesson builds what the
REM repository holds BEFORE a take is spent finding out that it does not.
REM Lesson 4 was recorded without this check and broke at step 45.
REM
REM RECON.ASM is scratch: gitignored, and safe to delete.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist RECON.ASM goto nosource
if not exist DRAW7.INC goto notable

echo Assembling RECON.ASM ...
if exist RECON.COM del RECON.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE RECON.ASM RECON.COM
if not exist RECON.COM goto failed
echo.
echo Built RECON.COM
goto end

:nofasm
echo TOOLS\FASM\FASM.EXE not found - run this from LESSONS\L07.
goto end
:nosource
echo RECON.ASM not found - the checker writes it before calling this.
goto end
:notable
echo DRAW7.INC not found.
goto end
:failed
echo.
echo RECON.ASM did NOT assemble - the script and the program have diverged.
:end
exit
