@echo off
if not exist TURN.COM goto nobuild
TURN.COM
goto end
:nobuild
echo.
echo There is no TURN.COM yet - type MAKE first. That is deliberate: this
echo bundle ships the source and the assembler, never the program.
:end
