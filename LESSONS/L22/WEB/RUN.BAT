@echo off
if not exist FILL.COM goto nobuild
FILL.COM
goto end
:nobuild
echo.
echo There is no FILL.COM yet - type MAKE first. That is deliberate: this
echo bundle ships the source and the assembler, never the program.
:end
