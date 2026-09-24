@echo off
REM ============================================================================
REM BUILD.BAT - compile REFGEN and run it, from inside DOS.
REM
REM Two steps in one batch because a batch started from a DOSBox -c line
REM swallows every -c after it: there is no second command to give.
REM
REM Everything goes to BUILD.LOG as well. DOSBox is started without a console
REM by the Windows side, so a compiler error would otherwise flash past inside
REM a window that closes itself - which is the same as no message at all.
REM
REM   BUILD EXIT   closes DOSBox when the screens are written.
REM ============================================================================
call MAKE.BAT > BUILD.LOG
if not exist REFGEN.EXE goto end
REFGEN.EXE >> BUILD.LOG
:end
if "%1"=="EXIT" exit
