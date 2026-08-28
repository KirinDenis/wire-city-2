@echo off
REM ============================================================================
REM CONVERT.BAT - prepare OWL FLY III's art, models and sound, on Windows.
REM
REM   CONVERT
REM
REM These are the modern half of the toolchain, and they run BEFORE the DOS
REM build: they turn drawn pictures, Wavefront models and ordinary WAVs into
REM the byte tables and blobs the 8086 loads. Their output is committed, so a
REM plain MAKEWIN does not need this to have run - only a change to the
REM artwork does.
REM
REM They are C#, per the project's tooling contract, and need the .NET SDK.
REM They came out of the repository-wide MAKEWIN.BAT when OWL FLY III finished
REM migrating and that file was retired.
REM ============================================================================
cd /d %~dp0..\..

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
set PANELSRC=GAMES\OWLFLY3\res\cockpit2.png
if exist GAMES\OWLFLY3\res\cockpit2_edit.png set PANELSRC=GAMES\OWLFLY3\res\cockpit2_edit.png
echo panel source: %PANELSRC%
REM The two 90-degree views ride the SAME run, and they have to: the VGA DAC
REM lends this game 63 slots and all three pictures live in them, so one
REM median cut has to see all three. Run the front alone and the sides go
REM stale against a palette they never voted in.
dotnet run --project TOOLS\Panel2Inc -c Release -- %PANELSRC% -o GAMES\OWLFLY3\SRC -bmp GAMES\OWLFLY3\res -left GAMES\OWLFLY3\res\cockpit_left.png -right GAMES\OWLFLY3\res\cockpit_right.png
if errorlevel 1 goto err
REM The Shilka's cabin rides the palette the run above just minted
REM (PALPNL.INC): the DAC lends 63 panel slots and a fourth picture has
REM to live in the same lease. So Cab2Dat runs AFTER Panel2Inc, always.
REM It also bakes the RETRO cabins (SHCCGA/SHCEGA/SHCHGC.DAT) - the same
REM span skeleton carrying marker bytes, drawn by bands the way VidRig
REM draws the jet's panel - and previews them in res\shilka_art_*.bmp.
dotnet run --project TOOLS\Cab2Dat -c Release -- GAMES\OWLFLY3\res\shilka.png -pal GAMES\OWLFLY3\SRC\PALPNL.INC -o GAMES\OWLFLY3\INSTALL\SHCAB.DAT -bmp GAMES\OWLFLY3\res\shilka_art.bmp
if errorlevel 1 goto err
dotnet run --project TOOLS\Obj2Inc -c Release -- GAMES\OWLFLY3\res\F15.OBJ -o GAMES\OWLFLY3\SRC\F15M.INC -n F15 -s 2 -fasm
if errorlevel 1 goto err
dotnet run --project TOOLS\Obj2Inc -c Release -- GAMES\OWLFLY3\res\RBASE.OBJ -o GAMES\OWLFLY3\SRC\RBASEM.INC -n RBASE -s 6 -fasm
if errorlevel 1 goto err
dotnet run --project TOOLS\Obj2Inc -c Release -- GAMES\OWLFLY3\res\RDISH.OBJ -o GAMES\OWLFLY3\SRC\RDISHM.INC -n RDISH -s 6 -fasm
if errorlevel 1 goto err
REM the Shilka: chassis and turret, ONE scale between them (-s 1: the
REM world metre is about seven units, so a 6.5m hull comes out ~44 long -
REM the -s 3 first cut towered over its own city, 2026-08-26). Change
REM all four together or the turret leaves the hull.
dotnet run --project TOOLS\Obj2Inc -c Release -- GAMES\OWLFLY3\res\SHULL.OBJ -o GAMES\OWLFLY3\SRC\SHULLM.INC -n SHULL -s 1 -fasm
if errorlevel 1 goto err
dotnet run --project TOOLS\Obj2Inc -c Release -- GAMES\OWLFLY3\res\STURR.OBJ -o GAMES\OWLFLY3\SRC\STURRM.INC -n STURR -s 1 -fasm
if errorlevel 1 goto err
REM the Gun Dish is a THIRD model: it sweeps while the guns hold still, and
REM one model can only carry one yaw. Same scale as the other two.
dotnet run --project TOOLS\Obj2Inc -c Release -- GAMES\OWLFLY3\res\SDISH.OBJ -o GAMES\OWLFLY3\SRC\SDISHM.INC -n SDISH -s 1 -fasm
if errorlevel 1 goto err
REM ...and a FOURTH: the barrels, which pitch at their trunnion as well as
REM riding the turret round. Three motions, three models.
dotnet run --project TOOLS\Obj2Inc -c Release -- GAMES\OWLFLY3\res\SBARR.OBJ -o GAMES\OWLFLY3\SRC\SBARRM.INC -n SBARR -s 1 -fasm
if errorlevel 1 goto err
REM ---- THE SOUND BANK. Ordinary WAVs in res\snd, cut to signed 8-bit mono
REM at 11025 Hz - the rate the engine ring already spins at - and packed with
REM an index into INSTALL\SFX.DAT. The second field is a HARD CAP in seconds
REM and it is not taste: every sound must fit inside a 32768-sample ring
REM ahead of the DMA beam, and the whole bank must fit one 64K segment.
REM Snd2Dat trims the padding off both ends (a library file is mastered with
REM silence around it) and normalises what actually ships, so the caps are
REM the only place loudness and length are decided. The third field pushes
REM one sound back behind the others.
dotnet run --project TOOLS\Snd2Dat -c Release -- -o GAMES\OWLFLY3\INSTALL -src GAMES\OWLFLY3\SRC "GUN=GAMES\OWLFLY3\res\snd\selfgun.wav,0.22,1.0" "FLAK=GAMES\OWLFLY3\res\snd\shilkagun.wav,0.22,0.85" "RKT=GAMES\OWLFLY3\res\snd\rocket.wav,0.90,1.0" "BOOM=GAMES\OWLFLY3\res\snd\Explosion.wav,1.10,1.0" "DETH=GAMES\OWLFLY3\res\snd\self_explosion.wav,1.30,1.0" "CAUT=GAMES\OWLFLY3\res\snd\alarm.wav,0.55,0.7" "WARN=GAMES\OWLFLY3\res\snd\critical-alarm.wav,0.55,0.85"
if errorlevel 1 goto err
REM ---- THE RETRO CARDS. VidRig bakes the CGA cockpit (INSTALL\CPCGA.DAT,
REM the panel drawn the 1988 way, offline) and the 256->4 day/night
REM lookup (SRC\VIDLUT.INC) straight from cockpit2_edit.png and UI.INC's
REM own palette tables. Regenerate after ANY palette or panel change, or
REM the CGA glass drifts from the VGA truth. Skill\VIDTASK.md is the plan.
dotnet run --project TOOLS\VidRig -c Release -- emit GAMES\OWLFLY3\res\cockpit2_edit.png GAMES\OWLFLY3\SRC\UI.INC GAMES\OWLFLY3\SRC GAMES\OWLFLY3\INSTALL
if errorlevel 1 goto err
echo.
echo Done. Now build it: MAKEWIN, in the game's folder.
goto end
:err
echo.
echo A converter failed - see the messages above.
:end
