@echo off
rem Both bots (ALEX + BORIS) on the LIVE ViewOwl pipe - autostart-safe.
rem At logon the network may not be up yet, and a bot that fails its
rem first connect does NOT retry - so wait for the relay host first.

:waitnet
ping -n 1 view.owlos.sk >nul 2>&1
if errorlevel 1 (
    timeout /t 10 /nobreak >nul
    goto waitnet
)

set D=%~dp0bin\Debug\net9.0-windows
start "" "%D%\WireCityChat.exe" settings.prod.json
rem Let ALEX register (and keep the two windows from racing the logs).
timeout /t 8 /nobreak >nul
start "" "%D%\WireCityChat.exe" settings.bot2.prod.json
