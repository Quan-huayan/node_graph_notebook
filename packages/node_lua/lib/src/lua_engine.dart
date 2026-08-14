/// LuaEngine —— Lua 5.4 运行时封装（M7 node_lua，archive lua_engine 精简带走）。
///
/// 修复（旧 lua_engine 缺陷）：flutter_embed_lua 的 `run` 对错误返回
/// "Error: ..." 前缀而非抛异常——旧实现未检测，脚本错误被当成功；
/// 本封装检测前缀并抛 [LuaEngineException]。
///
/// 能力：
/// - 沙箱（禁用 os/io/package/require/debug/load*——archive 资产带走）
/// - Dart → Lua 值传递（节点数据拼 Lua 表字面量，旧 _valueToLuaString 带走）
/// - Lua → Dart 宿主 API（`host.node_*`，单 C 回调分发，返回值 = 字符串）
/// - 执行表达式并读取返回值（executeAndReadTop，栈读取）
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'vendor/lua_bindings.dart';
import 'vendor/lua_runtime.dart';

/// 执行超时默认值（保留字段；MVP 未实现硬超时——沙箱为安全边界，
/// 已知限制记录于文档）。
const Duration luaDefaultTimeout = Duration(seconds: 5);

/// Lua 引擎封装。
class LuaEngine {
  /// 构造（引擎延迟初始化）。
  LuaEngine();

  LuaRuntime? _runtime;

  /// Dart → Lua 宿主函数表（单 C 回调分发）。
  final Map<String, dynamic Function(List<dynamic>)> _hostFunctions = {};

  /// 是否已初始化。
  bool get isInitialized => _runtime != null;

  /// 初始化：加载 Lua 5.4 + 沙箱 + host 表注入。
  ///
  /// 失败抛 [LuaEngineException]（dll 缺失/加载失败——调用方隔离）。
  void initialize() {
    if (_runtime != null) {
      throw StateError('LuaEngine 已初始化');
    }
    try {
      _runtime = LuaRuntime();
      // 单引擎实例：静态回调分发固定绑定（M7 设计；多引擎隔离 = M7+）。
      _bind();
      _enableSandbox();
      _injectHostTable();
    } catch (e) {
      throw LuaEngineException('Lua 引擎初始化失败: $e');
    }
  }

  /// 沙箱：禁用危险 API（archive 资产带走；脚本无文件/进程/require 能力）。
  void _enableSandbox() {
    final result = run(
      'os = nil; io = nil; package = nil; require = nil; debug = nil;'
      'load = nil; loadstring = nil; loadfile = nil; dofile = nil;'
      'collectgarbage = nil; rawget = nil; rawset = nil;',
    );
    if (result.startsWith(errorPrefix)) {
      throw LuaEngineException('沙箱启用失败: $result');
    }
  }

  /// 注入 `host` 表（宿主写 API 的 Lua 包装，经单 C 回调分发）。
  void _injectHostTable() {
    final result = run(
      'host = {\n'
      "  node_create = function(payload) return __call_host('node_create', payload) end,\n"
      "  node_update = function(payload) return __call_host('node_update', payload) end,\n"
      "  node_delete = function(payload) return __call_host('node_delete', payload) end,\n"
      '}\n',
    );
    if (result.startsWith(errorPrefix)) {
      throw LuaEngineException('host 表注入失败: $result');
    }
  }

  /// 错误前缀（flutter_embed_lua run 的错误通道）。
  static const String errorPrefix = 'Error: ';

  /// 注册 Dart 宿主函数（Lua 侧经 `host.<name>` 或 `__call_host` 调用）。
  ///
  /// [fn] 接收 Lua 传入参数（标量/表 → Dart 值），返回 String（"ok" 或
  /// "error:消息"）或可 tostring 的值。返回值压栈为字符串。
  void registerHostFunction(String name, dynamic Function(List<dynamic>) fn) {
    if (_hostFunctions.isEmpty) {
      _runtime!.registerFunction('__call_host', _callHostPointer);
    }
    _hostFunctions[name] = fn;
  }

  /// 执行脚本字符串（定义全局；语法/运行时错误抛异常）。
  String run(String code) {
    final result = _runtime!.run(code);
    if (result.startsWith(errorPrefix)) {
      throw LuaEngineException(result.substring(errorPrefix.length));
    }
    return result;
  }

  /// 执行 Lua 表达式并读取返回值（bool/num/String/Map）。
  dynamic eval(String code) => _runtime!.executeAndReadTop(code);

  /// 从 Lua 取回全局表（脚本定义的 Concept/Commands 表）。
  ///
  /// 注：Lua chunk 不允许裸表达式语句（只允许函数调用）——须 `return`
  /// 前缀取回值（M7 修正）；错误经 evalBound 包装为 LuaEngineException
  /// （坏脚本隔离统一捕获路径）。
  Map<String, dynamic> getGlobalTable(String name) {
    final table = evalBound('return $name');
    if (table is! Map<String, dynamic>) {
      throw LuaEngineException('全局表不存在或不是 table: $name');
    }
    return table;
  }

