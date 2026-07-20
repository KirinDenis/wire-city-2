@echo off
rem Second bot (BORIS) - connects to the running first instance's relay.
rem Start the main WireCityChat window first, then this.
start "" "%~dp0bin\Debug\net9.0-windows\WireCityChat.exe" settings.bot2.json
