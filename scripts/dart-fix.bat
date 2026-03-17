@echo off
REM Dart Fix Script for Windows - Auto-fixes applicable lint issues

echo ========================================
echo Dart Auto-Fix Script
echo ========================================
echo.

REM Check if dart is available
where dart >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: Dart is not installed or not in PATH
    echo Please install Dart SDK first
    exit /b 1
)

echo Running dart fix --apply...
dart fix --apply

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo Fix Summary
    echo ========================================
    echo.
    echo Successfully applied automatic fixes!
    echo.
    echo The following types of issues were automatically fixed:
    echo   - Style issues (prefer_single_quotes, prefer_const_constructors, etc.)
    echo   - Unnecessary code (unnecessary_const, unnecessary_new, etc.)
    echo   - Modern Dart patterns (prefer_spread_collections, prefer_if_elements, etc.)
    echo   - Type simplifications (prefer_typing_uninitialized_variables, etc.)
    echo.
    echo Manual fixes may still be needed for:
    echo   - Documentation (public_member_api_docs)
    echo   - Performance issues (avoid_slow_async_io)
    echo   - Security concerns (control_flow_in_finally)
    echo   - Logic issues (avoid_print, etc.)
    echo.
    echo Run 'flutter analyze' to see remaining issues
    echo.
) else (
    echo.
    echo Error: dart fix failed with exit code %ERRORLEVEL%
    echo.
)

exit /b %ERRORLEVEL%
