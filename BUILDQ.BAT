@echo off
REM BUILDQ.BAT %1 - runs INSIDE DOSBox (via MAKE.BAT), C: = repo root.
REM Targets: ALL | OWLFLY | WIRECITY | EXAMPLES. Case matters (DOSBox).
set PATH=c:\bp\bin;d:\bin;%PATH%
echo BUILD START > BUILD.LOG
if "%1"=="OWLFLY" goto owlfly
if "%1"=="WIRECITY" goto wirecity
if "%1"=="EXAMPLES" goto examples

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
cd ..

:ok
echo BUILD OK >> C:\BUILD.LOG
goto end
:err
echo BUILD FAILED >> C:\BUILD.LOG
:end
exit
