@echo off
REM ============================================================================
REM MAKEWIN.BAT - the reference factory, one command, nobody touching it.
REM
REM   TOOLS\REFGEN\MAKEWIN
REM
REM Compiles REFGEN with Borland Pascal, runs it, and decodes every screen it
REM produced. DOSBox opens and closes by itself; there is no hotkey to press
REM and no window to arrange. What comes out is REF00.TXT and up, each one a
REM picture of the screen plus a legend of every attribute in it by name.
REM
REM That legend is the whole point of the exercise. "Which blue is the window
REM background" stops being a question about a screenshot and becomes a line
REM in a file.
REM
REM Borland Pascal comes from TASMDIR in LOCAL.BAT. Neither it nor the output
REM is committed - see THIRD-PARTY.md.
REM
REM NB a -c string must not end in a backslash: it escapes the closing quote
REM and DOSBox swallows the -c that follows. And a batch started from a -c
REM line swallows every -c after it, so BUILD.BAT is last and closes the
REM emulator itself.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
if "%TASMDIR%"=="" goto notasm

if exist TOOLS\REFGEN\REF*.BIN del TOOLS\REFGEN\REF*.BIN
if exist TOOLS\REFGEN\REF*.TXT del TOOLS\REFGEN\REF*.TXT

echo Compiling and running in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "mount d %TASMDIR%" -c "c:" -c "cd TOOLS\REFGEN" -c "BUILD.BAT EXIT"

if not exist TOOLS\REFGEN\REF00.BIN goto noshots

if not exist TOOLS\ShotRead\ShotRead.exe call TOOLS\ShotRead\BUILD.BAT
echo.
echo Decoding...
for %%f in (TOOLS\REFGEN\REF*.BIN) do (
    TOOLS\ShotRead\ShotRead.exe "%%f" > "%%~dpnf.TXT"
    echo   %%~nf.TXT
)
echo.
type TOOLS\REFGEN\REFS.TXT
goto end

:noshots
echo.
echo Nothing came back. Either the compile failed or REFGEN did not run -
echo open DOSBox by hand and run TOOLS\REFGEN\BUILD.BAT to see the messages.
goto end

:notasm
echo.
echo TASMDIR is not set. Put your Borland Pascal path in LOCAL.BAT:
echo     set TASMDIR=c:\DOSFiles\bp
:end
