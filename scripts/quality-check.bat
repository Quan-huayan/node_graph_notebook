@echo off
REM Quality check script - Run all quality checks (Windows)

echo 🔍 Running comprehensive quality checks...
echo.

REM Step 1: Format code
echo Step 1: Formatting code...
dart format --set-exit-if-changed .
if %ERRORLEVEL% NEQ 0 exit /b 1
echo ✓ Code formatted
echo.

REM Step 2: Analyze code
echo Step 2: Analyzing code...
dart analyze --fatal-infos --fatal-warnings
if %ERRORLEVEL% NEQ 0 exit /b 1
echo ✓ Code analysis passed
echo.

REM Step 3: Run tests
echo Step 3: Running tests...
flutter test --coverage
if %ERRORLEVEL% NEQ 0 exit /b 1
echo ✓ Tests passed
echo.

REM Step 4: Check test coverage
echo Step 4: Checking test coverage...
if exist coverage (
    echo Coverage report generated in coverage/
    echo To view: start coverage/index.html
)
echo ✓ Coverage check complete
echo.

echo 🎉 All quality checks passed!
