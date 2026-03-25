@echo off
REM Lua 动态按钮测试脚本 (Windows)

echo ========================================
echo Lua 动态工具栏按钮测试
echo ========================================
echo.

REM 检查 Flutter 环境
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo 错误: Flutter 未安装或未添加到 PATH
    echo 请先安装 Flutter: https://flutter.dev/docs/get-started/install
    pause
    exit /b 1
)

echo [1/3] 检查依赖...
flutter pub get
if %errorlevel% neq 0 (
    echo 错误: 依赖安装失败
    pause
    exit /b 1
)

echo.
echo [2/3] 编译代码...
flutter analyze
if %errorlevel% neq 0 (
    echo 警告: 代码分析发现问题，但继续测试...
)

echo.
echo [3/3] 运行测试...
echo.
dart run tool/test_lua_dynamic_buttons.dart

echo.
echo ========================================
echo 测试完成
echo ========================================
pause
