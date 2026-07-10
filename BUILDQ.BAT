@echo off
REM Quiet build (run INSIDE DOSBox, usually via MAKE.BAT): assembles the
REM sources in SRC, installs CITY.COM + CITY.DAT into INSTALL, and logs
REM everything to BUILD.LOG in the repo root.
set PATH=c:\bp\bin;d:\bin;%PATH%
echo BUILD START > BUILD.LOG
cd SRC
TASM /T RESDAT.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t RESDAT.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
copy /y RESDAT.COM ..\INSTALL\CITY.DAT >> ..\BUILD.LOG
del RESDAT.COM
TASM /T CITY.ASM >> ..\BUILD.LOG
if errorlevel 1 goto err
TLINK /t CITY.OBJ >> ..\BUILD.LOG
if errorlevel 1 goto err
copy /y CITY.COM ..\INSTALL\CITY.COM >> ..\BUILD.LOG
del CITY.COM
cd ..\EXAMPLES
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
echo BUILD OK >> BUILD.LOG
goto end
:err
cd ..
echo BUILD FAILED >> BUILD.LOG
:end
