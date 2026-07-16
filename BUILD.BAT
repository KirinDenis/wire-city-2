@echo off
REM ==========================================================================
REM BUILD.BAT - the DOS-side master build: every game + the examples,
REM in ONE batch with no nested CALLs (DOSBox resumes a parent batch by
REM RELATIVE name in the CURRENT dir - nested calls die after the first
REM child). Each folder also has its own standalone BUILD.BAT.
REM Run inside DOS/DOSBox from the repo root, TASM + TLINK on the path.
REM ==========================================================================
set PATH=c:\bp\bin;d:\bin;%PATH%

echo ===== GAMES\OWLFLY =====
cd GAMES\OWLFLY\SRC
TASM /T RESDAT.ASM
if errorlevel 1 goto err3
TLINK /t RESDAT.OBJ
if errorlevel 1 goto err3
copy /y RESDAT.COM ..\INSTALL\CITY.DAT
del RESDAT.COM
TASM /T CITY.ASM
if errorlevel 1 goto err3
TLINK /t CITY.OBJ
if errorlevel 1 goto err3
copy /y CITY.COM ..\INSTALL\FLYOWL.COM
del CITY.COM
cd ..\..\..

echo ===== GAMES\WIRECITY =====
cd GAMES\WIRECITY
TASM /T CITY.ASM
if errorlevel 1 goto err2
TLINK /t CITY.OBJ
if errorlevel 1 goto err2
cd ..\..

echo ===== EXAMPLES =====
cd EXAMPLES
TASM /T TERRA.ASM
if errorlevel 1 goto err1
TLINK /t TERRA.OBJ
if errorlevel 1 goto err1
TASM /T RING.ASM
if errorlevel 1 goto err1
TLINK /t RING.OBJ
if errorlevel 1 goto err1
TASM /T JET.ASM
if errorlevel 1 goto err1
TLINK /t JET.OBJ
if errorlevel 1 goto err1
TASM /T AVIO.ASM
if errorlevel 1 goto err1
TLINK /t AVIO.OBJ
if errorlevel 1 goto err1
TASM /T SMOKE.ASM
if errorlevel 1 goto err1
TLINK /t SMOKE.OBJ
if errorlevel 1 goto err1
cd ..

echo ===== TOOLS =====
cd TOOLS
TASM /T OBJ2DAT.ASM
if errorlevel 1 goto err1
TLINK /t OBJ2DAT.OBJ
if errorlevel 1 goto err1
cd ..

echo ===== GAMES\TRAINER =====
cd GAMES\TRAINER
\TOOLS\OBJ2DAT.COM res\PLANE1.OBJ PLANE1.DAT 4
if errorlevel 1 goto err2
\TOOLS\OBJ2DAT.COM res\RBASE1.OBJ RBASE1.DAT 4
if errorlevel 1 goto err2
\TOOLS\OBJ2DAT.COM res\RDISH1.OBJ RDISH1.DAT 4
if errorlevel 1 goto err2
\TOOLS\OBJ2DAT.COM res\TWR1.OBJ TWR1.DAT 12
if errorlevel 1 goto err2
\TOOLS\OBJ2DAT.COM res\CKPT1.OBJ CKPT1.DAT 120
if errorlevel 1 goto err2
\TOOLS\OBJ2DAT.COM res\CNPY1.OBJ CNPY1.DAT 120
if errorlevel 1 goto err2
cd SRC
TASM /T FIELD.ASM
if errorlevel 1 goto err3
TLINK /t FIELD.OBJ
if errorlevel 1 goto err3
copy /y FIELD.COM ..
del FIELD.COM
cd ..\..\..

echo.
echo ALL BUILT: FLYOWL, WIRECITY, TRAINER, EXAMPLES, TOOLS
goto end
:err3
cd ..\..\..
goto fail
:err2
cd ..\..
goto fail
:err1
cd ..
:fail
echo.
echo BUILD FAILED - see the messages above
:end
