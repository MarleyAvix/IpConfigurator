@echo off
title IpConfigurator PowerShell - Lancer le script PowerShell pour configurer les adresses IP
echo Lancement du script PowerShell IpConfigurator...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0IpConfigurator.ps1"
pause
