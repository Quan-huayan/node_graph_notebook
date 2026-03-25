import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_embed_lua/lua_bindings.dart';
import 'package:flutter_embed_lua/lua_runtime.dart';

import '../models/lua_execution_result.dart';

/// 真正的Lua引擎封装
class RealLuaEngine {
  /// 构造函数
  RealLuaEngine({
    this.enableDebugOutput = false,
    this.enableSandbox = true,
    this.executionTimeout = defaultExecutionTimeout,
  });

  /// 最大用户函数注册数量
  static const int maxUserFunctions = 50;
  static const int errorPrefixLength = 7;
  static const int callbackErrorPrefixLength = 16;
  static const Duration defaultExecutionTimeout = Duration(seconds: 5);
  static const Duration maxExecutionTimeout = Duration(seconds: 30);
  static RealLuaEngine? _currentEngine;

  /// 当前引擎的函数注册表
  static final Map<RealLuaEngine, Map<String, dynamic Function(List<dynamic>)>>
      _engineFunctionRegistry = {};

  /// 用户函数名称池
  static final List<String> _userFunctionNames = List.filled(200, '');

  /// Lua运行时实例
  LuaRuntime? _runtime;

  /// 是否启用调试输出
  final bool enableDebugOutput;

  /// 是否启用沙箱模式
  final bool enableSandbox;

  /// 脚本执行超时时间
  final Duration executionTimeout;

  /// 输出缓冲区
  final List<String> _outputBuffer = [];

  /// 已注册的Dart函数指针
  final List<Pointer<NativeFunction<Int32 Function(Pointer<lua_State>)>>>
      _functionPointers = [];

  /// 已注册的Dart函数映射
  final Map<String, dynamic Function(List<dynamic>)> _registeredFunctions = {};

  /// 是否已初始化
  bool get isInitialized => _runtime != null;

  /// 初始化引擎
  Future<void> initialize() async {
    if (_runtime != null) {
      throw StateError('Lua引擎已经初始化');
    }

    try {
      _runtime = LuaRuntime();
      _engineFunctionRegistry[this] = {};
      _registerBuiltInFunctions();

      if (enableDebugOutput) {
        _output('真正Lua引擎初始化成功 (Lua 5.2 via FFI)');
      }
    } catch (e) {
      throw LuaEngineException('Lua引擎初始化失败: $e');
    }
  }

  /// 注册内置函数
  void _registerBuiltInFunctions() {
    if (_runtime == null) return;

    if (enableSandbox) {
      _enableSandbox();
    }

    final printPtr =
        Pointer.fromFunction<Int32 Function(Pointer<lua_State>)>(_print, 0);
    _functionPointers.add(printPtr);
    _runtime!.registerFunction('print', printPtr);

    final logPtr =
        Pointer.fromFunction<Int32 Function(Pointer<lua_State>)>(_log, 0);
    _functionPointers.add(logPtr);
    _runtime!.registerFunction('log', logPtr);

    final debugPtr =
        Pointer.fromFunction<Int32 Function(Pointer<lua_State>)>(_debug, 0);
    _functionPointers.add(debugPtr);
    _runtime!.registerFunction('debug', debugPtr);
  }

  /// 启用安全沙箱
  void _enableSandbox() {
    if (_runtime == null) return;

    try {
      _runtime!.run('''
        os = nil
        io = nil
        package = nil
        require = nil
        debug = nil
        load = nil
        loadstring = nil
        loadfile = nil
        dofile = nil
      ''');

      if (enableDebugOutput) {
        _output('安全沙箱已启用：危险API已禁用');
      }
    } catch (e) {
      _output('警告：沙箱启用失败: $e');
    }
  }

  /// print函数的C回调
  static int _print(Pointer<lua_State> L) {
    final bindings = LuaRuntime.lua;
    final engine = _currentEngine;
    if (engine == null) return 0;

    final n = bindings.lua_gettop(L);
    final parts = <String>[];
    for (var i = 1; i <= n; i++) {
      parts.add(_luaToString(bindings, L, i));
    }
    engine._output(parts.join('\t'));
    return 0;
  }

