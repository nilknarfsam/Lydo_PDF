@echo off
rem Cria a chave de release do Lydo e o android\key.properties.
rem Basta dar dois cliques. A senha e digitada so aqui.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0criar_chave_release.ps1"
echo.
pause
