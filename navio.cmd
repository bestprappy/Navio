@echo off
rem Local backend runner. See scripts\local\navio.ps1 for commands, or run: navio help
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\local\navio.ps1" %*
exit /b %ERRORLEVEL%
