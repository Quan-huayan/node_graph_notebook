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
/// dart tool/generate_i18n.dart --output=lib/core/services/i18n/translations.dart

import 'dart:io';

import 'package:flutter/material.dart';

void main(List<String> args) async {
  debugPrint('╔════════════════════════════════════════════════════════════╗');
  debugPrint('║         I18n 翻译代码生成工具 v2.0                          ║');
  debugPrint('╚════════════════════════════════════════════════════════════╝');
  debugPrint('');

  // 解析参数
  var inputPath = 'assets/i18n/source.csv';
  var outputPath = 'lib/core/services/i18n/translations.dart';
  var verbose = false;

  for (final arg in args) {
    if (arg.startsWith('--input=')) {
      inputPath = arg.split('=')[1];
    } else if (arg.startsWith('--output=')) {
      outputPath = arg.split('=')[1];
    } else if (arg == '--verbose' || arg == '-v') {
      verbose = true;
    } else if (arg == '--help' || arg == '-h') {
      _printHelp();
      exit(0);
    }
  }

  debugPrint('📂 输入文件: $inputPath');
  debugPrint('📄 输出文件: $outputPath');
  debugPrint('');

  // 检查输入文件
  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    debugPrint('❌ 错误: 输入文件不存在');
    debugPrint('   路径: ${inputFile.absolute.path}');
    debugPrint('');
    debugPrint('💡 提示:');
    debugPrint('   1. 请确认文件路径正确');
    debugPrint('   2. 使用 --help 查看使用说明');
    debugPrint('   3. 运行工具时使用绝对路径或从项目根目录运行');
    exit(1);
  }

  try {
    // 读取 CSV
    debugPrint('📖 读取 CSV 文件...');
    final lines = await inputFile.readAsLines();

    if (lines.isEmpty) {
      debugPrint('❌ 错误: CSV 文件为空');
      exit(1);
    }

    // 解析 CSV
    debugPrint('🔍 解析翻译数据...');
    final result = _parseCsv(lines, verbose);

    if (result.isEmpty) {
      debugPrint('❌ 错误: 未找到任何翻译数据');
      exit(1);
    }

    // 统计信息
    final totalTranslations = result.values.fold<int>(
      0, (sum, lang) => sum + lang.length,
    );
    final categories = _extractCategories(result);

    debugPrint('✅ 解析完成:');
    result.forEach((lang, data) {
      final langName = _getLanguageName(lang);
      final count = data.length;
      debugPrint('   - $langName ($lang): $count 条');
    });
    debugPrint('   - 总计: $totalTranslations 条');
    debugPrint('   - 分类: ${categories.length} 个');
    if (verbose) {
      debugPrint('   - 分类列表: ${categories.join(', ')}');
    }
    debugPrint('');

    // 生成 Dart 代码
    debugPrint('🔨 生成 Dart 代码...');
    final dartCode = _generateDartCode(result, categories);

    // 确保输出目录存在
    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);

    // 写入文件
    debugPrint('💾 写入文件...');
    await outputFile.writeAsString(dartCode);

    debugPrint('✅ 生成成功: ${outputFile.absolute.path}');
    debugPrint('');
    debugPrint('💡 后续步骤:');
    debugPrint('   1. 检查生成的文件内容');
    debugPrint('   2. 运行应用测试翻译功能');
    debugPrint('   3. 如需修改，编辑 CSV 文件后重新生成');
  } catch (e, stack) {
    debugPrint('❌ 错误: $e');
    if (verbose) {
      debugPrint('堆栈跟踪:');
      debugPrint(stack.toString());
    }
    exit(1);
  }
}

