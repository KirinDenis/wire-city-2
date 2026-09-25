@echo off
if not exist RELIEF.COM goto nobuild
RELIEF.COM
goto end
:nobuild
echo.
echo There is no RELIEF.COM yet - type MAKE first. That is deliberate: this
echo bundle ships the source and the assembler, never the program.
:end
