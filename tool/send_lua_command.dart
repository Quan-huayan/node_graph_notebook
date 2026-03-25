#!/usr/bin/env dart

/// Lua 命令行发送工具
///
/// 使用方法：
/// ```bash
/// # 发送单行命令
/// dart run tool/send_lua_command.dart "debugPrint('Hello')"
///
/// # 发送多行脚本
/// dart run tool/send_lua_command.dart "
/// onTest = function()
///     debugPrint('Test')
/// end
/// registerToolbarButton('test', 'Test', 'onTest', 'star')
/// "
///
/// # 从文件读取
/// dart run tool/send_lua_command.dart --file=myscript.lua
/// ```

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  if (args.isEmpty) {
    debugPrint('用法：');
    debugPrint('  dart run tool/send_lua_command.dart "<Lua代码>"');
    debugPrint('  dart run tool/send_lua_command.dart --file=<脚本文件>');
    debugPrint('');
    debugPrint('示例：');
    debugPrint('  dart run tool/send_lua_command.dart "debugPrint(\'Hello\')"');
    debugPrint('  dart run tool/send_lua_command.dart --file=test.lua');
    exit(1);
  }

  // 获取命令目录
  final tempDir = Directory.systemTemp;
  final commandDir = Directory(path.join(tempDir.path, 'lua_commands'));

  // 确保命令目录存在
  if (!commandDir.existsSync()) {
    await commandDir.create(recursive: true);
  }

  var scriptContent = '';

  // 解析参数
  if (args[0].startsWith('--file=')) {
    // 从文件读取
    final filePath = args[0].substring(7);
    final file = File(filePath);

    if (!file.existsSync()) {
      debugPrint('错误: 文件不存在: $filePath');
      exit(1);
    }

    scriptContent = await file.readAsString();
    debugPrint('从文件读取脚本: $filePath');
  } else {
    // 直接使用命令行参数
    scriptContent = args.join(' ');
  }

  // 生成唯一的文件名
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final scriptFile = File(path.join(commandDir.path, 'command_$timestamp.lua'));

  // ✅ 确保使用纯UTF-8编码写入文件
  final utf8Content = scriptContent;

  // 调试信息：显示原始内容
  debugPrint('📝 脚本内容长度: ${utf8Content.length} 字符');
  debugPrint('📝 脚本内容: $utf8Content');

  // 先验证内容是否为有效的UTF-8
  final bytes = utf8.encode(utf8Content);
  debugPrint('📝 编码后字节数: ${bytes.length} 字节');
  if (bytes.isNotEmpty) {
    debugPrint('📝 前20字节(Hex): ${bytes.sublist(0, bytes.length > 20 ? 20 : bytes.length).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
  }

  // 直接写入字符串，让Dart自动处理UTF-8编码
  await scriptFile.writeAsString(utf8Content, encoding: utf8);

  // 验证写入的文件
  final writtenBytes = await scriptFile.readAsBytes();
  debugPrint('📝 文件实际大小: ${writtenBytes.length} 字节');
  if (writtenBytes.isNotEmpty && writtenBytes.length != bytes.length) {
    debugPrint('⚠️  警告: 写入的字节数与编码后的字节数不匹配!');
  }

  debugPrint('✓ 脚本已发送到应用');
  debugPrint('  文件: ${scriptFile.path}');
  debugPrint('');
  debugPrint('请查看 Flutter 应用的 Debug Console 输出');
  debugPrint('');
  debugPrint('提示: 如果应用没有运行，请先启动应用');
  debugPrint('      flutter run');
}
