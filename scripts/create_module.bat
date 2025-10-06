@echo off
setlocal

:: ==========================================================
:: 模块创建启动器
:: 功能：通过 PowerShell 调用 create_module.ps1
:: ==========================================================

set SCRIPT_PATH=%~dp0create_module.ps1

if "%~1"=="" (
    echo 用法: %~nx0 模块名 [主类名]
    echo 示例: %~nx0 Hello
    exit /b 1
)

powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_PATH%" %*

endlocal
