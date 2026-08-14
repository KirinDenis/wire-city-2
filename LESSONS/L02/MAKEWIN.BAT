@echo off
REM ============================================================================
REM MAKEWIN.BAT - build lesson 2 from Windows, without opening DOSBox by hand.
REM
REM It does not reimplement the build: it starts DOSBox and runs this folder's
REM own MAKE.BAT, with the argument EXIT so the emulator closes itself when the
REM assembler is done. There is one build, and it is the DOS one - the same one
REM a reader with nothing but this repository will run.
REM
REM Machine paths live in a gitignored LOCAL.BAT in the repository root
REM (set DOSBOX=...).
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd LESSONS\L02" -c "MAKE.BAT EXIT"
if not exist LESSONS\L02\HELLO.COM goto failed
if not exist LESSONS\L02\HELLO2.EXE goto failed
if not exist LESSONS\L02\HEX.COM goto failed
echo.
echo Built LESSONS\L02\HELLO.COM, HELLO2.EXE and HEX.COM
goto end

:failed
echo.
echo Build failed - see the messages above.
:end
