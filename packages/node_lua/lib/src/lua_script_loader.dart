/// LuaScriptLoader —— 脚本扫描与解析（M7 node_lua）。
///
/// 脚本 = data/lua_scripts/*.lua（文件树，可被编辑器/git 管理，00 §3.2）。
/// 每个脚本定义 `Concept` 全局表（动态 Concept）+ 可选 `Commands` 表
/// （命令处理函数）。**坏脚本隔离**：单个脚本加载/解析失败 → 跳过并
/// 记录错误，不影响其他脚本与宿主（架构 §8 PluginLoadError 思路）。
library;

import 'dart:io';

import 'package:core_data/core_data.dart';

import 'lua_concept.dart';
import 'lua_engine.dart';

/// 一个脚本的加载结果。
class LuaScriptResult {
  /// 构造结果。
  LuaScriptResult({required this.scriptId, this.concept, this.error});

  /// 脚本 id（文件名，去扩展名）。
  final String scriptId;

  /// 动态 Concept（解析成功）。
  final LuaConcept? concept;

  /// 加载/解析错误（坏脚本隔离；null = 成功）。
  final String? error;

  /// 是否成功。
  bool get ok => concept != null;
}

/// 脚本加载器。
class LuaScriptLoader {
  /// 注入引擎。
  LuaScriptLoader({required this.engine});

  /// 引擎。
  final LuaEngine engine;

  /// 扫描并加载目录内全部 *.lua（跳过隐藏文件）。
  ///
  /// [scriptsDir] 不存在 → 空列表（无脚本不是错误）。
  List<LuaScriptResult> loadAll(String scriptsDir) {
    final dir = Directory(scriptsDir);
    if (!dir.existsSync()) {
      return <LuaScriptResult>[];
    }
    final results = <LuaScriptResult>[];
    for (final file
        in dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.lua'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path))) {
      results.add(_loadFile(file));
    }
    return results;
  }

  /// 加载单个脚本（坏脚本隔离：错误返回，不抛）。
  LuaScriptResult _loadFile(File file) {
    final scriptId = file.uri.pathSegments.last.replaceAll('.lua', '');
    try {
      engine.run(file.readAsStringSync());
      final concept = _parseConcept();
      return LuaScriptResult(scriptId: scriptId, concept: concept);
    } on LuaEngineException catch (e) {
      return LuaScriptResult(scriptId: scriptId, error: e.message);
    } on StateError catch (e) {
      return LuaScriptResult(scriptId: scriptId, error: e.message);
    }
  }

  /// 从 Lua 全局解析 Concept 表（缺必需字段 → 抛错隔离）。
  LuaConcept? _parseConcept() {
    final table = engine.getGlobalTable('Concept');
    final id = table['id'];
    if (id is! String || id.isEmpty) {
      throw StateError('脚本缺少 Concept.id（字符串）');
    }
    final name = table['name'];
    if (name is! String || name.isEmpty) {
      throw StateError('脚本缺少 Concept.name（字符串）');
    }
    // 脚本定义验证函数？——执行表达式探测（概念存在 = 可调用）。
    final hasValidate = _hasGlobalFunction('Concept.validate');
    final hasCreateHook = _hasGlobalFunction('Concept.createHook');
    return LuaConcept(
      id: id,
      name: name,
      description: table['description'] is String
          ? table['description'] as String
          : 'Lua 动态 Concept（$id）',
      slots: _stringSet(table['slots']),
      requiredSlots: _stringSet(table['requiredSlots']),
      requiredMetadataKeys: _stringSet(table['requiredMetadataKeys']),
      contentRequirement: _contentRequirement(table['contentRequirement']),
      hasValidate: hasValidate,
      hasCreateHook: hasCreateHook,
      engine: engine,
    );
  }

  /// Lua 全局是否存在函数（`type(name) == "function"`）。
  ///
  /// `return` 前缀：Lua chunk 不允许裸表达式语句（M7 修正）。
  bool _hasGlobalFunction(String name) {
    try {
      return engine.evalBound('return type($name) == "function"') == true;
    } on LuaEngineException {
      return false;
    }
  }

  /// 提取脚本命令名列表（Commands 表的字符串键）。
  ///
  /// 表读取：Dart 侧取回 Lua 表并枚举（引擎 eval 返回 Map；
  /// `return` 前缀——Lua chunk 不允许裸表达式语句）。
  List<String> commandNames() {
    try {
      final commands = engine.evalBound('return Commands');
      if (commands is Map<String, dynamic>) {
        return commands.keys.where((k) => k != 'list').toList()..sort();
      }
    } on LuaEngineException {
      // Commands 未定义 → 空。
    }
    return <String>[];
  }

  Set<String> _stringSet(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return <String>{};
    }
    return value.keys
        .where((k) => k != 'list')
        .where((k) => value[k] == true || value[k] == 1)
        .toSet();
  }

  ContentRequirement _contentRequirement(dynamic value) => switch (value) {
    'required' => ContentRequirement.required,
    'optional' => ContentRequirement.optional,
    _ => ContentRequirement.none,
  };
}
