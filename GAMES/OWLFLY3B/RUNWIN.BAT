@echo off
REM ============================================================================
REM RUNWIN.BAT - OWL FLY III BOND from Windows: opens DOSBox, runs it, closes again.
REM Inside DOS the equivalent is simply RUN, in this folder.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if not exist GAMES\OWLFLY3B\INSTALL\OWLFLY3B.EXE goto missing
"%DOSBOX%" -noautoexec -c "mount c %CD%" -c "c:" -c "cd GAMES\OWLFLY3B\INSTALL" -c "OWLFLY3B.EXE" -c "exit"
goto end

:missing
echo GAMES\OWLFLY3B\INSTALL\OWLFLY3B.EXE is not built. Run MAKEWIN.BAT here first.
:end
