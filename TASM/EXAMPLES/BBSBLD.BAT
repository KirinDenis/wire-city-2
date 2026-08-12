@echo off
set PATH=c:\bp\bin;d:\bin;%PATH%
cd EXAMPLES
TASM /T BBS.ASM > BUILD.LOG
if errorlevel 1 goto err
TLINK /t BBS.OBJ >> BUILD.LOG
if errorlevel 1 goto err
echo OK >> BUILD.LOG
goto end
:err
echo FAILED >> BUILD.LOG
:end