  /// log函数的C回调
  static int _log(Pointer<lua_State> L) {
    final bindings = LuaRuntime.lua;
    final engine = _currentEngine;
    if (engine == null) return 0;

    if (bindings.lua_gettop(L) >= 1) {
      final message = _luaToString(bindings, L, 1);
      engine._output('[LOG] $message');
    }
    return 0;
  }

  /// debug函数的C回调
  static int _debug(Pointer<lua_State> L) {
    final bindings = LuaRuntime.lua;
    final engine = _currentEngine;
    if (engine == null) return 0;

    if (bindings.lua_gettop(L) >= 1) {
      final message = _luaToString(bindings, L, 1);
      engine._output('[DEBUG] $message');
    }
    return 0;
  }

  /// 将Lua值转换为字符串
  static String _luaToString(LuaBindings bindings, Pointer<lua_State> L, int index) {
    final type = bindings.lua_type(L, index);
    switch (type) {
      case LUA_TNONE:
      case LUA_TNIL:
        return 'nil';
      case LUA_TBOOLEAN:
        return bindings.lua_toboolean(L, index) != 0 ? 'true' : 'false';
      case LUA_TNUMBER:
        final ptr = bindings.lua_tolstring(L, index, nullptr);
        if (ptr == nullptr) return '0';
        return ptr.cast<Utf8>().toDartString();
      case LUA_TSTRING:
        final ptr = bindings.lua_tolstring(L, index, nullptr);
        if (ptr == nullptr) return '';
        return ptr.cast<Utf8>().toDartString();
      case LUA_TTABLE:
        return 'table';
      case LUA_TFUNCTION:
        return 'function';
      case LUA_TUSERDATA:
        return 'userdata';
      case LUA_TTHREAD:
        return 'thread';
      default:
        return 'unknown';
    }
  }

  /// 执行脚本字符串
  Future<LuaExecutionResult> executeString(
    String script, {
    Map<String, dynamic>? context,
  }) async {
    if (_runtime == null) {
      throw StateError('Lua引擎未初始化');
    }

    _outputBuffer.clear();
    _currentEngine = this;

    try {
      if (context != null) {
        _setContextVariables(context);
      }

      // 直接执行脚本，避免wrapper中的复杂字符串处理
      // 这样可以完全避免UTF-8编码和转义问题
      try {
        // 直接尝试加载和执行脚本
        _runtime!.run(script);

        return LuaExecutionResult.success(
          output: List.from(_outputBuffer),
        );
      } catch (e) {
        // 如果直接执行失败，返回错误信息
        return LuaExecutionResult.failure(
          error: e.toString(),
          output: List.from(_outputBuffer),
        );
      }
    } catch (e) {
      return LuaExecutionResult.failure(
        error: e.toString(),
        output: List.from(_outputBuffer),
      );
    } finally {
      _currentEngine = null;
    }
  }

  /// 执行脚本文件
  Future<LuaExecutionResult> executeFile(
    String filePath, {
    Map<String, dynamic>? context,
  }) async {
    if (_runtime == null) {
      throw StateError('Lua引擎未初始化');
    }

    _outputBuffer.clear();
    _currentEngine = this;

    try {
      if (context != null) {
        _setContextVariables(context);
      }

      // 🔒 修复：在沙箱模式下不使用dofile，而是读取文件内容并执行
      // 这样可以绕过沙箱对dofile的限制
      final file = File(filePath);
      if (!file.existsSync()) {
        return LuaExecutionResult.failure(
          error: '文件不存在: $filePath',
          output: List.from(_outputBuffer),
        );
      }

      final scriptContent = file.readAsStringSync();
      return await executeString(scriptContent, context: context);
    } catch (e) {
      return LuaExecutionResult.failure(
        error: '无法执行文件: $filePath\n错误: $e',
        output: List.from(_outputBuffer),
      );
    } finally {
      _currentEngine = null;
    }
  }

