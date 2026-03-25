@echo off
REM Lua 命令行发送工具 (Windows)

setlocal enabledelayedexpansion

if "%~1"=="" (
    echo 用法：
    echo   lua "debugPrint('Hello')"
    echo   lua --file=myscript.lua
    echo.
    echo 示例：
    echo   lua "registerToolbarButton('test', 'Test', 'onTest', 'star')"
    echo.
    exit /b 1
)

dart run tool/send_lua_command.dart %*

endlocal
