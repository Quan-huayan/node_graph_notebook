// ignore_for_file: public_member_api_docs, unnecessary_string_interpolations

// Vendored from flutter_embed_lua 0.0.1 (MIT, https://pub.dev/packages/flutter_embed_lua).
// 修改（M7 node_lua）：
// 1. DLL 路径探测：环境变量 NGN_LUA54_DLL → 包 assets/ → 系统 "lua54.dll"
//    （原实现只开 "lua54.dll"，测试/应用目录无 dll 即失败）。
// 2. 新增 executeAndReadTop：执行脚本并**读取栈顶返回值**（原 run 只回
//    字符串且不区分错误——"Error:" 前缀被当成功返回，旧 lua_engine 缺陷）。
// 3. run 保留（print 通道），但错误前缀检测上浮到调用方（LuaEngine）。
import 'dart:ffi';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'lua_bindings.dart';

typedef LuaCFunction = Int32 Function(Pointer<lua_State>);
typedef LuaCFunctionDart = int Function(Pointer<lua_State>);

/// 打开 Lua 共享库（M7 修改：多路径探测）。
///
/// 候选序列：NGN_LUA54_DLL 环境变量 → 包 assets（Platform.script 推断
/// 包根）→ cwd 相对包路径（flutter test cwd = workspace 根 →
/// packages/node_lua/assets；直接跑包目录 → assets）→ 系统 "lua54.dll"
/// （应用目录 / System32 / PATH）。
///
/// 应用分发：dll 须放入应用可执行目录或用 NGN_LUA54_DLL 指定。
ffi.DynamicLibrary _openLuaLibrary() {
  if (Platform.isWindows) {
    final env = Platform.environment['NGN_LUA54_DLL'];
    if (env != null && env.isNotEmpty) {
      return ffi.DynamicLibrary.open(env);
    }
    final sep = Platform.pathSeparator;
    // Platform.script 推断包根（Dart VM 脚本在 lib 下时）。
    final vendorDir = File.fromUri(Platform.script).parent.path;
    final pkgRoot = vendorDir.contains('lib${sep}src')
        ? vendorDir.substring(0, vendorDir.indexOf('lib${sep}src'))
        : '';
    final candidates = <String>[
      if (pkgRoot.isNotEmpty) '$pkgRoot${sep}assets${sep}lua54.dll',
      'packages${sep}node_lua${sep}assets${sep}lua54.dll',
      'assets${sep}lua54.dll',
      'lua54.dll',
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return ffi.DynamicLibrary.open(candidate);
      }
    }
    throw const FileSystemException('未找到 lua54.dll（设置 NGN_LUA54_DLL 指定）');
  }
  if (Platform.isAndroid) {
    return ffi.DynamicLibrary.open('liblua.so');
  }
  return ffi.DynamicLibrary.process();
}

/// Lua 运行时（M7 修改：自定义加载 + executeAndReadTop）。
class LuaRuntime {
  /// 构造：加载动态库并初始化 Lua 5.4 状态。
  LuaRuntime() {
    final dylib = _openLuaLibrary();
    lua = LuaBindings(dylib);
    L = lua.luaL_newstate();
    lua.luaL_openlibs(L);
    final printFunc = Pointer.fromFunction<Int32 Function(Pointer<lua_State>)>(
      luaPrint,
      0,
    );
    registerFunction('print', printFunc);
  }

  /// 全局绑定（静态：C 回调需访问）。
  static late LuaBindings lua;

  /// 最近一次 print 输出（run 的字符串通道）。
  static String lastPrintOutput = '';

  /// Lua 状态机。
  late final Pointer<lua_State> L;

  /// 注册 C 函数到 Lua 全局。
  void registerFunction(
    String name,
    Pointer<NativeFunction<Int32 Function(Pointer<lua_State>)>> fn,
  ) {
    lua.lua_pushcclosure(L, fn as lua_CFunction, 0);
    lua.lua_setglobal(L, name.toNativeUtf8().cast());
  }

  /// 执行脚本（字符串通道；语法/运行时错误返回 "Error: ..." 前缀——调用方检测）。
  String run(String code) {
    lastPrintOutput = '';
    final codePtr = code.toNativeUtf8();
    final loadStatus = lua.luaL_loadstring(L, codePtr.cast());
    malloc.free(codePtr);
    if (loadStatus != 0) {
      final err = _stringAt(-1) ?? '<Lua 错误消息不可读>';
      lua.lua_settop(L, -2);
      return 'Error: $err';
    }
    final callStatus = lua.lua_pcallk(L, 0, LUA_MULTRET, 0, 0, nullptr);
    if (callStatus != 0) {
      final err = _stringAt(-1) ?? '<Lua 错误消息不可读>';
      lua.lua_settop(L, -2);
      return 'Error: $err';
    }
    if (lastPrintOutput.isNotEmpty) {
      return lastPrintOutput;
    }
    if (lua.lua_gettop(L) > 0) {
      final resPtr = lua.lua_tolstring(L, -1, nullptr);
      if (resPtr.address != 0) {
        final result = resPtr.cast<Utf8>().toDartString();
        lua.lua_settop(L, -2);
        return result;
      }
    }
    return '';
  }

