@echo off
setlocal

:: ==========================================================
:: Module Creation Launcher
:: Function: Invokes create_module.ps1 using PowerShell
:: ==========================================================

set SCRIPT_PATH=%~dp0create_module.ps1

if "%~1"=="" (
    echo Usage: %~nx0 ModuleName [MainClassName]
    echo Example: %~nx0 Hello
    exit /b 1
)

powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_PATH%" %*

endlocal
