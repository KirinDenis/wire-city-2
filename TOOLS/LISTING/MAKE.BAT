@echo off
REM ============================================================================
REM MAKE.BAT - assemble LISTING.EXE, from inside DOS.
REM
REM   cd TOOLS\LISTING
REM   MAKE
REM
REM The source is not here and is not ours to edit: it is flat assembler's
REM own listing tool, vendored at ..\FASM\TOOLS\DOS\LISTING.ASM. This folder
REM only holds the build of it, because the vendored tree stays as shipped.
REM
REM What it is for: FASM has no disassembler and never did. What a student
REM actually wants is the answer to "what did my line turn into", and that is
REM a listing:
REM
REM   FASM    TURN.ASM TURN.COM -s TURN.FAS
REM   LISTING TURN.FAS TURN.LST
REM
REM Generate the listing IMMEDIATELY after the build, from the same
REM directory, with nothing moved or edited in between - it reads the .FAS
REM symbol dump against the source files it names, so a stale pair prints
REM garbage. Pass -a for EXE-format outputs to get run-time addresses.
REM
REM CWSDPMI is loaded first because the assembler is a 32-bit program and
REM something has to own protected mode on its behalf; with no arguments it
REM serves exactly one program and unloads itself. LISTING.EXE is built from
REM the same 32-bit runtime, so RUNNING it needs a DPMI host too.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT, which
REM               drives this file from Windows. Typed by hand, MAKE leaves
REM               you at the prompt.
REM ============================================================================
if not exist ..\FASM\FASM.EXE goto nofasm
if not exist ..\FASM\TOOLS\DOS\LISTING.ASM goto nosource

echo Assembling LISTING.EXE ...
if exist LISTING.EXE del LISTING.EXE
..\CWSDPMI\CWSDPMI.EXE
..\FASM\FASM.EXE ..\FASM\TOOLS\DOS\LISTING.ASM LISTING.EXE
if not exist LISTING.EXE goto failed
echo.
echo Built LISTING.EXE.
goto end

:nofasm
echo.
echo Cannot find ..\FASM\FASM.EXE
echo Run MAKE from the tool's own folder - cd TOOLS\LISTING - and make sure
echo you mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo ..\FASM\TOOLS\DOS\LISTING.ASM is not there. The vendored FASM tree is
echo incomplete - nothing to build.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. LISTING.EXE was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
