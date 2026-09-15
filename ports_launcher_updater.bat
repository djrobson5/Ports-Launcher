@echo off
title Ports Launcher Updater & color 0A
cd /d "%~dp0"

taskkill /IM "ports_launcher.exe" /F >nul 2>&1
timeout /t 2 /nobreak >nul

echo Downloading latest version...
curl -L -o "%TEMP%\PortsLauncher-update.zip" "https://github.com/djrobson5/Ports-Launcher/releases/latest/download/Ports.Launcher.Windows.zip" || (echo Download failed. & pause & exit /b 1)

set "EXTRACT_TO=."
set "INSTALL_DIR=Ports Launcher"
for %%I in ("%CD%") do if /I "%%~nxI"=="Ports Launcher" (set "EXTRACT_TO=.." & set "INSTALL_DIR=.")

echo Installing...
tar -xf "%TEMP%\PortsLauncher-update.zip" -C "%EXTRACT_TO%" --exclude="Ports Launcher/ports_launcher_updater.bat" || (echo Extraction failed. & pause & exit /b 1)

del /q "%TEMP%\PortsLauncher-update.zip"

echo Refreshing catalog...
curl -fsSL -o "%TEMP%\ports.json.new" "https://raw.githubusercontent.com/djrobson5/Ports-Launcher/main/ports.json" && move /y "%TEMP%\ports.json.new" "%INSTALL_DIR%\ports.json" >nul
curl -fsSL -o "%TEMP%\themes.json.new" "https://raw.githubusercontent.com/djrobson5/Ports-Launcher/main/themes.json" && move /y "%TEMP%\themes.json.new" "%INSTALL_DIR%\themes.json" >nul

start "" "%INSTALL_DIR%\ports_launcher.exe"
move /y "%~f0" "%INSTALL_DIR%\%~nx0" >nul 2>&1
