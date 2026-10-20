@echo off
setlocal
cd /d "%~dp0"
title NFS II SE - Gerar traducao PT-BR
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GERAR_TEXT_ENG.ps1"
set "RESULTADO=%ERRORLEVEL%"
echo.
if not "%RESULTADO%"=="0" echo Falha ao gerar o arquivo. Veja a mensagem acima.
pause
exit /b %RESULTADO%
