@echo off
REM ============================================================================
REM MAKE.BAT - the BROWSER copy. Same build, flat paths.
REM
REM This is not the lesson's MAKE.BAT. The one a folder up reaches the
REM assembler through ..\..\TOOLS\FASM, because in the repository that is
REM where it lives. Inside the .jsdos bundle there is no repository: the
REM source and the tools sit in one directory, which is the whole of drive
REM C:. The COMMANDS are identical, and that is what matters - whichever
REM machine you type MAKE on, the same assembler produces the same bytes.
REM
REM THE ENGINE IS STILL IN ITS OWN FOLDER, and that is deliberate. RELIEF.ASM
REM includes '..\..\ENGINE\E_MATH.INC' and five more like it, exactly as it
REM does in the repository, and DOS clamps ".." at the root of a drive - so
REM from C:\ that path resolves to C:\ENGINE and the file is found. The
REM source in this bundle is the source in the repository, character for
REM character. Nothing was rewritten to make it fit in a browser.
REM ============================================================================
if exist RELIEF.COM del RELIEF.COM
echo Assembling RELIEF.ASM ...
CWSDPMI.EXE
FASM.EXE RELIEF.ASM RELIEF.COM
if not exist RELIEF.COM goto failed
echo.
echo Built RELIEF.COM - you just assembled it. Type RUN.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. Nothing was
echo overwritten with a broken build. Type LESSON for the way back.
:end
