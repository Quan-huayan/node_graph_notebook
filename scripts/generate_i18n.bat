@echo off
REM Node Graph Notebook - I18n 代码生成脚本 for Windows

echo 🌐 Node Graph Notebook - I18n 代码生成
echo.

REM 检查 Dart 是否安装
where dart >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Dart not found. Please install Dart first.
    exit /b 1
)

echo ✅ Dart found
echo.

REM 运行 i18n 代码生成工具
echo 🔧 Generating i18n translation code...
dart tool/generate_i18n.dart --verbose

echo.
echo ✅ I18n 代码生成完成！
echo.
echo 💡 提示:
echo    - 翻译源文件: assets/i18n/source.csv
echo    - 生成文件: lib/core/services/i18n/translations.dart
echo    - 修改翻译后重新运行此脚本
