@echo off
REM Node Graph Notebook - Build Script for Windows

echo 🔨 Node Graph Notebook - Build Script
echo.

REM 检查 Flutter 是否安装
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter not found. Please install Flutter first.
    exit /b 1
)

flutter --version | findstr /C:"Flutter" >nul
if %ERRORLEVEL% EQU 0 (
    echo ✅ Flutter found
) else (
    echo ❌ Flutter not working properly
    exit /b 1
)

REM 获取依赖
echo.
echo 📦 Installing dependencies...
flutter pub get

REM 生成代码
echo.
echo 🔧 Generating JSON serialization code...
flutter pub run build_runner build --delete-conflicting-outputs

REM 分析代码
echo.
echo 🔍 Analyzing code...
flutter analyze

REM 运行测试
echo.
echo 🧪 Running tests...
flutter test

REM 构建
echo.
echo 🏗️  Building application...
flutter build windows

echo.
echo ✅ Build completed successfully!
echo 📂 Output: build\windows\runner\Release\
