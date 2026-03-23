# Lua 插件实现原理详解

## 目录
1. [整体架构](#整体架构)
2. [核心技术栈](#核心技术栈)
3. [FFI 集成机制](ffi-集成机制)
4. [双向通信原理](#双向通信原理)
5. [类型转换系统](#类型转换系统)
6. [内存管理](#内存管理)
7. [安全机制](#安全机制)
8. [代码实现详解](#代码实现详解)

---

## 整体架构

### 架构层次图

```
┌─────────────────────────────────────────────────────────────┐
│                    应用层 (Application Layer)                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  UI Pages    │  │   BLoCs      │  │  Commands    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  Lua 插件层 (Lua Plugin Layer)               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            LuaEngineService (统一入口)                │  │
│  │  - executeString()  - executeFile()  - registerFunction()│  │
│  └──────────────────────────────────────────────────────┘  │
│                            ↓                                 │
│  ┌──────────────┐           ┌──────────────┐               │
│  │SimpleScript  │           │ RealLua      │               │
│  │  Engine      │           │  Engine      │               │
│  │ (兼容模式)    │           │  (FFI模式)    │               │
│  └──────────────┘           └──────────────┘               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                API 实现层 (API Implementation Layer)          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          LuaAPIImplementation                          │  │
│  │  - registerNodeAPIs()  - registerMessageAPIs()        │  │
│  │  - registerUtilityAPIs()  - registerCustomAPIs()      │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                FFI 绑定层 (FFI Binding Layer)                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              flutter_embed_lua                         │  │
│  │  - LuaRuntime  - LuaBindings  - lua_State            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│               原生 Lua 库 (Native Lua Library)                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           lua.dll (Windows) / liblua.so (Linux)       │  │
│  │           Lua 5.2 C API                               │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 设计模式

1. **策略模式 (Strategy Pattern)**
   - `LuaEngineType` 枚举定义引擎类型
   - 运行时选择使用 SimpleScriptEngine 或 RealLuaEngine

2. **外观模式 (Facade Pattern)**
   - `LuaEngineService` 提供统一接口
   - 隐藏底层引擎复杂性

3. **注册表模式 (Registry Pattern)**
   - `_engineFunctionRegistry` 管理函数注册
   - `_userFunctionNames` 维护函数名称池

4. **工厂模式 (Factory Pattern)**
   - `_getCallbackPointer()` 根据索引创建回调指针

---

## 核心技术栈

### 1. 依赖包

```yaml
dependencies:
  # Lua FFI 绑定
  flutter_embed_lua: ^0.0.1  # Lua 运行时封装
  ffi: ^2.1.0                # Dart FFI 接口
```

### 2. flutter_embed_lua 包结构

```dart
// 核心类
class LuaRuntime {
  // 创建 Lua 状态机
  LuaRuntime();

  // 注册 C 函数到 Lua
  void registerFunction(
    String name,
    Pointer<NativeFunction<Int32 Function(Pointer<lua_State>)>> function
  );

  // 执行 Lua 代码
  void run(String script);

  // 释放资源
  void dispose();
}

// FFI 绑定
class LuaBindings {
  // Lua C API 函数
  int lua_gettop(Pointer<lua_State> L);
  void lua_pushnil(Pointer<lua_State> L);
  void lua_pushstring(Pointer<lua_State> L, Pointer<Char> s);
  int lua_toboolean(Pointer<lua_State> L, int index);
  // ... 更多 API
}

// Lua 状态机类型
class lua_State extends Opaque {}
```

---

## FFI 集成机制

### 什么是 FFI？

**FFI (Foreign Function Interface)** 是 Dart 提供的机制，允许 Dart 代码调用其他语言（通常是 C）编写的函数。

### FFI 调用流程

```
Dart 代码
    ↓
Pointer<NativeFunction<...>>  // Dart 函数指针
    ↓
dart:ffi  // FFI 库
    ↓
Native Function  // C 函数
    ↓
Lua C Library  // lua.dll
    ↓
Lua State Machine  // Lua 虚拟机
```

### 代码示例：注册 Dart 函数给 Lua

```dart
// 1. 定义 Dart 函数
int _print(Pointer<lua_State> L) {
  final bindings = LuaRuntime.lua;
  final engine = _currentEngine;

  // 2. 从 Lua 栈获取参数
  final n = bindings.lua_gettop(L);
  final parts = <String>[];
  for (var i = 1; i <= n; i++) {
    parts.add(_luaToString(bindings, L, i));
  }

  // 3. 处理逻辑
  engine._output(parts.join('\t'));

  // 4. 返回结果数量
  return 0;
}

// 5. 转换为 C 函数指针
final printPtr = Pointer.fromFunction<
  Int32 Function(Pointer<lua_State>)
>(_print, 0);

// 6. 注册到 Lua
_runtime!.registerFunction('print', printPtr);
```

### Lua 栈操作

Lua 使用栈来传递参数和返回值：

```
Lua 栈结构 (调用 print("Hello", 123))
┌─────────────┐
│   123       │  ← 索引 2 (参数2)
├─────────────┤
│  "Hello"    │  ← 索引 1 (参数1)
├─────────────┤
│   (更多)    │
└─────────────┘
```

```dart
// 获取栈顶元素数量
final n = bindings.lua_gettop(L);  // 返回 2

// 获取指定索引的值
final str = bindings.lua_tolstring(L, 1, nullptr);  // 获取 "Hello"

// 压入返回值
bindings.lua_pushstring(L, cstr);  // 压入字符串到栈

// 返回值数量
return 1;  // 告诉 Lua 有 1 个返回值
```

---

## 双向通信原理

### 1. Dart → Lua (调用 Lua)

```dart
// LuaEngineService.executeString()
Future<LuaExecutionResult> executeString(
  String script,
  {Map<String, dynamic>? context}
) async {
  // 1. 清空输出缓冲区
  _outputBuffer.clear();

  // 2. 设置上下文变量（注入到 Lua 全局环境）
  if (context != null) {
    _setContextVariables(context);
  }

  // 3. 转义并包装脚本
  final escapedScript = script
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll("\n", "\\n");

  // 4. 使用 wrapper 捕获错误
  final wrapper = '''
    local script = "$escapedScript"
    local fn, err = load(script)
    if not fn then
      _execution_error = "Syntax Error: " .. err
    else
      local success, result = pcall(fn)
      if not success then
        _execution_error = "Runtime Error: " .. tostring(result)
      else
        _execution_error = nil
      end
    end
  ''';

  // 5. 执行脚本
  _runtime!.run(wrapper);

  // 6. 检查错误标记
  final errorLine = _outputBuffer.firstWhere(
    (line) => line.startsWith('[ERROR]'),
    orElse: () => '',
  );

  // 7. 返回结果
  if (errorLine.isNotEmpty) {
    return LuaExecutionResult.failure(
      error: errorLine.substring(7),
      output: List.from(_outputBuffer),
    );
  }

  return LuaExecutionResult.success(
    output: List.from(_outputBuffer),
  );
}
```

### 2. Lua → Dart (Lua 调用 Dart)

```lua
-- Lua 脚本
createNode("My Node", "Node Content", "onCreateComplete")

onCreateComplete = function(success, result)
  if success then
    print("节点创建成功: " .. result.id)
  end
end
```

```dart
// Dart 侧实现
void registerFunction(String name, DartFunctionCallback fn) {
  // 1. 获取回调索引
  final callbackIndex = _registeredFunctions.length;

  // 2. 保存函数引用
  _registeredFunctions[name] = fn;
  _userFunctionNames[callbackIndex] = name;

  // 3. 获取对应的 C 回调指针
  final callbackPtr = _getCallbackPointer(callbackIndex);

  // 4. 保存指针防止被 GC
  _functionPointers.add(callbackPtr);

  // 5. 注册到 Lua
  _runtime!.registerFunction(name, callbackPtr);
}

// 用户函数分发器
static int _userFunctionDispatcher(
  int callbackIndex,
  Pointer<lua_State> L
) {
  final bindings = LuaRuntime.lua;
  final engine = _currentEngine;

  try {
    // 1. 获取函数名称
    final functionName = _userFunctionNames[callbackIndex];

    // 2. 获取实际的 Dart 函数
    final fn = _engineFunctionRegistry[engine]?[functionName];

    // 3. 从 Lua 栈提取参数
    final args = <dynamic>[];
    final n = bindings.lua_gettop(L);
    for (var i = 1; i <= n; i++) {
      args.add(_luaToDartValue(bindings, L, i));
    }

    // 4. 调用 Dart 函数
    final result = fn(args);

    // 5. 将返回值压入 Lua 栈
    _pushValue(bindings, L, result);

    // 6. 返回结果数量
    return 1;
  } catch (e) {
    engine._output('[ERROR] 用户函数错误: $e');
    return 0;
  }
}
```

### 3. 回调函数调用 (Dart 调用 Lua 函数)

```dart
// LuaEngineService.invokeCallback()
Future<LuaExecutionResult> invokeCallback(
  String callbackName,
  List<dynamic> args
) async {
  _outputBuffer.clear();

  try {
    // 1. 将 Dart 参数转换为 Lua 字符串
    final argList = args.map((arg) =>
      _valueToLuaString(arg)
    ).join(', ');

    // 2. 构建 Lua 调用脚本
    final script = '''
      if type($callbackName) == "function" then
        local success, result = pcall($callbackName, $argList)
        if not success then
          print("[CALLBACK_ERROR]" .. tostring(result))
        end
      else
        print("[CALLBACK_ERROR] Callback '$callbackName' is not a function")
      end
    ''';

    // 3. 执行调用
    _runtime!.run(script);

    // 4. 检查错误
    final errorLine = _outputBuffer.firstWhere(
      (line) => line.startsWith('[CALLBACK_ERROR]'),
      orElse: () => '',
    );

    if (errorLine.isNotEmpty) {
      return LuaExecutionResult.failure(
        error: errorLine.substring(16),
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
  }
}
```

---

## 类型转换系统

### Lua ↔ Dart 类型映射

| Lua 类型 | Dart 类型 | 转换方法 |
|---------|----------|---------|
| `nil` | `null` | `lua_type() == LUA_TNIL` |
| `boolean` | `bool` | `lua_toboolean()` |
| `number` | `double` | `lua_tolstring()` → `double.tryParse()` |
| `string` | `String` | `lua_tolstring()` → `toDartString()` |
| `table` | `Map<String, dynamic>` 或 `List<dynamic>` | 遍历表结构 |
| `function` | 不支持 | - |
| `userdata` | 不支持 | - |
| `thread` | 不支持 | - |

### 1. Lua → Dart 转换

```dart
/// 将 Lua 值转换为 Dart 值
static dynamic _luaToDartValue(
  LuaBindings bindings,
  Pointer<lua_State> L,
  int index
) {
  // 1. 获取 Lua 类型
  final type = bindings.lua_type(L, index);

  // 2. 根据类型转换
  switch (type) {
    case LUA_TNIL:
    case LUA_TNONE:
      return null;

    case LUA_TBOOLEAN:
      return bindings.lua_toboolean(L, index) != 0;

    case LUA_TNUMBER:
      // Lua 数字都是浮点数
      final ptr = bindings.lua_tolstring(L, index, nullptr);
      if (ptr == nullptr) return 0.0;
      final str = ptr.cast<Utf8>().toDartString();
      return double.tryParse(str) ?? 0.0;

    case LUA_TSTRING:
      final ptr = bindings.lua_tolstring(L, index, nullptr);
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString();

    case LUA_TTABLE:
      // 表需要特殊处理，可能是数组或 Map
      return _parseTable(bindings, L, index);

    default:
      // 其他类型转为字符串
      final ptr = bindings.lua_tolstring(L, index, nullptr);
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString();
  }
}
```

### 2. 表 (Table) 解析

```dart
/// 解析 Lua 表为 Dart Map 或 List
static dynamic _parseTable(
  LuaBindings bindings,
  Pointer<lua_State> L,
  int index
) {
  // 1. 修正索引（负索引是相对栈顶）
  if (index < 0) {
    index = bindings.lua_gettop(L) + index + 1;
  }

  final initialStackTop = bindings.lua_gettop(L);

  try {
    // 2. 尝试解析为数组
    final arrayResult = _parseAsArray(bindings, L, index);
    if (arrayResult != null) {
      _restoreStack(bindings, L, initialStackTop);
      return arrayResult;
    }
  } catch (e) {
    // 数组解析失败，尝试作为 Map
  }

  try {
    // 3. 尝试解析为 Map
    final mapResult = _parseAsMap(bindings, L, index);
    _restoreStack(bindings, L, initialStackTop);
    return mapResult;
  } catch (e) {
    _restoreStack(bindings, L, initialStackTop);
    return '<table>';
  }
}

/// 尝试将表解析为数组
static List<dynamic>? _parseAsArray(
  LuaBindings bindings,
  Pointer<lua_State> L,
  int index
) {
  final result = <dynamic>[];

  // Lua 数组从 1 开始
  for (int i = 1; ; i++) {
    // lua_rawgeti 获取 t[i]
    bindings.lua_rawgeti(L, index, i);
    final type = bindings.lua_type(L, -1);

    if (type == luaTypeNil) {
      _tryPop(bindings, L);
      break;  // 到达数组末尾
    }

    final value = _luaToDartValue(bindings, L, -1);
    result.add(value);
    _tryPop(bindings, L);  // 弹出值
  }

  if (result.isEmpty) {
    return null;
  }

  return result;
}

/// 将表解析为 Map
static Map<String, dynamic> _parseAsMap(
  LuaBindings bindings,
  Pointer<lua_State> L,
  int index
) {
  final result = <String, dynamic>{};

  // lua_next 遍历表
  bindings.lua_pushnil(L);  // 第一个 key
  while (bindings.lua_next(L, index) != 0) {
    // 栈: ... key, value
    final key = _luaToDartValue(bindings, L, -2);
    final value = _luaToDartValue(bindings, L, -1);

    if (key is String) {
      result[key] = value;
    }

    _tryPop(bindings, L);  // 弹出 value，保留 key
  }

  return result;
}
```

### 3. Dart → Lua 转换

```dart
/// 将 Dart 值压入 Lua 栈
static void _pushValue(
  LuaBindings bindings,
  Pointer<lua_State> L,
  dynamic value
) {
  if (value == null) {
    bindings.lua_pushnil(L);
  } else if (value is String) {
    // 转换为 C 字符串
    final cstr = value.toNativeUtf8();
    try {
      bindings.lua_pushstring(L, cstr.cast<Char>());
    } finally {
      calloc.free(cstr);  // 释放内存
    }
  } else if (value is num) {
    // 数字转为字符串再压入
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
    // 其他类型转为字符串
    final str = value.toString();
    final cstr = str.toNativeUtf8();
    try {
      bindings.lua_pushstring(L, cstr.cast<Char>());
    } finally {
      calloc.free(cstr);
    }
  }
}
```

---

## 内存管理

### 1. 指针管理

```dart
class RealLuaEngine {
  // 保存函数指针，防止被垃圾回收
  final List<Pointer<NativeFunction<Int32 Function(Pointer<lua_State>)>>>
    _functionPointers = [];

  void registerFunction(String name, DartFunctionCallback fn) {
    final callbackPtr = _getCallbackPointer(callbackIndex);
    _functionPointers.add(callbackPtr);  // 保存引用
    _runtime!.registerFunction(name, callbackPtr);
  }

  Future<void> dispose() async {
    _runtime?.dispose();
    _runtime = null;
    _functionPointers.clear();  // 清空指针
    _outputBuffer.clear();
    _registeredFunctions.clear();
  }
}
```

### 2. C 字符串内存

```dart
// 错误示例：内存泄漏
bindings.lua_pushstring(L, "Hello".toNativeUtf8());  // 内存泄漏！

// 正确示例：手动释放
final cstr = "Hello".toNativeUtf8();
try {
  bindings.lua_pushstring(L, cstr.cast<Char>());
} finally {
  calloc.free(cstr);  // 确保释放
}
```

### 3. Lua 栈管理

```dart
// 保存栈状态
final initialStackTop = bindings.lua_gettop(L);

try {
  // 操作栈...
  _parseTable(bindings, L, index);
} finally {
  // 恢复栈状态
  _restoreStack(bindings, L, initialStackTop);
}

/// 恢复 Lua 栈到指定大小
static void _restoreStack(
  LuaBindings bindings,
  Pointer<lua_State> L,
  int targetTop
) {
  final currentTop = bindings.lua_gettop(L);
  if (currentTop > targetTop) {
    try {
      bindings.lua_settop(L, targetTop);
    } catch (e) {
      // lua_settop 不可用时忽略
    }
  }
}
```

---

## 安全机制

### 1. 沙箱模式

```dart
void _enableSandbox() {
  if (_runtime == null) return;

  try {
    // 禁用危险 API
    _runtime!.run('''
      os = nil              -- 禁用操作系统 API
      io = nil              -- 禁用文件 I/O
      package = nil         -- 禁用模块系统
      require = nil         -- 禁用 require 函数
      debug = nil           -- 禁用调试库
      load = nil            -- 禁用动态加载
      loadstring = nil      -- 禁用字符串编译
      loadfile = nil        -- 禁用文件加载
      dofile = nil          -- 禁用文件执行
    ''');

    if (enableDebugOutput) {
      _output('安全沙箱已启用：危险API已禁用');
    }
  } catch (e) {
    _output('警告：沙箱启用失败: $e');
  }
}
```

### 2. 输入验证

```dart
class LuaSecurityManager {
  /// 验证脚本安全性
  LuaScriptValidation validateScript(String script) {
    final errors = <String>[];
    final warnings = <String>[];

    // 检查危险操作
    if (config.disableFileOperations) {
      if (script.contains('os.execute') ||
          script.contains('io.open') ||
          script.contains('dofile')) {
        errors.add('禁止文件操作');
      }
    }

    // 检查无限循环风险
    if (config.detectInfiniteLoops) {
      if (_detectInfiniteLoopRisk(script)) {
        warnings.add('可能存在无限循环');
      }
    }

    return LuaScriptValidation(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}
```

### 3. 资源限制

```dart
class LuaSecurityManager {
  /// 检查执行时间
  void checkExecutionTime(Duration elapsed) {
    if (elapsed > config.maxExecutionTime) {
      throw LuaSecurityException(
        '脚本执行超时 (${elapsed.inMilliseconds}ms > ${config.maxExecutionTime.inMilliseconds}ms)'
      );
    }
  }

  /// 过滤输出
  List<String> filterOutput(List<String> output) {
    if (output.length > config.maxOutputLines) {
      final truncated = output.sublist(0, config.maxOutputLines);
      _output('输出被截断: ${output.length} -> ${config.maxOutputLines}');
      return truncated;
    }
    return output;
  }
}
```

---

## 代码实现详解

### 1. 引擎初始化流程

```dart
Future<void> initialize() async {
  // 步骤 1: 检查是否已初始化
  if (_runtime != null) {
    throw StateError('Lua引擎已经初始化');
  }

  try {
    // 步骤 2: 创建 Lua 运行时
    _runtime = LuaRuntime();
    _engineFunctionRegistry[this] = {};

    // 步骤 3: 注册内置函数
    _registerBuiltInFunctions();

    if (enableDebugOutput) {
      _output('真正Lua引擎初始化成功 (Lua 5.2 via FFI)');
    }
  } catch (e) {
    throw LuaEngineException('Lua引擎初始化失败: $e');
  }
}
```

### 2. 脚本执行流程

```dart
Future<LuaExecutionResult> executeString(
  String script,
  {Map<String, dynamic>? context}
) async {
  // 步骤 1: 状态检查
  if (_runtime == null) {
    throw StateError('Lua引擎未初始化');
  }

  _outputBuffer.clear();
  _currentEngine = this;

  try {
    // 步骤 2: 设置上下文变量
    if (context != null) {
      _setContextVariables(context);
    }

    // 步骤 3: 转义脚本
    final escapedScript = _escapeScript(script);

    // 步骤 4: 包装脚本（错误处理）
    final wrapper = _wrapScript(escapedScript);

    // 步骤 5: 执行脚本
    _runtime!.run(wrapper);

    // 步骤 6: 检查错误
    return _checkForErrors();

  } catch (e) {
    return LuaExecutionResult.failure(
      error: e.toString(),
      output: List.from(_outputBuffer),
    );
  } finally {
    _currentEngine = null;
  }
}
```

### 3. 函数注册流程

```dart
void registerFunction(String name, DartFunctionCallback fn) {
  // 步骤 1: 状态检查
  if (_runtime == null) {
    throw StateError('Lua引擎未初始化');
  }

  // 步骤 2: 获取回调索引
  final callbackIndex = _registeredFunctions.length;
  if (callbackIndex >= maxUserFunctions) {
    throw StateError('已达到最大函数数量限制 ($maxUserFunctions)');
  }

  // 步骤 3: 保存函数引用
  _registeredFunctions[name] = fn;
  _engineFunctionRegistry[this]![name] = fn;
  _userFunctionNames[callbackIndex] = name;

  // 步骤 4: 获取 C 函数指针
  final callbackPtr = _getCallbackPointer(callbackIndex);

  // 步骤 5: 保存指针防止 GC
  _functionPointers.add(callbackPtr);

  // 步骤 6: 注册到 Lua
  _runtime!.registerFunction(name, callbackPtr);

  if (enableDebugOutput) {
    _output('注册函数: $name');
  }
}
```

### 4. API 实现流程

```dart
class LuaAPIImplementation {
  void registerAllAPIs() {
    _registerNodeAPIs();
    _registerMessageAPIs();
    _registerUtilityAPIs();
  }

  void _registerNodeAPIs() {
    // createNode API
    engineService.registerFunction('createNode', (args) {
      try {
        // 1. 参数验证
        if (args.isEmpty) {
          throw LuaArgumentException('缺少必需参数');
        }

        final title = _validateString(args[0], 'title');
        final content = args.length > 1
          ? _validateString(args[1], 'content')
          : null;
        final callback = args.length > 2 ? args[2] : null;

        // 2. 创建节点
        final node = Node(
          id: _uuid.v4(),
          title: title!,
          content: content,
          // ... 其他字段
        );

        // 3. 异步保存
        nodeRepository.save(node).then((_) {
          debugPrint('[LUA API] 节点已创建: ${node.id}');

          // 4. 调用回调
          if (callback != null) {
            _invokeCallback(callback, [true, {
              'id': node.id,
              'title': node.title,
            }]);
          }
        }).catchError((e) {
          // 错误处理
          if (callback != null) {
            _invokeCallback(callback, [false, {'error': e.toString()}]);
          }
        });

        return 0;
      } catch (e) {
        _showError("创建节点失败: $e");
        return 0;
      }
    });

    // ... 其他 API
  }
}
```

---

## 实际应用示例

### 示例 1: 创建节点

```lua
-- Lua 脚本
print("开始创建节点...")

onCreateComplete = function(success, result)
  if success then
    print("节点创建成功!")
    print("节点ID: " .. result.id)
    print("节点标题: " .. result.title)
  else
    print("节点创建失败: " .. result.error)
  end
end

createNode("我的节点", "节点内容", "onCreateComplete")
```

```dart
// Dart 侧执行
final result = await engineService.executeString(luaScript);
print(result.output);
// 输出:
// [开始创建节点...]
```

```dart
// 异步回调输出（通过 debugPrint）
// [LUA API] 节点已创建: f6509fde-e302-4115-b9e5-800b48f250a8
// 节点创建成功!
// 节点ID: f6509fde-e302-4115-b9e5-800b48f250a8
// 节点标题: 我的节点
```

### 示例 2: 批量操作

```lua
-- Lua 脚本
getAllNodes("onGetAll")

onGetAll = function(success, result)
  if success then
    print("获取到 " .. result.count .. " 个节点")

    -- 批量重命名
    for i, node in pairs(result.nodes) do
      local newTitle = "Updated " .. node.title
      updateNode(node.id, newTitle, nil, nil)
    end

    print("批量重命名完成")
  end
end
```

### 示例 3: 复杂逻辑

```lua
-- Lua 脚本：根据标签组织节点
local tags = {
  {name = "重要", color = "red"},
  {name = "学习", color = "blue"},
  {name = "待办", color = "green"}
}

for i, tag in pairs(tags) do
  local nodeName = tag.name .. "任务"
  local content = "优先级: " .. tag.color

  createNode(nodeName, content, nil)
  print("创建: " .. nodeName)
end

print("任务组织完成")
```

---

## 性能优化

### 1. 双引擎架构

```dart
enum LuaEngineType {
  simple,    // 简单引擎：快速启动，基础功能
  realLua,   // 真实引擎：完整功能，更好性能
}
```

### 2. 资源复用

```dart
Future<void> reset() async {
  // 重置而非重新创建
  await dispose();
  _runtime = LuaRuntime();
  _registerBuiltInFunctions();
}
```

### 3. 函数缓存

```dart
// 引擎级别的函数注册表
static final Map<RealLuaEngine, Map<String, dynamic Function(List<dynamic>)>>
  _engineFunctionRegistry = {};
```

---

## 总结

Lua 插件的实现是一个**多层架构的复杂系统**，涉及：

1. **FFI 技术**：连接 Dart 和 C/Lua 世界
2. **栈操作**：Lua 和 Dart 之间的数据传递
3. **类型转换**：自动处理不同语言类型系统
4. **内存管理**：指针管理和垃圾回收
5. **安全机制**：沙箱和权限控制
6. **异步处理**：Dart Future 和 Lua 同步模型的协调

这个实现展现了 Flutter/Dart 在系统集成方面的强大能力，为应用提供了灵活的脚本扩展能力。

---

**相关文档**:
- [Lua API 参考手册](./lua_api_reference.md)
- [Lua 插件架构文档](./lua_plugin_architecture.md)
- [深度测试报告](../test/plugins/lua/integration/LUA_DEEP_TEST_REPORT.md)
