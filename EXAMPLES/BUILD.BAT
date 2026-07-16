@echo off
REM Build the teaching machines inside DOS. Run from THIS folder
REM (EXAMPLES) with TASM + TLINK on the path. Each .COM stays here.
set PATH=c:\bp\bin;d:\bin;%PATH%
TASM /T TERRA.ASM
if errorlevel 1 goto err
TLINK /t TERRA.OBJ
if errorlevel 1 goto err
TASM /T RING.ASM
if errorlevel 1 goto err
TLINK /t RING.OBJ
if errorlevel 1 goto err
TASM /T JET.ASM
if errorlevel 1 goto err
TLINK /t JET.OBJ
if errorlevel 1 goto err
TASM /T AVIO.ASM
if errorlevel 1 goto err
TLINK /t AVIO.OBJ
if errorlevel 1 goto err
TASM /T SMOKE.ASM
if errorlevel 1 goto err
TLINK /t SMOKE.OBJ
if errorlevel 1 goto err
echo.
echo OK -- TERRA, RING, JET, AVIO built
goto end
:err
echo.
echo BUILD FAILED
:end
