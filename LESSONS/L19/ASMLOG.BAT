@echo off
REM Scratch: assemble and keep what FASM said, for reading from Windows.
REM Not part of the lesson - delete before it ships.
if exist CLIP.COM del CLIP.COM
if exist ASM.LOG del ASM.LOG
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE CLIP.ASM CLIP.COM > ASM.LOG
exit