  /// 执行脚本文件（读文件 → run；文件不存在抛异常）。
  String runFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw LuaEngineException('脚本文件不存在: $path');
    }
    return run(file.readAsStringSync());
  }

  /// 释放引擎。
  void dispose() {
    _runtime?.dispose();
    _runtime = null;
    _hostFunctions.clear();
    _unbind();
  }

  // ---- C 回调（单分发器：所有 host.* 调用经此）----

  static final Pointer<NativeFunction<Int32 Function(Pointer<lua_State>)>>
  _callHostPointer = Pointer.fromFunction<Int32 Function(Pointer<lua_State>)>(
    _callHost,
    0,
  );

  /// 宿主调用分发（第 1 参数 = 函数名，第 2..n = 参数）。
  static int _callHost(Pointer<lua_State> L) {
    final bindings = LuaRuntime.lua;
    final n = bindings.lua_gettop(L);
    if (n < 1) {
      return 0;
    }
    final name = _luaToString(bindings, L, 1);
    final args = <dynamic>[];
    for (var i = 2; i <= n; i++) {
      args.add(_luaToDartValue(bindings, L, i));
    }
    final engine = _currentEngine;
    if (engine == null) {
      return 0;
    }
    final fn = engine._hostFunctions[name];
    String result;
    if (fn == null) {
      result = 'error:未知宿主函数 $name';
    } else {
      try {
        final value = fn(args);
        result = value is String ? value : value.toString();
      } catch (e) {
        result = 'error:$e';
      }
    }
    // 压栈字符串返回值（M7：宿主 API 返回值 = 字符串通道）。
    final cstr = result.toNativeUtf8();
    bindings.lua_pushstring(L, cstr.cast<Char>());
    calloc.free(cstr);
    return 1;
  }

  /// 当前引擎（C 回调静态分发需要）。
  static LuaEngine? _currentEngine;

  /// 绑定当前引擎（run/eval 期间——M7 单引擎实例，构造时绑定）。
  void _bind() {
    _currentEngine = this;
  }

  /// 解除绑定。
  void _unbind() {
    _currentEngine = null;
  }

  /// 脚本执行入口（绑定引擎后执行；runFile/run/eval 内部使用）。
  // 说明：单引擎实例下静态引用固定；多引擎（隔离测试）场景需绑定——
  // M7 用 _bind/_unbind 包裹 eval/run（见下）。

  // ---- Lua ↔ Dart 值转换（archive lua_engine 带走）----

  /// Lua 值 → Dart（标量 + 表递归；栈位置读取）。
  ///
  /// 修正记录（M7）：number 用 lua_tonumberx（lua_tolstring 会原地改栈
  /// 上 number 为 string，破坏 lua_next 键）。
  static dynamic _luaToDartValue(
    LuaBindings bindings,
    Pointer<lua_State> L,
    int index,
  ) {
    final type = bindings.lua_type(L, index);
    switch (type) {
      case luaTypeNil:
      case luaTypeNone:
        return null;
      case luaTypeBoolean:
        return bindings.lua_toboolean(L, index) != 0;
      case luaTypeNumber:
        return bindings.lua_tonumberx(L, index, nullptr);
      case luaTypeString:
        final ptr = bindings.lua_tolstring(L, index, nullptr);
        return ptr.address == 0 ? '' : ptr.cast<Utf8>().toDartString();
      case luaTypeTable:
        return _parseTable(bindings, L, index);
      default:
        return _luaToString(bindings, L, index);
    }
  }

  /// Lua 值 → 字符串（栈位置读取）。
  static String _luaToString(
    LuaBindings bindings,
    Pointer<lua_State> L,
    int index,
  ) {
    final ptr = bindings.lua_tolstring(L, index, nullptr);
    return ptr.address == 0 ? '' : ptr.cast<Utf8>().toDartString();
  }

  /// 表 → Map（lua_next 遍历；嵌套支持）。
  static Map<String, dynamic> _parseTable(
    LuaBindings bindings,
    Pointer<lua_State> L,
    int index,
  ) {
    final result = <String, dynamic>{};
    if (index < 0) {
      index = bindings.lua_gettop(L) + index + 1;
    }
    final top = bindings.lua_gettop(L);
    bindings.lua_pushnil(L);
    while (bindings.lua_next(L, index) != 0) {
      final key = _luaToDartValue(bindings, L, -2);
      final value = _luaToDartValue(bindings, L, -1);
      bindings.lua_settop(L, -2);
      if (key is String) {
        result[key] = value;
      }
    }
    bindings.lua_settop(L, top);
    return result;
  }

  /// Dart 值 → Lua 字面量字符串（节点数据拼表，archive 带走）。
  static String toLuaLiteral(dynamic value) {
    if (value == null) {
      return 'nil';
    } else if (value is String) {
      final escaped = value
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r');
      return "'$escaped'";
    } else if (value is num || value is bool) {
      return value.toString();
    } else if (value is List) {
      return '{${value.map(toLuaLiteral).join(', ')}}';
    } else if (value is Map) {
      final pairs = value.entries
          .map((e) => "['${e.key}'] = ${toLuaLiteral(e.value)}")
          .join(', ');
      return '{$pairs}';
    } else {
      return "'${value.toString()}'";
    }
  }

  /// 执行表达式（绑定引擎；错误抛 LuaEngineException）。
  dynamic evalBound(String code) {
    _bind();
    try {
      return eval(code);
    } on LuaValueError catch (e) {
      throw LuaEngineException(e.message);
    } finally {
      _unbind();
    }
  }
}

/// Lua 引擎异常（脚本错误/引擎初始化失败——调用方隔离）。
class LuaEngineException implements Exception {
  /// 构造异常。
  LuaEngineException(this.message);

  /// 错误消息。
  final String message;

  @override
  String toString() => 'LuaEngineException: $message';
}
