@echo off
REM Pre-commit hook for Node Graph Notebook (Windows)
REM This script runs before each commit to ensure code quality

setlocal enabledelayedexpansion

echo 🔍 Running pre-commit checks...

REM Format code
echo 📝 Formatting code...
dart format --set-exit-if-changed .
if %ERRORLEVEL% NEQ 0 (
    echo ✗ Code formatting failed
    echo Please run 'dart format .' to fix formatting issues
    exit /b 1
)
echo ✓ Code formatted

REM Analyze code
echo 🔎 Analyzing code...
dart analyze --fatal-infos --fatal-warnings
if %ERRORLEVEL% NEQ 0 (
    echo ✗ Code analysis failed
    echo Please fix the issues above before committing
    exit /b 1
)
echo ✓ Code analysis passed

echo ✅ All pre-commit checks passed!
exit /b 0
