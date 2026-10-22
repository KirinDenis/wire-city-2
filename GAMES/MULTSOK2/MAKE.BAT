@echo off
REM ============================================================================
REM MAKE.BAT - assemble MULTIPLAY SOKO II, from inside DOS: its pictures
REM (ART.ASM -> ART.DAT, and EGA 640's ARTF.ASM -> ARTF.DAT), its levels
REM (LEVELS.ASM -> LEVELS.DAT), then the game (MULTSOK2.ASM -> MULTSOK2.COM).
REM
REM   cd GAMES\MULTSOK2
REM   MAKE
REM
REM Run it from this folder: every path below is relative to here. CWSDPMI
REM is loaded for FASM (a 32-bit program needs a DPMI host and DOSBox has
REM none); with no arguments it stays for one program and leaves with it.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist MULTSOK2.ASM goto nosource

echo Assembling ART.ASM ...
if exist ART.DAT del ART.DAT
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE ART.ASM ART.DAT
if not exist ART.DAT goto failed
echo Assembling ARTF.ASM ...
if exist ARTF.DAT del ARTF.DAT
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE ARTF.ASM ARTF.DAT
if not exist ARTF.DAT goto failed
echo Assembling LEVELS.ASM ...
if exist LEVELS.DAT del LEVELS.DAT
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE LEVELS.ASM LEVELS.DAT
if not exist LEVELS.DAT goto failed
echo Assembling MULTSOK2.ASM ...
if exist MULTSOK2.COM del MULTSOK2.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE MULTSOK2.ASM MULTSOK2.COM
if not exist MULTSOK2.COM goto failed
echo.
echo Built ART.DAT, ARTF.DAT, LEVELS.DAT and MULTSOK2.COM.  Type RUN to play it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the game's own folder - cd GAMES\MULTSOK2 - and make sure
echo you mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo MULTSOK2.ASM is not here. Run MAKE from GAMES\MULTSOK2.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. Nothing broken was
echo left behind: a file that failed is not written.
:end
if "%1"=="EXIT" exit