/// 解析 CSV 文件
/// 返回结构: { 'zh': { 'key': 'value', ... }, 'en': { ... } }
Map<String, Map<String, TranslationEntry>> _parseCsv(List<String> lines, bool verbose) {
  final translations = <String, Map<String, TranslationEntry>>{
    'en': {},
    'zh': {},
  };

  var lineNumber = 0;
  var skippedCount = 0;

  // 跳过表头（第一行）
  for (final line in lines.skip(1)) {
    lineNumber++;

    // 跳过空行和注释行
    if (line.trim().isEmpty || line.trim().startsWith('#')) {
      continue;
    }

    // 使用更智能的 CSV 解析（处理带引号的字段）
    final parts = _parseCsvLine(line);

    if (parts.length < 3) {
      if (verbose) {
        debugPrint('⚠️  行 $lineNumber: 字段不足，跳过');
      }
      skippedCount++;
      continue;
    }

    final key = parts[0].trim();
    final zh = parts[1].trim();
    final en = parts[2].trim();
    final category = parts.length > 3 ? parts[3].trim() : '其他';
    final notes = parts.length > 4 ? parts[4].trim() : '';

    // 验证数据
    if (key.isEmpty) {
      if (verbose) {
        debugPrint('⚠️  行 $lineNumber: key 为空，跳过');
      }
      skippedCount++;
      continue;
    }

    if (zh.isEmpty && en.isEmpty) {
      if (verbose) {
        debugPrint('⚠️  行 $lineNumber: 中英文翻译都为空，跳过');
      }
      skippedCount++;
      continue;
    }

    // 添加翻译
    translations['zh']![key] = TranslationEntry(
      key: key,
      value: zh.isEmpty ? key : zh,
      category: category,
      notes: notes,
    );

    translations['en']![key] = TranslationEntry(
      key: key,
      value: en.isEmpty ? key : en,
      category: category,
      notes: notes,
    );
  }

  if (skippedCount > 0 && verbose) {
    debugPrint('ℹ️  跳过 $skippedCount 行无效数据');
  }

  return translations;
}

/// 解析单行 CSV，正确处理带引号的字段
List<String> _parseCsvLine(String line) {
  final parts = <String>[];
  var current = '';
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];

    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        // 转义的引号
        current += '"';
        i++; // 跳过下一个引号
      } else {
        // 切换引号状态
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      // 字段分隔符
      parts.add(current);
      current = '';
    } else {
      current += char;
    }
  }

  // 添加最后一个字段
  parts.add(current);

  return parts;
}

/// 提取所有分类
Set<String> _extractCategories(Map<String, Map<String, TranslationEntry>> translations) {
  final categories = <String>{};

  for (final langData in translations.values) {
    for (final entry in langData.values) {
      if (entry.category.isNotEmpty) {
        categories.add(entry.category);
      }
    }
  }

  return categories;
}

/// 生成 Dart 代码
String _generateDartCode(Map<String, Map<String, TranslationEntry>> translations, Set<String> categories) {
  final buffer = StringBuffer();
  final timestamp = DateTime.now().toIso8601String();

  // 文件头
  buffer.writeln('/// 自动生成的翻译数据');
  buffer.writeln('///');
  buffer.writeln('/// 生成时间: $timestamp');
  buffer.writeln('/// 翻译条目: ${_getTotalCount(translations)} 条');
  buffer.writeln('/// 分类: ${categories.length} 个');
  buffer.writeln('///');
  buffer.writeln('/// ⚠️  请勿手动编辑此文件 ⚠️');
  buffer.writeln('///');
  buffer.writeln('/// 如需修改翻译，请编辑源 CSV 文件并重新运行生成工具：');
  buffer.writeln('///   dart tool/generate_i18n.dart');
  buffer.writeln();
  buffer.writeln('// 忽略 long_string 提示，因为这是翻译数据');
  buffer.writeln('// ignore_for_file: long_string_literal_lines');
  buffer.writeln();
  buffer.writeln('/// I18n 翻译数据类');
  buffer.writeln('///');
  buffer.writeln('/// 提供应用的多语言翻译支持');
  buffer.writeln('class I18nTranslations {');
  buffer.writeln('  /// 翻译数据映射');
  buffer.writeln('  ///');
  buffer.writeln('  /// 结构: { 语言代码: { 翻译键: 翻译值 } }');
  buffer.writeln('  /// 例如: { "zh": { "Home": "主页" } }');
  buffer.writeln('  static const Map<String, Map<String, String>> data = {');

  // 生成每种语言的翻译
  translations.forEach((lang, data) {
    buffer.writeln("    '$lang': {");
    buffer.writeln('      // === ${_getLanguageName(lang)} ===');
    buffer.writeln('      // 共 ${data.length} 条翻译');
    buffer.writeln();

    // 按分类组织翻译
    final categorizedData = _groupByCategory(data);

    categorizedData.forEach((category, entries) {
      if (category.isNotEmpty) {
        buffer.writeln('      // === $category ===');
      }

      for (var entry in entries) {
        final escapedKey = _escapeString(entry.key);
        final escapedValue = _escapeString(entry.value);

        // 添加注释（如果有备注）
        if (entry.notes.isNotEmpty) {
          buffer.writeln('      // ${entry.notes}');
        }

        buffer.writeln("      '$escapedKey': '$escapedValue',");
      }

      buffer.writeln();
    });

    buffer.writeln('    },');
  });

  buffer.writeln('  };');
  buffer.writeln('}');

  return buffer.toString();
}

