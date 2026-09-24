@echo off
REM ============================================================================
REM MAKE.BAT - compile REFGEN, from inside DOS.
REM
REM Drive D: must be Borland Pascal - MAKEWIN.BAT mounts it from TASMDIR.
REM The units live in D:\UNITS; BPC.CFG inside Borland points at C:\BP\UNITS,
REM which is not where we mounted it, so the path is given here instead.
REM
REM   MAKE EXIT   compiles and then closes DOSBox, for MAKEWIN.BAT.
REM ============================================================================
if not exist D:\BIN\TPC.EXE goto nobp
if not exist REFGEN.PAS goto nosource

echo Compiling REFGEN.PAS ...
if exist REFGEN.EXE del REFGEN.EXE

REM The compiler's own output goes to a file AND to the screen. DOS has no
REM tee, and CALL does not carry a redirection into the batch it calls, so a
REM caller cannot capture this from outside - it has to be done here. Without
REM it a compiler error inside a windowless DOSBox is simply invisible.
D:\BIN\TPC.EXE REFGEN.PAS /UD:\UNITS > MAKE.LOG
type MAKE.LOG

if not exist REFGEN.EXE goto failed
echo.
echo Built REFGEN.EXE.  Type RUN to generate the reference screens.
goto end

:nobp
echo.
echo D:\BIN\TPC.EXE is not there. Drive D: should be Borland Pascal -
echo set TASMDIR in LOCAL.BAT and start this through MAKEWIN.BAT.
goto end

:nosource
echo.
echo REFGEN.PAS is not here. Run MAKE from TOOLS\REFGEN.
goto end

:failed
echo.
echo Compilation failed - the reason is printed just above.
:end
if "%1"=="EXIT" exit
