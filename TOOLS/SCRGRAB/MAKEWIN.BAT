@echo off
REM ============================================================================
REM MAKEWIN.BAT - build SCRGRAB from Windows, without opening DOSBox by hand.
REM
REM It does not reimplement the build: it starts DOSBox and runs this folder's
REM own MAKE.BAT with the argument EXIT, so the emulator closes itself when
REM the assembler is done. There is one build and it is the DOS one.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd TOOLS\SCRGRAB" -c "MAKE.BAT EXIT"
if not exist TOOLS\SCRGRAB\SCRGRAB.COM goto failed
echo.
echo Built TOOLS\SCRGRAB\SCRGRAB.COM
goto end

:failed
echo.
echo Build failed - see the messages above.
:end