/// 按分类分组翻译条目
Map<String, List<TranslationEntry>> _groupByCategory(Map<String, TranslationEntry> data) {
  final grouped = <String, List<TranslationEntry>>{};

  for (final entry in data.values) {
    final category = entry.category.isEmpty ? '其他' : entry.category;
    grouped.putIfAbsent(category, () => []).add(entry);
  }

  return grouped;
}

/// 获取总翻译条目数（单语言）
int _getTotalCount(Map<String, Map<String, TranslationEntry>> translations) => translations.values.first.length;

/// 转义字符串中的特殊字符
String _escapeString(String value) {
  return value
      .replaceAll('\\', '\\\\')  // 反斜杠
      .replaceAll("'", "\\'")     // 单引号
      .replaceAll('\n', '\\n')    // 换行
      .replaceAll('\r', '\\r')    // 回车
      .replaceAll('\t', '\\t');   // 制表符
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
    case 'ko':
      return '한국어';
    case 'fr':
      return 'Français';
    case 'de':
      return 'Deutsch';
    case 'es':
      return 'Español';
    default:
      return 'Unknown ($code)';
  }
}

/// 翻译条目数据类
class TranslationEntry {

  TranslationEntry({
    required this.key,
    required this.value,
    required this.category,
    required this.notes,
  });
  final String key;
  final String value;
  final String category;
  final String notes;
}

/// 打印帮助信息
void _printHelp() {
  debugPrint('I18n 翻译代码生成工具 - 帮助');
  debugPrint('');
  debugPrint('用法:');
  debugPrint('  dart tool/generate_i18n.dart [选项]');
  debugPrint('');
  debugPrint('选项:');
  debugPrint('  --input=<path>     指定输入 CSV 文件路径');
  debugPrint('                     (默认: assets/i18n/source.csv)');
  debugPrint('  --output=<path>    指定输出 Dart 文件路径');
  debugPrint('                     (默认: lib/core/services/i18n/translations.dart)');
  debugPrint('  -v, --verbose      显示详细输出');
  debugPrint('  -h, --help         显示此帮助信息');
  debugPrint('');
  debugPrint('CSV 格式:');
  debugPrint('  Key,Zh,En,Category,Notes');
  debugPrint('  Home,主页,Home,通用,');
  debugPrint('  Settings,设置,Settings,通用,');
  debugPrint('  AI Tools,AI 工具,AI Tools,AI模块,');
  debugPrint('');
  debugPrint('示例:');
  debugPrint('  # 使用默认路径');
  debugPrint('  dart tool/generate_i18n.dart');
  debugPrint('');
  debugPrint('  # 指定输入输出路径');
  debugPrint('  dart tool/generate_i18n.dart --input=custom.csv --output=output.dart');
  debugPrint('');
  debugPrint('  # 显示详细信息');
  debugPrint('  dart tool/generate_i18n.dart --verbose');
}
