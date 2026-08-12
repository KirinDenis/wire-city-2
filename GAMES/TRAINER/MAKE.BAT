@echo off
REM ============================================================================
REM MAKE.BAT - assemble the flight school, from inside DOS.
REM
REM   cd GAMES\TRAINER
REM   MAKE                       ->  FIELD.COM and the model tables
REM
REM TWO STEPS, and the first one is easy to forget. The aeroplane, the radar
REM base, its dish, the tower, the cockpit and the canopy are Wavefront .OBJ
REM files in res\, and the game cannot read text at runtime - so OBJ2DAT packs
REM each one into a .DAT table first. The number after each is the scale
REM divisor, and it is not decoration: change it and the model changes size.
REM
REM Run MAKE from this folder. Every path below is relative to here on
REM purpose: a path from a drive root only works if the repository happens to
REM be mounted AS a drive root, and mounting the folder above it - a perfectly
REM ordinary thing to do - would leave every tool path pointing at nothing.
REM
REM   MAKE EXIT   assembles and then closes DOSBox, for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist ..\..\TOOLS\OBJ2DAT.COM goto noobj2dat
if not exist SRC\FIELD.ASM goto nosource

echo Packing the models ...
..\..\TOOLS\OBJ2DAT.COM res\PLANE1.OBJ PLANE1.DAT 4
..\..\TOOLS\OBJ2DAT.COM res\RBASE1.OBJ RBASE1.DAT 4
..\..\TOOLS\OBJ2DAT.COM res\RDISH1.OBJ RDISH1.DAT 4
..\..\TOOLS\OBJ2DAT.COM res\TWR1.OBJ TWR1.DAT 12
..\..\TOOLS\OBJ2DAT.COM res\CKPT1.OBJ CKPT1.DAT 120
..\..\TOOLS\OBJ2DAT.COM res\CNPY1.OBJ CNPY1.DAT 120
if not exist PLANE1.DAT goto nomodels

echo Assembling SRC\FIELD.ASM ...
if exist FIELD.COM del FIELD.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SRC\FIELD.ASM FIELD.COM
if not exist FIELD.COM goto failed
echo.
echo Built FIELD.COM.  Type RUN to fly it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from GAMES\TRAINER, and make sure you mounted the whole
echo repository rather than just this directory.
goto end

:noobj2dat
echo.
echo ..\..\TOOLS\OBJ2DAT.COM is not built. Build it first:
echo     cd ..\..\TOOLS
echo     MAKE
goto end

:nosource
echo.
echo SRC\FIELD.ASM is not here. Run MAKE from GAMES\TRAINER.
goto end

:nomodels
echo.
echo The model tables were not written - see the messages above.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. FIELD.COM was not
echo written, so nothing was overwritten with a broken build.

:end
if "%1"=="EXIT" exit
