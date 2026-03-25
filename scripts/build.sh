#!/bin/bash

# Node Graph Notebook - Build Script

set -e

echo "🔨 Node Graph Notebook - Build Script"
echo ""

# 检查 Flutter 是否安装
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n 1)"

# 获取依赖
echo ""
echo "📦 Installing dependencies..."
flutter pub get

# 生成 i18n 翻译代码
echo ""
echo "🌐 Generating i18n translation code..."
dart tool/generate_i18n.dart

# 生成代码
echo ""
echo "🔧 Generating JSON serialization code..."
flutter pub run build_runner build --delete-conflicting-outputs

# 分析代码
echo ""
echo "🔍 Analyzing code..."
flutter analyze

# 运行测试
echo ""
echo "🧪 Running tests..."
flutter test

# 构建
echo ""
echo "🏗️  Building application..."
flutter build windows

echo ""
echo "✅ Build completed successfully!"
echo "📂 Output: build/windows/runner/Release/"