  /// 设置上下文变量
  void _setContextVariables(Map<String, dynamic> context) {
    if (_runtime == null) return;

    context.forEach((key, value) {
      final luaCode = _valueToLuaAssignment(key, value);
      try {
        _runtime!.run(luaCode);
      } catch (e) {
        _output('警告: 无法设置变量 $key: $e');
      }
    });
  }

  /// 将Dart值转换为Lua赋值语句
  String _valueToLuaAssignment(String name, dynamic value) {
    if (value == null) {
      return '$name = nil';
    } else if (value is String) {
      final escaped = value
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"')
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r')
          .replaceAll('\t', '\\t');
      return "$name = '$escaped'";
    } else if (value is num) {
      return '$name = $value';
    } else if (value is bool) {
      return '$name = ${value ? 'true' : 'false'}';
    } else if (value is List) {
      final elements = value.map(_valueToLuaString).join(', ');
      return '$name = {$elements}';
    } else if (value is Map) {
      final pairs = <String>[];
      value.forEach((k, v) {
        pairs.add("['$k'] = ${_valueToLuaString(v)}");
      });
      return '$name = {${pairs.join(', ')}}';
    } else {
      return "$name = '${value.toString()}'";
    }
  }

  /// 将Dart值转换为Lua字符串表示
  String _valueToLuaString(dynamic value) {
    if (value == null) {
      return 'nil';
    } else if (value is String) {
      final escaped = value
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n');
      return "'$escaped'";
    } else if (value is num) {
      return value.toString();
    } else if (value is bool) {
      return value ? 'true' : 'false';
    } else if (value is List) {
      final elements = value.map(_valueToLuaString).join(', ');
      return '{$elements}';
    } else if (value is Map) {
      final pairs = <String>[];
      value.forEach((k, v) {
        pairs.add("['$k'] = ${_valueToLuaString(v)}");
      });
      return '{${pairs.join(', ')}}';
    } else {
      return "'${value.toString()}'";
    }
  }

  /// 调用Lua回调函数
  Future<LuaExecutionResult> invokeCallback(
    String callbackName,
    List<dynamic> args,
  ) async {
    if (_runtime == null) {
      throw StateError('Lua引擎未初始化');
    }

    _outputBuffer.clear();
    _currentEngine = this;

    try {
      final argList = args.map(_valueToLuaString).join(', ');
      final script = '''
        if type($callbackName) == "function" then
          local success, result = pcall($callbackName, $argList)
          if not success then
            debugPrint("[CALLBACK_ERROR]" .. tostring(result))
          end
        else
          debugPrint("[CALLBACK_ERROR] Callback '$callbackName' is not a function")
        end
      ''';

      _runtime!.run(script);

      final errorLine = _outputBuffer.cast<String>().firstWhere(
        (line) => line.startsWith('[CALLBACK_ERROR]'),
        orElse: () => '',
      );

      if (errorLine.isNotEmpty) {
        final errorMsg = errorLine.substring(callbackErrorPrefixLength);
        _outputBuffer.remove(errorLine);
        return LuaExecutionResult.failure(
          error: errorMsg,
          output: List.from(_outputBuffer),
        );
      }

      return LuaExecutionResult.success(
        output: List.from(_outputBuffer),
      );
    } catch (e) {
      return LuaExecutionResult.failure(
        error: e.toString(),
        output: List.from(_outputBuffer),
      );
    } finally {
      _currentEngine = null;  // ✅ 修复：应该设置为null，不是this
    }
  }

  /// 注册Dart函数供Lua调用
  void registerFunction(String name, dynamic Function(List<dynamic>) fn) {
    if (_runtime == null) {
      throw StateError('Lua引擎未初始化');
    }

    final callbackIndex = _registeredFunctions.length;
    if (callbackIndex >= maxUserFunctions) {
      throw StateError('已达到最大用户函数数量限制 ($maxUserFunctions)');
    }

    _registeredFunctions[name] = fn;
    _engineFunctionRegistry[this]![name] = fn;
    _userFunctionNames[callbackIndex] = name;

    final callbackPtr = _getCallbackPointer(callbackIndex);
    _functionPointers.add(callbackPtr);
    _runtime!.registerFunction(name, callbackPtr);

    if (enableDebugOutput) {
      _output('注册函数: $name');
    }
  }

