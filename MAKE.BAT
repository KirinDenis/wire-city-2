@echo off
REM ============================================================================
REM MAKE.BAT [target] - the arcade build orchestrator. Run from Windows.
REM   MAKE            - build EVERYTHING (all games + examples)
REM   MAKE OWLFLY     - the flight simulator only (converters + TASM)
REM   MAKE WIRECITY   - the 1986 original only
REM   MAKE EXAMPLES   - the teaching machines only
REM   MAKE TOOLS      - the DOS toolchain (OBJ2DAT model precompiler)
REM   MAKE TRAINER    - the flight school (model DAT + TASM)
REM   MAKE NEWTON     - the force-model aeroplane (TASM only, archived)
REM   MAKE OWLFLY2    - OWL FLY II, the successor (converters + TASM)
REM Per-game folders have one-line wrappers calling this with their target.
REM All build logic lives HERE: DOSBox always mounts the repo root as C:
REM because ENGINE\ is shared by every target. Log: BUILD.LOG in the root.
REM Machine paths live in LOCAL.BAT (gitignored):
REM   set DOSBOX=C:\Games\DOSBox\DOSBox.exe
REM   set TASMDIR=d:\borland\bp
REM ============================================================================
cd /d %~dp0
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
if "%TASMDIR%"=="" set TASMDIR=c:\bp
set TARGET=%~1
if "%TARGET%"=="" set TARGET=ALL

if "%TARGET%"=="WIRECITY" goto skipconv
if "%TARGET%"=="EXAMPLES" goto skipconv
if "%TARGET%"=="TOOLS" goto skipconv
if "%TARGET%"=="NEWTON" goto skipconv
if "%TARGET%"=="TRAINER" goto trconv
goto convdone
:trconv
echo === 1/2 TRAINER converters (instrument panel) ===
python GAMES\TRAINER\res\mkpanel.py
if errorlevel 1 goto err
goto skipconv
:convdone
echo === 1/2 OWLFLY converters (panel + engine sample) ===
REM OWLFLY (the first one) still rides the old Python pair. OWLFLY2 does
REM NOT: its cockpit goes through TOOLS\Panel2Inc below - C#, per the
REM tooling contract. Until 2026-07-29 nothing rebuilt OWLFLY2's panel at
REM all: it carried a stale copy of OWLFLY's generated INCs, so editing
REM its artwork changed precisely nothing.
python GAMES\OWLFLY\res\mkpanel.py
if errorlevel 1 goto err
python GAMES\OWLFLY\res\mkengine.py
if errorlevel 1 goto err
REM The cockpit source. cockpit2.png is the big original (1586x992); the
REM converter shrinks it. cockpit2_edit.png, if it exists, WINS - that is
REM the hand-worked 320x200 panel, and pixel work at final resolution is
REM the only way to place a three-pixel lamp lens or a five-pixel letter.
REM Both go down the same path: the tool takes any size from 320x200 up,
REM and at exactly 320x200 the shrink is a straight copy.
REM DO NOT edit cockpit2_art.bmp or cockpit2_mark.bmp - the tool REWRITES
REM both of them on every build, and an afternoon of retouching goes with
REM them. _mark.bmp is however the right thing to START from: it is the
REM panel at 320x200 with the three screen markers painted back in and the
REM transparent viewport in pure white, which is exactly what comes back
REM in. Save it as cockpit2_edit.png and it is yours.
set PANELSRC=GAMES\OWLFLY2\res\cockpit2.png
if exist GAMES\OWLFLY2\res\cockpit2_edit.png set PANELSRC=GAMES\OWLFLY2\res\cockpit2_edit.png
echo panel source: %PANELSRC%
dotnet run --project TOOLS\Panel2Inc -c Release -- %PANELSRC% -o GAMES\OWLFLY2\SRC -bmp GAMES\OWLFLY2\res
if errorlevel 1 goto err
dotnet run --project TOOLS\Obj2Inc -c Release -- GAMES\OWLFLY2\res\F15.OBJ -o GAMES\OWLFLY2\SRC\F15M.INC -n F15 -s 2
if errorlevel 1 goto err
dotnet run --project TOOLS\Obj2Inc -c Release -- GAMES\OWLFLY2\res\RBASE.OBJ -o GAMES\OWLFLY2\SRC\RBASEM.INC -n RBASE -s 6
if errorlevel 1 goto err
dotnet run --project TOOLS\Obj2Inc -c Release -- GAMES\OWLFLY2\res\RDISH.OBJ -o GAMES\OWLFLY2\SRC\RDISHM.INC -n RDISH -s 6
if errorlevel 1 goto err
REM the Shilka: chassis and turret, ONE scale between them (-s 3 = 15
REM engine units per metre). Change both or the turret leaves the hull.
dotnet run --project TOOLS\Obj2Inc -c Release -- GAMES\OWLFLY2\res\SHULL.OBJ -o GAMES\OWLFLY2\SRC\SHULLM.INC -n SHULL -s 3
if errorlevel 1 goto err
dotnet run --project TOOLS\Obj2Inc -c Release -- GAMES\OWLFLY2\res\STURR.OBJ -o GAMES\OWLFLY2\SRC\STURRM.INC -n STURR -s 3
if errorlevel 1 goto err
REM the Gun Dish is a THIRD model: it sweeps while the guns hold still, and
REM one model can only carry one yaw. Same scale as the other two.
dotnet run --project TOOLS\Obj2Inc -c Release -- GAMES\OWLFLY2\res\SDISH.OBJ -o GAMES\OWLFLY2\SRC\SDISHM.INC -n SDISH -s 3
if errorlevel 1 goto err
REM ...and a FOURTH: the barrels, which pitch at their trunnion as well as
REM riding the turret round. Three motions, three models.
dotnet run --project TOOLS\Obj2Inc -c Release -- GAMES\OWLFLY2\res\SBARR.OBJ -o GAMES\OWLFLY2\SRC\SBARRM.INC -n SBARR -s 3
if errorlevel 1 goto err
:skipconv

echo === 2/2 DOSBox build: %TARGET% ===
if exist BUILD.LOG del BUILD.LOG
set MKROOT=%~dp0
if "%MKROOT:~-1%"=="\" set MKROOT=%MKROOT:~0,-1%
"%DOSBOX%" -noautoexec -noconsole -c "mount c %MKROOT%" -c "mount d %TASMDIR%" -c "c:" -c "buildq.bat %TARGET%" -c "exit"
if not exist BUILD.LOG goto norun
type BUILD.LOG
findstr /C:"BUILD OK" BUILD.LOG >nul
if errorlevel 1 goto err
echo.
echo MAKE OK [%TARGET%]
goto end
:norun
echo BUILD.LOG was never written - the DOSBox mount or BUILDQ.BAT failed
:err
echo.
echo MAKE FAILED [%TARGET%] - see messages above
:end
