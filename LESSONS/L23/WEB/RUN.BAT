@echo off
if not exist HOUSES.COM goto nobuild
HOUSES.COM
goto end
:nobuild
echo.
echo There is no HOUSES.COM yet - type MAKE first. That is deliberate: this
echo bundle ships the source and the assembler, never the program.
:end
