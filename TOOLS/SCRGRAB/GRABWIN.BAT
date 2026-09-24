@echo off
REM ============================================================================
REM GRABWIN.BAT - the reference rig, one command.
REM
REM   TOOLS\SCRGRAB\GRABWIN
REM
REM Starts DOSBox with the repository on C: and Borland on D:, loads SCRGRAB,
REM and puts you in the IDE. Arrange a screen, press both Shift keys, repeat.
REM Alt+X quits the IDE; the shots are written and DOSBox closes by itself.
REM
REM Then, without being asked, every shot is decoded and its report written
REM next to it as SHOTnn.TXT. Those reports are the product - the pictures are
REM only how you find the one you want.
REM
REM Borland Pascal is not in this repository and will not be (see
REM THIRD-PARTY.md). It comes from TASMDIR in LOCAL.BAT, which is also not
REM committed.
REM
REM NB a -c string must not end in a backslash: it escapes the closing quote
REM and DOSBox then swallows the -c after it, silently. And a batch file
REM started from a -c line swallows every -c that follows, so GRAB.BAT is
REM last and closes the emulator itself.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
if "%TASMDIR%"=="" goto notasm
if not exist TOOLS\SCRGRAB\SCRGRAB.COM goto nobin

"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "mount d %TASMDIR%" -c "c:" -c "cd TOOLS\SCRGRAB" -c "GRAB.BAT EXIT"

if not exist TOOLS\SCRGRAB\SHOTS\SHOT00.BIN goto noshots

if not exist TOOLS\ShotRead\ShotRead.exe call TOOLS\ShotRead\BUILD.BAT
echo.
echo Decoding...
for %%f in (TOOLS\SCRGRAB\SHOTS\SHOT*.BIN) do (
    TOOLS\ShotRead\ShotRead.exe "%%f" > "%%~dpnf.TXT"
    echo   %%~nf.TXT
)
echo.
echo Reports are in TOOLS\SCRGRAB\SHOTS.
goto end

:noshots
echo.
echo No shots came back. Either nothing was captured - both Shift keys, and
echo listen for the beep - or the IDE never started.
goto end

:notasm
echo.
echo TASMDIR is not set. Put your Borland Pascal path in LOCAL.BAT:
echo     set TASMDIR=c:\DOSFiles\bp
goto end

:nobin
echo.
echo SCRGRAB.COM is not built. Run TOOLS\SCRGRAB\MAKEWIN.BAT first.
:end
