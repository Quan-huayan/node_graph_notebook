import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/lua_script.dart';

/// Lua脚本管理服务
///
/// 负责Lua脚本的加载、保存、删除等管理操作
class LuaScriptService {
  /// 构造函数
  LuaScriptService({
    String? scriptsDirectory,
  }) : _scriptsDirectory = scriptsDirectory ?? defaultScriptsDirectory;

  /// 默认脚本存储目录
  static const String defaultScriptsDirectory = 'data/lua_scripts';

  /// 脚本存储目录
  final String _scriptsDirectory;

  /// UUID生成器
  final _uuid = const Uuid();

  /// 内存中的脚本缓存
  final Map<String, LuaScript> _scriptCache = {};

  /// 初始化服务
  ///
  /// 创建脚本目录，加载所有脚本
  Future<void> initialize() async {
    try {
      final dir = Directory(_scriptsDirectory);

      // 创建目录（如果不存在）
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }

      // 加载所有脚本
      await loadAllScripts();
    } catch (e) {
      throw LuaScriptServiceException('脚本服务初始化失败: $e');
    }
  }

  /// 加载所有脚本
  ///
  /// 从文件系统加载所有.lua文件到内存
  Future<List<LuaScript>> loadAllScripts() async {
    try {
      final dir = Directory(_scriptsDirectory);

      if (!dir.existsSync()) {
        return [];
      }

      final entities = await dir.list().toList();
      final scripts = <LuaScript>[];

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.lua')) {
          try {
            final script = await _loadScriptFromFile(entity);
            if (script != null) {
              scripts.add(script);
              _scriptCache[script.id] = script;
            }
          } catch (e) {
            // 跳过加载失败的脚本
            continue;
          }
        }
      }

      return scripts;
    } catch (e) {
      throw LuaScriptServiceException('加载脚本失败: $e');
    }
  }

  /// 从文件加载脚本
  Future<LuaScript?> _loadScriptFromFile(File file) async {
    try {
      // 读取内容
      final content = await file.readAsString();

      // 解析元数据注释（格式：-- key: value）
      final metadata = _parseMetadata(content);
      final scriptContent = _removeMetadata(content);

      // 从文件名生成ID
      final fileName = path.basenameWithoutExtension(file.path);
      final id = metadata['id'] ?? _uuid.v4();

      return LuaScript(
        id: id,
        name: metadata['name'] ?? fileName,
        content: scriptContent,
        enabled: metadata['enabled'] == 'true',
        description: metadata['description'],
        author: metadata['author'],
        version: metadata['version'],
        createdAt: metadata['createdAt'] != null
            ? DateTime.tryParse(metadata['createdAt']!)
            : null,
        updatedAt: metadata['updatedAt'] != null
            ? DateTime.tryParse(metadata['updatedAt']!)
            : null,
      );
    } catch (e) {
      return null;
    }
  }

  /// 解析脚本元数据
  Map<String, String> _parseMetadata(String content) {
    final metadata = <String, String>{};

    final lines = content.split('\n');
    for (final line in lines) {
      if (line.startsWith('--')) {
        final trimmed = line.substring(2).trim();
        final colonIndex = trimmed.indexOf(':');

        if (colonIndex > 0) {
          final key = trimmed.substring(0, colonIndex).trim();
          final value = trimmed.substring(colonIndex + 1).trim();
          metadata[key] = value;
        }
      } else if (line.trim().isNotEmpty) {
        // 遇到非注释行，停止解析元数据
        break;
      }
    }

    return metadata;
  }

  /// 移除元数据注释
  String _removeMetadata(String content) {
    final lines = content.split('\n');
    final startIndex = lines.indexWhere((line) =>
        !line.startsWith('--') || line.trim().isEmpty);

    if (startIndex == -1) {
      return content;
    }

    return lines.sublist(startIndex).join('\n');
  }

  /// 保存脚本
  ///
  /// [script] 要保存的脚本对象
  /// 如果脚本已存在则更新，否则创建新脚本
  Future<void> saveScript(LuaScript script) async {
    try {
      final dir = Directory(_scriptsDirectory);

      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }

      // 构建文件路径
      final fileName = '${script.name}.lua';
      final filePath = path.join(_scriptsDirectory, fileName);
      final file = File(filePath);

      // 构建脚本内容（包含元数据）
      final content = _buildScriptContent(script);

      // 写入文件
      await file.writeAsString(content);

      // 更新缓存
      _scriptCache[script.id] = script.copyWith(updatedAt: DateTime.now());
    } catch (e) {
      throw LuaScriptServiceException('保存脚本失败: $e');
    }
  }

  /// 构建脚本内容（包含元数据）
  String _buildScriptContent(LuaScript script) {
    final buffer = StringBuffer();

    // 写入元数据
    buffer.writeln('-- id: ${script.id}');
    buffer.writeln('-- name: ${script.name}');
    if (script.description != null) {
      buffer.writeln('-- description: ${script.description}');
    }
    if (script.author != null) {
      buffer.writeln('-- author: ${script.author}');
    }
    if (script.version != null) {
      buffer.writeln('-- version: ${script.version}');
    }
    buffer.writeln('-- enabled: ${script.enabled}');
    if (script.createdAt != null) {
      buffer.writeln('-- createdAt: ${script.createdAt!.toIso8601String()}');
    }
    buffer.writeln('-- updatedAt: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    // 写入脚本内容
    buffer.write(script.content);

    return buffer.toString();
  }

  /// 删除脚本
  ///
  /// [scriptId] 脚本ID
  Future<void> deleteScript(String scriptId) async {
    try {
      final script = _scriptCache[scriptId];
      if (script == null) {
        throw LuaScriptServiceException('脚本不存在: $scriptId');
      }

      final fileName = '${script.name}.lua';
      final filePath = path.join(_scriptsDirectory, fileName);
      final file = File(filePath);

      if (file.existsSync()) {
        await file.delete();
      }

      // 从缓存中移除
      _scriptCache.remove(scriptId);
    } catch (e) {
      throw LuaScriptServiceException('删除脚本失败: $e');
    }
  }

  /// 启用脚本
  ///
  /// [scriptId] 脚本ID
  Future<void> enableScript(String scriptId) async {
    final script = _scriptCache[scriptId];
    if (script == null) {
      throw LuaScriptServiceException('脚本不存在: $scriptId');
    }

    final updated = script.copyWith(enabled: true);
    await saveScript(updated);
    _scriptCache[scriptId] = updated;
  }

  /// 禁用脚本
  ///
  /// [scriptId] 脚本ID
  Future<void> disableScript(String scriptId) async {
    final script = _scriptCache[scriptId];
    if (script == null) {
      throw LuaScriptServiceException('脚本不存在: $scriptId');
    }

    final updated = script.copyWith(enabled: false);
    await saveScript(updated);
    _scriptCache[scriptId] = updated;
  }

  /// 获取脚本信息
  ///
  /// [scriptId] 脚本ID
  LuaScript? getScriptInfo(String scriptId) {
    return _scriptCache[scriptId];
  }

  /// 获取所有启用的脚本
  List<LuaScript> getEnabledScripts() {
    return _scriptCache.values.where((script) => script.enabled).toList();
  }

  /// 获取所有脚本
  List<LuaScript> getAllScripts() {
    return _scriptCache.values.toList();
  }

  /// 清空缓存
  void clearCache() {
    _scriptCache.clear();
  }

  /// 释放资源
  Future<void> dispose() async {
    clearCache();
  }
}

