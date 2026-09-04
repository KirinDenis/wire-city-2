@echo off
REM ============================================================================
REM RUNWIN.BAT - the video workbench from Windows: opens DOSBox, runs it,
REM closes again. Inside DOS the equivalent is simply RUN, in this folder.
REM
REM   RUNWIN                    play TEST2.OWV
REM   RUNWIN PLAYER SOME.OWV    play that one instead
REM   RUNWIN VESATEST           ask what this machine grants
REM   RUNWIN X ...              the same, but under DOSBox-X
REM
REM It does not reimplement anything: it starts DOSBox and runs this folder's
REM own RUN.BAT with the arguments given. There is one way to run these
REM programs and it is the DOS one.
REM
REM CYCLES=30000, the same figure the games run at. It was measured, not
REM assumed: at that setting the player keeps up with a twelve-frame-a-second
REM clip. Raising it to max was tried and made things worse, because the time
REM went into DOSBox printing illegal-access complaints rather than into
REM emulation - which is how that bug was found.
REM
REM -noautoexec is not optional: without it DOSBox runs the machine's own
REM autoexec (a file manager, on this one) and every -c below is buried
REM under it. It also means no memory manager is loaded, which is what makes
REM the player's habit of simply taking the memory above 1 MB safe here.
REM ============================================================================
cd /d %~dp0..\..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

set VTBOX=%DOSBOX%
set VTNAME=DOSBox
set VTPROG=%1
set VTFILE=%2
if /i not "%~1"=="X" goto defaults
if "%DOSBOXX%"=="" goto nodosboxx
set VTBOX=%DOSBOXX%
set VTNAME=DOSBox-X
set VTPROG=%2
set VTFILE=%3

REM Every argument is filled in HERE rather than left empty, because an empty
REM argument does not hold its place: "RUN.BAT %1 %2 EXIT" with nothing in %1
REM arrives as "RUN.BAT EXIT", and the word EXIT becomes the program name.
:defaults
if "%VTPROG%"=="" set VTPROG=PLAYER
if "%VTFILE%"=="" set VTFILE=TEST2.OWV
set VTRUN=RUN.BAT %VTPROG% %VTFILE% EXIT

:go
echo Running under %VTNAME% ...
"%VTBOX%" -noautoexec -c "config -set cycles=30000" -c "mount c %CD%" -c "c:" -c "cd LAB\OWLFLY4\VIDEO" -c "%VTRUN%" -c "exit"
goto end

:nodosboxx
echo DOSBOXX is not set. Put it in LOCAL.BAT next to DOSBOX.
:end
