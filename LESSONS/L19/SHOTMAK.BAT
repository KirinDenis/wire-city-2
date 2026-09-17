@echo off
REM Scratch: assemble SHOT.ASM if needed, run it on stage %1, then quit.
if exist SHOT.COM goto run
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SHOT.ASM SHOT.COM > SHOT.LOG
if not exist SHOT.COM exit
:run
SHOT.COM %1
exit