  /// 获取回调函数指针
  static Pointer<NativeFunction<Int32 Function(Pointer<lua_State>)>>
      _getCallbackPointer(int index) {
    switch (index) {
      case 0:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback0, 0);
      case 1:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback1, 0);
      case 2:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback2, 0);
      case 3:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback3, 0);
      case 4:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback4, 0);
      case 5:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback5, 0);
      case 6:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback6, 0);
      case 7:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback7, 0);
      case 8:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback8, 0);
      case 9:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback9, 0);
      case 10:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback10, 0);
      case 11:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback11, 0);
      case 12:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback12, 0);
      case 13:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback13, 0);
      case 14:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback14, 0);
      case 15:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback15, 0);
      case 16:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback16, 0);
      case 17:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback17, 0);
      case 18:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback18, 0);
      case 19:
        return Pointer.fromFunction<
            Int32 Function(Pointer<lua_State>)>(_userFunctionCallback19, 0);
      default:
        throw StateError('Invalid callback index: $index');
    }
  }

  /// 重置引擎状态
  Future<void> reset() async {
    if (_runtime == null) return;

    try {
      await dispose();
      _runtime = LuaRuntime();
      _registerBuiltInFunctions();

      if (enableDebugOutput) {
        _output('Lua引擎已重置');
      }
    } catch (e) {
      throw LuaEngineException('Lua引擎重置失败: $e');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    _runtime?.dispose();
    _runtime = null;
    _functionPointers.clear();
    _outputBuffer.clear();
    _registeredFunctions.clear();
    _engineFunctionRegistry.remove(this);

    if (enableDebugOutput) {
      _output('Lua引擎已释放');
    }
  }

  /// 输出到缓冲区
  void _output(String message) {
    _outputBuffer.add(message);
    if (enableDebugOutput) {
      debugPrint('[LUA] $message');
    }
  }

  /// 静态用户函数回调
  static int _userFunctionCallback0(Pointer<lua_State> L) =>
      _userFunctionDispatcher(0, L);
  static int _userFunctionCallback1(Pointer<lua_State> L) =>
      _userFunctionDispatcher(1, L);
  static int _userFunctionCallback2(Pointer<lua_State> L) =>
      _userFunctionDispatcher(2, L);
  static int _userFunctionCallback3(Pointer<lua_State> L) =>
      _userFunctionDispatcher(3, L);
  static int _userFunctionCallback4(Pointer<lua_State> L) =>
      _userFunctionDispatcher(4, L);
  static int _userFunctionCallback5(Pointer<lua_State> L) =>
      _userFunctionDispatcher(5, L);
  static int _userFunctionCallback6(Pointer<lua_State> L) =>
      _userFunctionDispatcher(6, L);
  static int _userFunctionCallback7(Pointer<lua_State> L) =>
      _userFunctionDispatcher(7, L);
  static int _userFunctionCallback8(Pointer<lua_State> L) =>
      _userFunctionDispatcher(8, L);
  static int _userFunctionCallback9(Pointer<lua_State> L) =>
      _userFunctionDispatcher(9, L);
  static int _userFunctionCallback10(Pointer<lua_State> L) =>
      _userFunctionDispatcher(10, L);
  static int _userFunctionCallback11(Pointer<lua_State> L) =>
      _userFunctionDispatcher(11, L);
  static int _userFunctionCallback12(Pointer<lua_State> L) =>
      _userFunctionDispatcher(12, L);
  static int _userFunctionCallback13(Pointer<lua_State> L) =>
      _userFunctionDispatcher(13, L);
  static int _userFunctionCallback14(Pointer<lua_State> L) =>
      _userFunctionDispatcher(14, L);
  static int _userFunctionCallback15(Pointer<lua_State> L) =>
      _userFunctionDispatcher(15, L);
  static int _userFunctionCallback16(Pointer<lua_State> L) =>
      _userFunctionDispatcher(16, L);
  static int _userFunctionCallback17(Pointer<lua_State> L) =>
      _userFunctionDispatcher(17, L);
  static int _userFunctionCallback18(Pointer<lua_State> L) =>
      _userFunctionDispatcher(18, L);
  static int _userFunctionCallback19(Pointer<lua_State> L) =>
      _userFunctionDispatcher(19, L);

  /// 用户函数分发器
  static int _userFunctionDispatcher(int callbackIndex, Pointer<lua_State> L) {
    final bindings = LuaRuntime.lua;
    final engine = _currentEngine;
    if (engine == null) return 0;

    try {
      final functionName = _userFunctionNames[callbackIndex];
      if (functionName.isEmpty) {
        engine._output('[ERROR] 回调索引 $callbackIndex 未关联函数名');
        return 0;
      }

      final fn = _engineFunctionRegistry[engine]?[functionName];
      if (fn == null) {
        engine._output('[ERROR] 函数未找到: $functionName');
        return 0;
      }

      final args = <dynamic>[];
      final n = bindings.lua_gettop(L);
      for (var i = 1; i <= n; i++) {
        args.add(_luaToDartValue(bindings, L, i));
      }

      final result = fn(args);
      _pushValue(bindings, L, result);

      return 1;
    } catch (e) {
      engine._output('[ERROR] 用户函数分发器错误 (索引 $callbackIndex): $e');
      return 0;
    }
  }

  /// 将Lua值转换为Dart值
  static dynamic _luaToDartValue(
      LuaBindings bindings, Pointer<lua_State> L, int index) {
    final type = bindings.lua_type(L, index);
    switch (type) {
      case LUA_TNIL:
      case LUA_TNONE:
        return null;
      case LUA_TBOOLEAN:
        return bindings.lua_toboolean(L, index) != 0;
      case LUA_TNUMBER:
        final ptr = bindings.lua_tolstring(L, index, nullptr);
        if (ptr == nullptr) return 0.0;
        final str = ptr.cast<Utf8>().toDartString();
        return double.tryParse(str) ?? 0.0;
      case LUA_TSTRING:
        final ptr = bindings.lua_tolstring(L, index, nullptr);
        if (ptr == nullptr) return '';
        return ptr.cast<Utf8>().toDartString();
      case LUA_TTABLE:
        return _parseTable(bindings, L, index);
      default:
        final ptr = bindings.lua_tolstring(L, index, nullptr);
        if (ptr == nullptr) return '';
        return ptr.cast<Utf8>().toDartString();
    }
  }

  /// 解析Lua表为Dart Map或List
  static dynamic _parseTable(
      LuaBindings bindings, Pointer<lua_State> L, int index) {
    if (index < 0) {
      index = bindings.lua_gettop(L) + index + 1;
    }

    final initialStackTop = bindings.lua_gettop(L);

    try {
      final arrayResult = _parseAsArray(bindings, L, index);
      if (arrayResult != null) {
        _restoreStack(bindings, L, initialStackTop);
        return arrayResult;
      }
    } catch (e) {
      // 数组解析失败，尝试作为Map
    }

    try {
      final mapResult = _parseAsMap(bindings, L, index);
      _restoreStack(bindings, L, initialStackTop);
      return mapResult;
    } catch (e) {
      _restoreStack(bindings, L, initialStackTop);
      return '<table>';
    }
  }

  /// 恢复Lua栈到指定大小
  static void _restoreStack(
      LuaBindings bindings, Pointer<lua_State> L, int targetTop) {
    final currentTop = bindings.lua_gettop(L);
    if (currentTop > targetTop) {
      try {
        bindings.lua_settop(L, targetTop);
      } catch (e) {
        // lua_settop不可用，忽略
      }
    }
  }

  /// 尝试将表解析为数组
  static List<dynamic>? _parseAsArray(
      LuaBindings bindings, Pointer<lua_State> L, int index) {
    final result = <dynamic>[];

    for (var i = 1; ; i++) {
      bindings.lua_rawgeti(L, index, i);
      final type = bindings.lua_type(L, -1);

      if (type == luaTypeNil) {
        _tryPop(bindings, L);
        break;
      }

      final value = _luaToDartValue(bindings, L, -1);
      result.add(value);
      _tryPop(bindings, L);
    }

    if (result.isEmpty) {
      return null;
    }

    return result;
  }

  /// 尝试弹出栈顶元素
  static void _tryPop(LuaBindings bindings, Pointer<lua_State> L) {
    try {
      bindings.lua_settop(L, bindings.lua_gettop(L) - 1);
    } catch (e) {
      // lua_settop不可用，忽略
    }
  }

  /// 将表解析为Map
  static Map<String, dynamic> _parseAsMap(
      LuaBindings bindings, Pointer<lua_State> L, int index) {
    final result = <String, dynamic>{};

    bindings.lua_pushnil(L);
    while (bindings.lua_next(L, index) != 0) {
      final key = _luaToDartValue(bindings, L, -2);
      final value = _luaToDartValue(bindings, L, -1);

      if (key is String) {
        result[key] = value;
      }

      _tryPop(bindings, L);
    }

    return result;
  }

  /// 将Dart值压入Lua栈
  static void _pushValue(LuaBindings bindings, Pointer<lua_State> L, dynamic value) {
    if (value == null) {
      bindings.lua_pushnil(L);
    } else if (value is String) {
      final cstr = value.toNativeUtf8();
      try {
        bindings.lua_pushstring(L, cstr.cast<Char>());
      } finally {
        calloc.free(cstr);
      }
    } else if (value is int || value is double) {
      final str = value.toString();
      final cstr = str.toNativeUtf8();
      try {
        bindings.lua_pushstring(L, cstr.cast<Char>());
      } finally {
        calloc.free(cstr);
      }
    } else if (value is bool) {
      final str = value ? 'true' : 'false';
      final cstr = str.toNativeUtf8();
      try {
        bindings.lua_pushstring(L, cstr.cast<Char>());
      } finally {
        calloc.free(cstr);
      }
    } else {
      final str = value.toString();
      final cstr = str.toNativeUtf8();
      try {
        bindings.lua_pushstring(L, cstr.cast<Char>());
      } finally {
        calloc.free(cstr);
      }
    }
  }
}

