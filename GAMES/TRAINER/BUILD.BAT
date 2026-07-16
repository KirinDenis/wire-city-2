@echo off
REM Build the flight school inside DOS. Run from THIS folder with
REM TASM + TLINK on the path; the repo root must be the C: drive
REM (the model precompiler lives in \TOOLS).
set PATH=c:pin;d:in;%PATH%
\TOOLS\OBJ2DAT.COM res\PLANE1.OBJ PLANE1.DAT 4
if errorlevel 1 goto err
\TOOLS\OBJ2DAT.COM res\RBASE1.OBJ RBASE1.DAT 4
if errorlevel 1 goto err
\TOOLS\OBJ2DAT.COM res\RDISH1.OBJ RDISH1.DAT 4
if errorlevel 1 goto err
\TOOLS\OBJ2DAT.COM res\TWR1.OBJ TWR1.DAT 12
if errorlevel 1 goto err
\TOOLS\OBJ2DAT.COM res\CKPT1.OBJ CKPT1.DAT 120
if errorlevel 1 goto err
\TOOLS\OBJ2DAT.COM res\CNPY1.OBJ CNPY1.DAT 120
if errorlevel 1 goto err
cd SRC
TASM /T FIELD.ASM
if errorlevel 1 goto errs
TLINK /t FIELD.OBJ
if errorlevel 1 goto errs
copy /y FIELD.COM ..
del FIELD.COM
cd ..
echo.
echo OK -- FIELD built
goto end
:errs
cd ..
:err
echo.
echo BUILD FAILED
:end
