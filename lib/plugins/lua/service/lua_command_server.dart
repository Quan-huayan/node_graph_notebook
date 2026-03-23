import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'lua_engine_service.dart';

/// Lua 命令服务器
///
/// 监听指定目录中的 Lua 脚本文件，自动执行
///
/// 使用方法：
/// 1. 启动 Flutter 应用
/// 2. 在命令行中执行：
///    ```bash
///    echo 'print("Hello")' > /tmp/lua_command.lua
///    ```
/// 3. 应用自动执行脚本并输出结果
class LuaCommandServer {
  /// 构造函数
  LuaCommandServer({
    required this.engineService,
    this.commandDirectory,
  });

  /// Lua 引擎服务
  final LuaEngineService engineService;

  /// 命令目录（默认为临时目录）
  final Directory? commandDirectory;

  /// 监听器
  FileSystemWatcher? _watcher;

  /// 是否正在运行
  bool _isRunning = false;

  /// 最后处理的文件修改时间
  final Map<String, DateTime> _lastProcessed = {};

  /// 启动服务器
  Future<void> start() async {
    if (_isRunning) {
      debugPrint('[LuaCommandServer] 服务器已在运行');
      return;
    }

    final dir = commandDirectory ?? Directory.systemTemp;
    final commandDir = Directory(path.join(dir.path, 'lua_commands'));

    // 创建命令目录
    if (!await commandDir.exists()) {
      await commandDir.create(recursive: true);
    }

    debugPrint('[LuaCommandServer] 启动服务器');
    debugPrint('[LuaCommandServer] 命令目录: ${commandDir.path}');
    debugPrint('[LuaCommandServer]');
    debugPrint('[LuaCommandServer] 使用方法:');
    debugPrint('[LuaCommandServer]   echo "print(\'Hello\')" > ${commandDir.path}/command.lua');
    debugPrint('[LuaCommandServer]');

    _isRunning = true;

    // 启动文件监听
    _watcher = FileSystemWatcher(
      commandDir.path,
      onFileChange: _onFileChanged,
    );
    await _watcher!.start();
  }

  /// 停止服务器
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    await _watcher?.stop();
    _watcher = null;

    debugPrint('[LuaCommandServer] 服务器已停止');
  }

  /// 处理文件变化
  void _onFileChanged(String filePath) async {
    if (!_isRunning) return;

    // 只处理 .lua 文件
    if (!filePath.endsWith('.lua')) return;

    // 防止重复处理
    final file = File(filePath);
    if (!await file.exists()) return;

    final stat = await file.stat();
    final lastTime = _lastProcessed[filePath];

    if (lastTime != null && stat.modified.isAtSameMomentAs(lastTime)) {
      return; // 已处理过
    }

    _lastProcessed[filePath] = stat.modified;

    debugPrint('[LuaCommandServer] ========================================');
    debugPrint('[LuaCommandServer] 检测到脚本: ${path.basename(filePath)}');
    debugPrint('[LuaCommandServer] ========================================');

    try {
      // ✅ 明确使用UTF-8编码读取文件（带容错处理）
      List<int> bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (e) {
        debugPrint('[LuaCommandServer] ✗ 无法读取文件: $e');
        return;
      }

      // 尝试检测并移除UTF-8 BOM（如果存在）
      String content;
      try {
        // 首先输出原始字节信息用于调试
        debugPrint('[LuaCommandServer] 🔍 文件大小: ${bytes.length} 字节');
        if (bytes.length > 60) {
          debugPrint('[LuaCommandServer] 🔍 前60字节: ${bytes.sublist(0, 60)}');
          debugPrint('[LuaCommandServer] 🔍 前60字节(Hex): ${bytes.sublist(0, 60).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
        }

        if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
          // 移除UTF-8 BOM
          debugPrint('[LuaCommandServer] 🔍 检测到UTF-8 BOM');
          content = utf8.decode(bytes.sublist(3), allowMalformed: true);
        } else {
          debugPrint('[LuaCommandServer] 🔍 未检测到BOM，直接解码');
          content = utf8.decode(bytes, allowMalformed: true);
        }
      } catch (e) {
        debugPrint('[LuaCommandServer] ✗ UTF-8解码失败: $e');
        debugPrint('[LuaCommandServer] 尝试使用系统默认编码...');
        content = await file.readAsString();
      }

      debugPrint('[LuaCommandServer] 脚本内容:');
      debugPrint('[LuaCommandServer] ---');
      debugPrint(content);
      debugPrint('[LuaCommandServer] ---');
      debugPrint('[LuaCommandServer]');

      // 执行脚本
      final result = await engineService.executeString(content);

      // 输出结果
      debugPrint('[LuaCommandServer] 执行结果:');
      debugPrint('[LuaCommandServer] ---');
      for (final line in result.output) {
        debugPrint('[LuaCommandServer] $line');
      }
      debugPrint('[LuaCommandServer] ---');

      if (result.success) {
        debugPrint('[LuaCommandServer] ✓ 执行成功');
      } else {
        debugPrint('[LuaCommandServer] ✗ 执行失败: ${result.error}');
      }

      // 删除已执行的文件
      await file.delete();
      debugPrint('[LuaCommandServer] 已清理脚本文件');
    } catch (e) {
      debugPrint('[LuaCommandServer] ✗ 处理脚本时出错: $e');
    }

    debugPrint('[LuaCommandServer] ========================================');
    debugPrint('[LuaCommandServer]');
  }
}

/// 文件系统监听器
class FileSystemWatcher {
  /// 构造函数
  FileSystemWatcher(
    this.directoryPath, {
    required this.onFileChange,
  });

  /// 监听的目录路径
  final String directoryPath;

  /// 文件变化回调
  final void Function(String filePath) onFileChange;

  /// 是否正在运行
  bool _isRunning = false;

  /// 定时器
  Timer? _timer;

  /// 最后的文件状态
  final Map<String, DateTime> _lastState = {};

  /// 启动监听
  Future<void> start() async {
    if (_isRunning) return;

    _isRunning = true;

    // 每秒检查一次
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkFiles();
    });

    debugPrint('[FileSystemWatcher] 开始监听: $directoryPath');
  }

  /// 停止监听
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    _timer?.cancel();
    _timer = null;

    debugPrint('[FileSystemWatcher] 停止监听');
  }

  /// 检查文件变化
  void _checkFiles() async {
    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) return;

      final files = await dir.list().toList();

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          final lastModified = _lastState[file.path];

          // 如果文件是新或被修改
          if (lastModified == null || stat.modified.isAfter(lastModified)) {
            _lastState[file.path] = stat.modified;
            onFileChange(file.path);
          }
        }
      }
    } catch (e) {
      // 忽略错误
    }
  }
}
