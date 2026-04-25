:: ========================================
:: create_module.bat
:: ========================================
@echo off
setlocal

set SCRIPT_PATH=%~dp0create_module.ps1

if "%~1"=="" (
    echo Usage: %~nx0 ModuleName [MainClassName]
    echo Example: %~nx0 Hello
    echo Example: %~nx0 MyModule MyMain
    exit /b 1
)

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_PATH%" %*

endlocal
exit /b %ERRORLEVEL%