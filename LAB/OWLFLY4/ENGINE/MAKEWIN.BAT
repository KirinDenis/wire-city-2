@echo off
REM ============================================================================
REM MAKEWIN.BAT - build the story engine from Windows, without opening DOSBox
REM by hand. It does not reimplement the build: it starts DOSBox and runs this
REM folder's own MAKE.BAT with the argument EXIT, so the emulator closes
REM itself when the assembler is done. There is one build, and it is the DOS
REM one, because that is the one a stranger will actually run.
REM ============================================================================
cd /d %~dp0..\..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd LAB\OWLFLY4\ENGINE" -c "MAKE.BAT EXIT"
if not exist LAB\OWLFLY4\ENGINE\STORY.COM goto failed
echo.
echo Built LAB\OWLFLY4\ENGINE\STORY.COM
goto end

:failed
echo.
echo Build failed - see LAB\OWLFLY4\ENGINE\BUILD.LOG.
:end
