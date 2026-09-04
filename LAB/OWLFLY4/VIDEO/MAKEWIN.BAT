@echo off
REM ============================================================================
REM MAKEWIN.BAT - build the video workbench from Windows, without opening
REM DOSBox by hand.
REM
REM   MAKEWIN           assemble everything, exactly the way MAKE does in DOS
REM
REM It does not reimplement the build: it starts DOSBox and runs this folder's
REM own MAKE.BAT with the argument EXIT, so the emulator closes itself when
REM the assembler is done. There is one build, and it is the DOS one, because
REM that is the one a stranger will actually run.
REM ============================================================================
cd /d %~dp0..\..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd LAB\OWLFLY4\VIDEO" -c "MAKE.BAT EXIT"
if not exist LAB\OWLFLY4\VIDEO\VESATEST.COM goto failed
echo.
echo Built LAB\OWLFLY4\VIDEO\VESATEST.COM
goto end

:failed
echo.
echo Build failed - see the messages above.
:end