  /// 执行代码片段并**读取栈顶返回值**（M7 新增）。
  ///
  /// [code] 必须是返回单值的 Lua 表达式/语句（如 `Concept.validate(node)`）；
  /// 错误抛 [LuaValueError]（携带 Lua 错误消息）。
  /// 返回值支持 bool / num / String / List / Map（table 递归解析）。
  dynamic executeAndReadTop(String code) {
    final codePtr = code.toNativeUtf8();
    final loadStatus = lua.luaL_loadstring(L, codePtr.cast());
    malloc.free(codePtr);
    if (loadStatus != 0) {
      // 容错解码（M7）：chunk 名截断可切断多字节 UTF-8。
      final err = _stringAt(-1) ?? '<Lua 错误消息不可读>';
      lua.lua_settop(L, -2);
      throw LuaValueError(err);
    }
    final callStatus = lua.lua_pcallk(L, 0, 1, 0, 0, nullptr);
    if (callStatus != 0) {
      final err = _stringAt(-1) ?? '<Lua 错误消息不可读>';
      lua.lua_settop(L, -2);
      throw LuaValueError(err);
    }
    final value = _readAt(-1);
    lua.lua_settop(L, -2);
    return value;
  }

  /// 递归解析栈顶 table（Map 形态：lua_next 遍历；数组形态由调用方
  /// 按 1..n 连续键提取——M7 命令结果用字符串通道，表仅元数据）。
  ///
  /// 修正记录（M7）：lua_next 后 key 在 -2、value 在 -1——初版先读 -1
  /// 再 settop(-2)，栈被破坏导致 lua_next 死循环（测试挂起）。
  Map<String, dynamic> _readTable() {
    final result = <String, dynamic>{};
    final top = lua.lua_gettop(L);
    lua.lua_pushnil(L);
    while (lua.lua_next(L, top) != 0) {
      final key = _readAt(-2); // lua_next 后：key(-2), value(-1)。
      final value = _readAt(-1);
      lua.lua_settop(L, -2); // 弹出 value + key。
      if (key is String) {
        result[key] = value;
      }
    }
    return result;
  }

  /// 读取指定索引的栈值（不弹出）。
  ///
  /// 修正记录（M7）：number 用 lua_tonumberx——lua_tolstring 会把栈上
  /// number 原地转 string，作为 lua_next 键会触发 "invalid key to 'next'"
  /// panic（表键类型被改）。
  dynamic _readAt(int index) {
    final bindings = LuaRuntime.lua;
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
        return _stringAt(index) ?? '';
      case luaTypeTable:
        return _readTable();
      default:
        return _stringAt(index) ?? '';
    }
  }

  String? _stringAt(int index) {
    final ptr = lua.lua_tolstring(L, index, nullptr);
    if (ptr.address == 0) {
      return null;
    }
    try {
      return ptr.cast<Utf8>().toDartString();
    } on FormatException {
      // 修正记录（M7）：loadstring 错误消息回显源码片段，多字节字符
      // 可能被 Lua 截断 → 无效 UTF-8——解码容错（错误消息非关键路径）。
      return '<Lua 错误消息包含非 UTF-8 字节>';
    }
  }

  /// 释放 Lua 状态。
  void dispose() {
    lua.lua_close(L);
  }
}

/// Lua 值错误（executeAndReadTop 抛；携带 Lua 错误消息）。
class LuaValueError implements Exception {
  /// 构造错误。
  LuaValueError(this.message);

  /// Lua 错误消息。
  final String message;

  @override
  String toString() => 'LuaValueError: $message';
}

// 自定义 print（捕获 Lua print() 输出到 lastPrintOutput）。
int luaPrint(Pointer<lua_State> L) {
  final bindings = LuaRuntime.lua;
  final buffer = StringBuffer();
  final n = bindings.lua_gettop(L);
  final namePtr = 'tostring'.toNativeUtf8().cast<Char>();
  for (var i = 1; i <= n; i++) {
    bindings.lua_getglobal(L, namePtr);
    bindings.lua_pushvalue(L, i);
    bindings.lua_pcallk(L, 1, 1, 0, 0, nullptr);
    final s = bindings.lua_tolstring(L, -1, nullptr);
    if (s.address != 0) {
      buffer.write(s.cast<Utf8>().toDartString());
    } else {
      buffer.write('[nil]');
    }
    bindings.lua_settop(L, -2);
    if (i < n) {
      buffer.write('\t');
    }
  }
  malloc.free(namePtr);
  LuaRuntime.lastPrintOutput = buffer.toString();
  return 0;
}

// Lua 类型常量（vendored 最小集；lua_bindings 内另有 Lua 5.4 常量）。
const int luaTypeNone = -1;
const int luaTypeNil = 0;
const int luaTypeBoolean = 1;
const int luaTypeNumber = 3;
const int luaTypeString = 4;
const int luaTypeTable = 5;
const int luaTypeFunction = 6;