/// Lua引擎异常
class LuaEngineException implements Exception {
  const LuaEngineException(this.message);
  final String message;

  @override
  String toString() => 'LuaEngineException: $message';
}

/// Lua类型常量
const int luaTypeNone = -1;
const int luaTypeNil = 0;
const int luaTypeBoolean = 1;
const int luaTypeLightUserdata = 2;
const int luaTypeNumber = 3;
const int luaTypeString = 4;
const int luaTypeTable = 5;
const int luaTypeFunction = 6;
const int luaTypeUserdata = 7;
const int luaTypeThread = 8;

@Deprecated('Use luaTypeNil instead')
const LUA_TNIL = luaTypeNil;
@Deprecated('Use luaTypeBoolean instead')
const LUA_TBOOLEAN = luaTypeBoolean;
@Deprecated('Use luaTypeLightUserdata instead')
const LUA_TLIGHTUSERDATA = luaTypeLightUserdata;
@Deprecated('Use luaTypeNumber instead')
const LUA_TNUMBER = luaTypeNumber;
@Deprecated('Use luaTypeString instead')
const LUA_TSTRING = luaTypeString;
@Deprecated('Use luaTypeTable instead')
const LUA_TTABLE = luaTypeTable;
@Deprecated('Use luaTypeFunction instead')
const LUA_TFUNCTION = luaTypeFunction;
@Deprecated('Use luaTypeUserdata instead')
const LUA_TUSERDATA = luaTypeUserdata;
@Deprecated('Use luaTypeThread instead')
const LUA_TTHREAD = luaTypeThread;
const LUA_TNONE = luaTypeNone;
