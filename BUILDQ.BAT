@echo off
REM BUILDQ.BAT %1 - runs INSIDE DOSBox (via MAKE.BAT), C: = repo root.
REM Targets: ALL | OWLFLY | OWLFLY2 | WIRECITY | EXAMPLES | TRAINER |
REM NEWTON. Case matters (DOSBox).
set PATH=c:\bp\bin;d:\bin;%PATH%
echo BUILD START > BUILD.LOG
if "%1"=="OWLFLY" goto owlfly
if "%1"=="OWLFLY2" goto owlfly2
if "%1"=="WIRECITY" goto wirecity
if "%1"=="EXAMPLES" goto examples
if "%1"=="TOOLS" goto tools
if "%1"=="TRAINER" goto trainer
if "%1"=="NEWTON" goto newton

:owlfly
cd GAMES\OWLFLY\SRC
TASM /T RESDAT.ASM >> ..\..\..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t RESDAT.OBJ >> ..\..\..\BUILD.LOG
if errorlevel 1 goto err
copy /y RESDAT.COM ..\INSTALL\CITY.DAT >> ..\..\..\BUILD.LOG
del RESDAT.COM
TASM /T CITY.ASM >> ..\..\..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t CITY.OBJ >> ..\..\..\BUILD.LOG
if errorlevel 1 goto err
copy /y CITY.COM ..\INSTALL\FLYOWL.COM >> ..\..\..\BUILD.LOG
del CITY.COM
cd ..\..\..
if "%1"=="OWLFLY" goto ok

:wirecity
cd GAMES\WIRECITY
TASM /T CITY.ASM >> ..\..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t CITY.OBJ >> ..\..\BUILD.LOG
if errorlevel 1 goto err
cd ..\..
if "%1"=="WIRECITY" goto ok

:examples
cd EXAMPLES
TASM /T TERRA.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t TERRA.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
TASM /T RING.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t RING.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
TASM /T JET.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t JET.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
TASM /T AVIO.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t AVIO.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
TASM /T SMOKE.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t SMOKE.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
TASM /T SPOOL.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t SPOOL.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
TASM /T TKOFF.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t TKOFF.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
TASM /T FLIGHT.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t FLIGHT.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
TASM /T LAND.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t LAND.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
TASM /T TKPHYS.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t TKPHYS.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
TASM /T LNDPHYS.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t LNDPHYS.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
TASM /T SOLO.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t SOLO.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
cd ..
if "%1"=="EXAMPLES" goto ok

:tools
cd TOOLS
TASM /T OBJ2DAT.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t OBJ2DAT.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
cd ..
if "%1"=="TOOLS" goto ok

:trainer
cd GAMES\TRAINER
\TOOLS\OBJ2DAT.COM res\PLANE1.OBJ PLANE1.DAT 4 >> ..\..\BUILD.LOG
if errorlevel 1 goto err
\TOOLS\OBJ2DAT.COM res\RBASE1.OBJ RBASE1.DAT 4 >> ..\..\BUILD.LOG
if errorlevel 1 goto err
\TOOLS\OBJ2DAT.COM res\RDISH1.OBJ RDISH1.DAT 4 >> ..\..\BUILD.LOG
if errorlevel 1 goto err
\TOOLS\OBJ2DAT.COM res\TWR1.OBJ TWR1.DAT 12 >> ..\..\BUILD.LOG
if errorlevel 1 goto err
\TOOLS\OBJ2DAT.COM res\CKPT1.OBJ CKPT1.DAT 120 >> ..\..\BUILD.LOG
if errorlevel 1 goto err
\TOOLS\OBJ2DAT.COM res\CNPY1.OBJ CNPY1.DAT 120 >> ..\..\BUILD.LOG
if errorlevel 1 goto err
cd SRC
TASM /T FIELD.ASM >> ..\..\..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t FIELD.OBJ >> ..\..\..\BUILD.LOG
if errorlevel 1 goto err
copy /y FIELD.COM .. >> ..\..\..\BUILD.LOG
del FIELD.COM
cd ..\..\..
if "%1"=="TRAINER" goto ok

:owlfly2
cd GAMES\OWLFLY2\SRC
TASM /T RESDAT.ASM >> ..\..\..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t RESDAT.OBJ >> ..\..\..\BUILD.LOG
if errorlevel 1 goto err
copy /y RESDAT.COM ..\INSTALL\CITY.DAT >> ..\..\..\BUILD.LOG
del RESDAT.COM
TASM /T CITY.ASM >> ..\..\..\BUILD.LOG
if errorlevel 1 goto err
TLINK CITY.OBJ >> ..\..\..\BUILD.LOG
if errorlevel 1 goto err
copy /y CITY.EXE ..\INSTALL\FLYOWL2.EXE >> ..\..\..\BUILD.LOG
del CITY.EXE
cd ..\..\..
if "%1"=="OWLFLY2" goto ok

:newton
cd GAMES\NEWTON\SRC
TASM /T NEWTON.ASM >> ..\..\..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t NEWTON.OBJ >> ..\..\..\BUILD.LOG
if errorlevel 1 goto err
copy /y NEWTON.COM .. >> ..\..\..\BUILD.LOG
del NEWTON.COM
cd ..\..\..

:ok
echo BUILD OK >> C:\BUILD.LOG
goto end
:err
echo BUILD FAILED >> C:\BUILD.LOG
:end
exit