/// Lua脚本服务异常基类
class LuaScriptServiceException implements Exception {
  /// 构造函数
  const LuaScriptServiceException(this.message);

  /// 错误信息
  final String message;

  @override
  String toString() => 'LuaScriptServiceException: $message';
}

/// Lua脚本未找到异常
class LuaScriptNotFoundException extends LuaScriptServiceException {
  /// 构造函数
  ///
  /// 参数：
  /// - [scriptId]: 未找到的脚本ID
  /// - [scriptPath]: 未找到的脚本路径（可选）
  const LuaScriptNotFoundException(
    this.scriptId, {
    this.scriptPath,
  }) : super('脚本未找到: $scriptId');

  /// 脚本ID
  final String scriptId;

  /// 脚本路径
  final String? scriptPath;

  @override
  String toString() {
    final buffer = StringBuffer('LuaScriptNotFoundException: $message');
    if (scriptPath != null) {
      buffer.write('\n路径: $scriptPath');
    }
    return buffer.toString();
  }
}

/// Lua脚本解析异常
class LuaScriptParseException extends LuaScriptServiceException {
  /// 构造函数
  ///
  /// 参数：
  /// - [scriptPath]: 脚本文件路径
  /// - [error]: 解析错误信息
  /// - [lineNumber]: 错误行号（可选）
  const LuaScriptParseException(
    this.scriptPath,
    this.error, {
    this.lineNumber,
  }) : super('脚本解析失败: $scriptPath');

  /// 脚本文件路径
  final String scriptPath;

  /// 解析错误信息
  final String error;

  /// 错误行号
  final int? lineNumber;

  @override
  String toString() {
    final buffer = StringBuffer('LuaScriptParseException: $message');
    buffer.write('\n错误: $error');
    if (lineNumber != null) {
      buffer.write('\n行号: $lineNumber');
    }
    return buffer.toString();
  }
}

/// Lua脚本IO异常
class LuaScriptIOException extends LuaScriptServiceException {
  /// 构造函数
  ///
  /// 参数：
  /// - [operation]: 操作类型（read、write、delete等）
  /// - [path]: 文件路径
  /// - [error]: 底层错误信息
  const LuaScriptIOException(
    this.operation,
    this.path,
    this.error,
  ) : super('脚本IO错误: $operation failed for $path');

  /// 操作类型
  final String operation;

  /// 文件路径
  final String path;

  /// 底层错误信息
  final String error;
}
