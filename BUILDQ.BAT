@echo off
REM Quiet build: same steps as BUILD.BAT, output captured to BUILD.LOG
set PATH=c:\bp\bin;d:\bin;%PATH%
echo BUILD START > BUILD.LOG
TASM /T RESDAT.ASM >> BUILD.LOG
if errorlevel 1 goto err
TLINK /t RESDAT.OBJ >> BUILD.LOG
if errorlevel 1 goto err
copy /y RESDAT.COM CITY.DAT >> BUILD.LOG
del RESDAT.COM
TASM /T CITY.ASM >> BUILD.LOG
if errorlevel 1 goto err
TLINK /t CITY.OBJ >> BUILD.LOG
if errorlevel 1 goto err
echo BUILD OK >> BUILD.LOG
goto end
:err
echo BUILD FAILED >> BUILD.LOG
:end
