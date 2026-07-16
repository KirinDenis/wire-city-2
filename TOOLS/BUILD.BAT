@echo off
REM Build the model precompiler inside DOS. Run from THIS folder
REM (TOOLS) with TASM + TLINK on the path.
set PATH=c:\bp\bin;d:\bin;%PATH%
TASM /T OBJ2DAT.ASM
if errorlevel 1 goto err
TLINK /t OBJ2DAT.OBJ
if errorlevel 1 goto err
echo.
echo OK -- OBJ2DAT built
goto end
:err
echo.
echo BUILD FAILED
:end
