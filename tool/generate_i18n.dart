#!/usr/bin/env dart

/// I18n 翻译代码生成工具
///
/// 用途：从 CSV 文件生成 Dart 翻译代码
///
/// CSV 格式：
/// Key,Zh,En,Category,Notes
/// Home,主页,Home,通用,
/// Settings,设置,Settings,通用,
///
/// 使用方法：
/// dart tool/generate_i18n.dart
/// dart tool/generate_i18n.dart --input=assets/i18n/source.csv

import 'dart:io';

void main(List<String> args) async {
  print('I18n 翻译代码生成工具');
  print('=' * 50);

  // 解析参数
  final inputPath = args.isNotEmpty && args[0].startsWith('--input=')
      ? args[0].split('=')[1]
      : 'assets/i18n/source.csv';

  final outputPath = args.length > 1 && args[1].startsWith('--output=')
      ? args[1].split('=')[1]
      : 'lib/core/services/i18n/translations.dart';

  print('输入文件: $inputPath');
  print('输出文件: $outputPath');
  print();

  // 检查输入文件
  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    print('❌ 错误: 输入文件不存在');
    print('提示: 请创建 $inputPath 文件');
    print('示例 CSV 格式:');
    print(_getCsvExample());
    exit(1);
  }

  try {
    // 读取 CSV
    print('📖 读取 CSV 文件...');
    final lines = await inputFile.readAsLines();

    if (lines.isEmpty) {
      print('❌ 错误: CSV 文件为空');
      exit(1);
    }

    // 解析 CSV
    print('🔍 解析翻译数据...');
    final translations = _parseCsv(lines);

    print('✅ 解析完成:');
    print('   - 中文翻译: ${translations['zh']?.length ?? 0} 条');
    print('   - 英文翻译: ${translations['en']?.length ?? 0} 条');

    // 生成 Dart 代码
    print('🔨 生成 Dart 代码...');
    final dartCode = _generateDartCode(translations);

    // 写入文件
    print('💾 写入文件...');
    final outputFile = File(outputPath);
    await outputFile.writeAsString(dartCode);

    print('✅ 生成成功: $outputPath');
    print();
    print('💡 提示: 运行 "flutter pub run build_runner build" 生成必要代码');
  } catch (e) {
    print('❌ 错误: $e');
    exit(1);
  }
}

/// 解析 CSV 文件
Map<String, Map<String, String>> _parseCsv(List<String> lines) {
  final translations = <String, Map<String, String>>{
    'en': {},
    'zh': {},
  };

  // 跳过表头（第一行）
  for (final line in lines.skip(1)) {
    // 跳过空行和注释行
    if (line.trim().isEmpty || line.trim().startsWith('#')) {
      continue;
    }

    // 分割 CSV 行
    final parts = line.split(',');
    if (parts.length < 2) {
      print('⚠️  跳过无效行: $line');
      continue;
    }

    final key = parts[0].trim();
    final zh = parts[1].trim();
    final en = parts.length > 2 ? parts[2].trim() : key;
    final category = parts.length > 3 ? parts[3].trim() : '其他';

    // 验证数据
    if (key.isEmpty) {
      print('⚠️  跳过空 key 的行: $line');
      continue;
    }

    // 添加翻译
    translations['zh']![key] = zh;
    translations['en']![key] = en;
  }

  return translations;
}

/// 生成 Dart 代码
String _generateDartCode(Map<String, Map<String, String>> translations) {
  final buffer = StringBuffer();

  // 文件头
  buffer.writeln('/// 自动生成的翻译数据');
  buffer.writeln('///');
  buffer.writeln('/// 生成时间: ${DateTime.now().toIso8601String()}');
  buffer.writeln('/// 请勿手动编辑此文件');
  buffer.writeln('///');
  buffer.writeln('/// 如需修改翻译，请编辑源 CSV 文件并重新运行生成工具');
  buffer.writeln();
  buffer.writeln('/// I18n 翻译数据');
  buffer.writeln('class I18nTranslations {');
  buffer.writeln('  /// 翻译数据映射');
  buffer.writeln('  static const Map<String, Map<String, String>> data = {');

  // 生成每种语言的翻译
  translations.forEach((lang, data) {
    buffer.writeln("    '$lang': {");
    buffer.writeln("      // === ${_getLanguageName(lang)} ===");

    data.forEach((key, value) {
      // 转义特殊字符
      final escapedValue = value
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n');

      buffer.writeln("      '$key': '$escapedValue',");
    });

    buffer.writeln('    },');
  });

  buffer.writeln('  };');
  buffer.writeln('}');

  return buffer.toString();
}

/// 获取语言名称
String _getLanguageName(String code) {
  switch (code) {
    case 'en':
      return 'English';
    case 'zh':
      return '简体中文';
    case 'ja':
      return '日本語';
    default:
      return 'Unknown';
  }
}

/// 获取 CSV 示例
String _getCsvExample() {
  return '''
Key,Zh,En,Category
Home,主页,Home,通用
Settings,设置,Settings,通用
About,关于,About,通用
Delete,删除,Delete,通用
AI Tools,AI 工具,AI Tools,AI 模块
AI Assistant,AI 助手,AI Assistant,AI 模块
Storage Settings,存储设置,Storage Settings,设置页面
Theme Settings,主题设置,Theme Settings,设置页面
Markdown Editor,Markdown 编辑器,Markdown Editor,编辑器
''';
}
