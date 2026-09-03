@echo off
REM ============================================================================
REM MAKEWIN.BAT - build lesson 0D from Windows, without opening DOSBox by hand.
REM
REM   MAKEWIN         assemble it, exactly the way MAKE does inside DOS
REM
REM It does not reimplement the build: it starts DOSBox and runs this folder's
REM own MAKE.BAT with the argument EXIT, so the emulator closes itself when
REM the assembler is done. There is one build, and it is the DOS one.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd LESSONS\L13" -c "MAKE.BAT EXIT"
if not exist LESSONS\L13\ARM.COM goto failed
echo.
echo Built LESSONS\L13\ARM.COM
goto end

:failed
echo.
echo Build failed - see the messages above.
:end
