@echo off
REM Clean analyze script for Windows that filters out third-party plugin warnings

echo Running Flutter analyze...
echo.

REM Run flutter analyze and filter out known third-party warnings
flutter analyze 2>&1 | findstr /V /C:"Package file_picker:" /C:"Ask the maintainers of file_picker" /C:"default_package: file_picker"

echo.
if %ERRORLEVEL% EQU 0 (
  echo ✅ No issues found in your code!
) else (
  echo ⚠️  Issues found. Please review the output above.
)

exit /b %ERRORLEVEL%
