@echo off
rem ALEX on the LIVE ViewOwl pipe (view.owlos.sk, GENERAL board).
rem Does not host anything locally - pure client of the remote relay.
start "" "%~dp0bin\Debug\net9.0-windows\WireCityChat.exe" settings.prod.json
