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
TASM /T SPOOL.ASM
if errorlevel 1 goto err
TLINK /t SPOOL.OBJ
if errorlevel 1 goto err
TASM /T TKOFF.ASM
if errorlevel 1 goto err
TLINK /t TKOFF.OBJ
if errorlevel 1 goto err
TASM /T FLIGHT.ASM
if errorlevel 1 goto err
TLINK /t FLIGHT.OBJ
if errorlevel 1 goto err
TASM /T LAND.ASM
if errorlevel 1 goto err
TLINK /t LAND.OBJ
if errorlevel 1 goto err
TASM /T TKPHYS.ASM
if errorlevel 1 goto err
TLINK /t TKPHYS.OBJ
if errorlevel 1 goto err
TASM /T LNDPHYS.ASM
if errorlevel 1 goto err
TLINK /t LNDPHYS.OBJ
if errorlevel 1 goto err
TASM /T SOLO.ASM
if errorlevel 1 goto err
TLINK /t SOLO.OBJ
if errorlevel 1 goto err
echo.
echo OK -- the whole air force built
goto end
:err
echo.
echo BUILD FAILED
:end
