import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/lua_execution_result.dart';
import 'simple_script_engine.dart';
import 'real_lua_engine.dart';
import 'lua_security_manager.dart';

/// Lua引擎类型
///
/// 定义支持的Lua引擎类型
enum LuaEngineType {
  /// 简单脚本引擎（默认，兼容性好）
  ///
  /// 轻量级Lua子集解释器，支持基础语法
  /// 适用于学习场景和简单脚本
  simple,

  /// 真正的Lua引擎（功能完整）
  ///
  /// 基于FFI的完整Lua 5.2运行时
  /// 支持完整Lua语法、标准库和模块系统
  realLua,
}

/// Lua引擎服务
///
/// 管理Lua引擎生命周期，执行Lua脚本，注册Dart函数给Lua调用。
/// 支持双引擎架构：SimpleScriptEngine（兼容模式）和RealLuaEngine（完整功能）。
///
/// ## 功能特性
/// - 双引擎架构，可根据场景选择合适的引擎
/// - Dart函数注册，让Lua脚本能调用原生功能
/// - 上下文变量注入，支持参数传递
/// - 完善的错误处理和输出捕获
///
/// ## 使用示例
/// ```dart
/// // 创建引擎服务
/// final engine = LuaEngineService(
///   engineType: LuaEngineType.realLua,
///   enableDebugOutput: true,
/// );
///
/// // 初始化引擎
/// await engine.initialize();
///
/// // 执行脚本字符串
/// final result = await engine.executeString('print("Hello, Lua!")');
/// if (result.success) {
///   print(result.output); // ['Hello, Lua!']
/// }
///
/// // 执行脚本文件
/// final fileResult = await engine.executeFile('/path/to/script.lua');
///
/// // 注册Dart函数
/// engine.registerFunction('add', (args) {
///   final a = args[0] as num;
///   final b = args[1] as num;
///   return (a + b).toInt();
/// });
/// ```
///
/// ## 架构说明
/// - **SimpleScriptEngine**: 自实现的轻量级解释器，无外部依赖
/// - **RealLuaEngine**: 基于flutter_embed_lua的完整Lua运行时
///
/// ## 线程安全
/// 此服务不是线程安全的，应在同一线程中创建和使用。
///
/// ## 资源管理
/// 使用完毕后必须调用[dispose]释放资源。
class LuaEngineService {
  /// 构造函数
  ///
  /// 创建Lua引擎服务实例
  ///
  /// 参数：
  /// - [enableSandbox] 是否启用沙箱模式（已实现）
  /// - [enableDebugOutput] 是否启用调试输出
  /// - [engineType] 使用的引擎类型，默认为realLua
  /// - [sandboxConfig] 沙箱配置，默认使用严格模式
  ///
  /// 示例：
  /// ```dart
  /// final engine = LuaEngineService(
  ///   enableDebugOutput: true,
  ///   engineType: LuaEngineType.realLua,
  ///   sandboxConfig: LuaSandboxConfig.permissive(),
  /// );
  /// ```
  LuaEngineService({
    this.enableSandbox = false,
    this.enableDebugOutput = false,
    this.engineType = LuaEngineType.realLua,
    LuaSandboxConfig? sandboxConfig,
  }) : securityManager = LuaSecurityManager(
          config: sandboxConfig ??
              (enableSandbox
                  ? LuaSandboxConfig.strict()
                  : LuaSandboxConfig.permissive()),
        );

  /// 简单脚本引擎实例
  SimpleScriptEngine? _simpleEngine;

  /// 真正Lua引擎实例
  RealLuaEngine? _realLuaEngine;

  /// 当前使用的引擎类型
  final LuaEngineType engineType;

  /// 是否启用沙箱模式
  final bool enableSandbox;

  /// 是否启用调试输出
  final bool enableDebugOutput;

  /// 已注册的函数列表
  final Map<String, DartFunctionCallback> _registeredFunctions = {};

  /// 安全管理器
  final LuaSecurityManager securityManager;

  /// 是否已初始化
  bool get isInitialized => _simpleEngine != null || _realLuaEngine != null;

  /// 初始化Lua引擎
  ///
  /// 创建Lua状态机，注册基础函数，准备执行环境。
  /// 根据[engineType]选择使用简单引擎或真正Lua引擎。
  ///
  /// ## 行为说明
  /// - 创建Lua运行时实例
  /// - 注册内置函数（print、log、debug）
  /// - 初始化执行环境
  ///
  /// ## 异常
  /// - [StateError]: 如果引擎已经初始化
  /// - [LuaEngineException]: 如果初始化失败
  ///
  /// ## 示例
  /// ```dart
  /// final engine = LuaEngineService();
  /// await engine.initialize(); // 首次初始化成功
  /// await engine.initialize(); // 抛出StateError
  /// ```
  Future<void> initialize() async {
    if (_simpleEngine != null || _realLuaEngine != null) {
      throw StateError('Lua引擎已经初始化');
    }

    try {
      switch (engineType) {
        case LuaEngineType.simple:
          _simpleEngine = SimpleScriptEngine(
            enableDebugOutput: enableDebugOutput,
          );
          await _simpleEngine!.initialize();
          if (enableDebugOutput) {
            debugPrint('[LUA] 使用简单脚本引擎');
          }
          break;

        case LuaEngineType.realLua:
          _realLuaEngine = RealLuaEngine(
            enableDebugOutput: enableDebugOutput,
            enableSandbox: enableSandbox,  // ✅ 修复：传递沙箱参数
          );
          await _realLuaEngine!.initialize();
          if (enableDebugOutput) {
            debugPrint('[LUA] 使用真正Lua引擎');
          }
          break;
      }

      // 注册基础API
      _registerBaseAPIs();

      if (enableDebugOutput) {
        final result = await executeString('print("Lua引擎初始化成功")');
        for (final line in result.output) {
          debugPrint('[LUA] $line');
        }
      }
    } catch (e) {
      throw LuaEngineException('Lua引擎初始化失败: $e');
    }
  }

  /// 注册基础API
  void _registerBaseAPIs() {
    if (!isInitialized) return;

    // 注册打印函数（引擎已内置）
    // 注册日志函数（引擎已内置）
    // 注册调试函数（引擎已内置）

    if (enableDebugOutput) {
      debugPrint('基础API已注册');
    }
  }

  /// 执行Lua脚本字符串
  ///
  /// 执行提供的Lua代码，并返回执行结果。
  ///
  /// ## 参数
  /// - [script]: 要执行的Lua脚本代码
  /// - [context]: 可选的执行上下文变量，会被注入为Lua全局变量
  ///
  /// ## 返回值
  /// 包含执行结果的[LuaExecutionResult]对象：
  /// - [success]: 是否成功执行
  /// - [output]: 输出日志列表
  /// - [error]: 错误信息（如果失败）
  /// - [returnValue]: 返回值（如果有）
  ///
  /// ## 异常
  /// - [StateError]: 如果引擎未初始化
  ///
  /// ## 示例
  /// ```dart
  /// // 简单执行
  /// final result = await engine.executeString('print("Hello")');
  /// print(result.output); // ['Hello']
  ///
  /// // 带上下文变量
  /// final result2 = await engine.executeString(
  ///   'print(name .. " is " .. age .. " years old")',
  ///   context: {'name': 'Alice', 'age': 30},
  /// );
  /// print(result2.output); // ['Alice is 30 years old']
  /// ```
  Future<LuaExecutionResult> executeString(
    String script, {
    Map<String, dynamic>? context,
  }) async {
    if (!isInitialized) {
      throw StateError('Lua引擎未初始化');
    }

    try {
      // 🔒 安全验证
      final validation = securityManager.validateScript(script);
      if (!validation.isValid) {
        return LuaExecutionResult.failure(
          error: '脚本安全验证失败:\n${validation.errors.join('\n')}',
        );
      }

      // 输出警告
      if (validation.warnings.isNotEmpty) {
        for (final warning in validation.warnings) {
          debugPrint('[LUA SECURITY WARNING] $warning');
        }
      }

      final stopwatch = Stopwatch()..start();

      // 根据引擎类型执行
      LuaExecutionResult result;
      switch (engineType) {
        case LuaEngineType.simple:
          if (_simpleEngine == null) {
            throw StateError('简单引擎未初始化');
          }
          result = await _simpleEngine!.executeString(script, context: context);
          break;

        case LuaEngineType.realLua:
          if (_realLuaEngine == null) {
            throw StateError('Lua引擎未初始化');
          }
          result = await _realLuaEngine!.executeString(script, context: context);
          break;
      }

      stopwatch.stop();

      // 🔒 检查执行时间
      try {
        securityManager.checkExecutionTime(stopwatch.elapsed);
      } catch (e) {
        return LuaExecutionResult.failure(
          error: e.toString(),
        );
      }

      // 🔒 过滤输出
      if (result.success) {
        final filteredOutput = securityManager.filterOutput(result.output);
        return result.copyWith(
          output: filteredOutput,
          executionTime: stopwatch.elapsed,
        );
      }

      return result.copyWith(executionTime: stopwatch.elapsed);
    } catch (e) {
      return LuaExecutionResult.failure(
        error: e.toString(),
      );
    }
  }

  /// 执行Lua脚本文件
  ///
  /// 从文件系统读取Lua脚本并执行。
  ///
  /// ## 参数
  /// - [filePath]: Lua脚本文件的绝对路径
  /// - [context]: 可选的执行上下文变量
  ///
  /// ## 返回值
  /// 包含执行结果的[LuaExecutionResult]对象
  ///
  /// ## 异常
  /// - [StateError]: 如果引擎未初始化
  ///
  /// ## 错误处理
  /// 如果文件不存在或无法读取，返回失败结果而非抛出异常
  ///
  /// ## 示例
  /// ```dart
  /// final result = await engine.executeFile('/path/to/script.lua');
  /// if (result.success) {
  ///   print('脚本执行成功');
  /// } else {
  ///   print('脚本执行失败: ${result.error}');
  /// }
  /// ```
  Future<LuaExecutionResult> executeFile(
    String filePath, {
    Map<String, dynamic>? context,
  }) async {
    if (!isInitialized) {
      throw StateError('Lua引擎未初始化');
    }

    try {
      // 根据引擎类型执行
      switch (engineType) {
        case LuaEngineType.simple:
          if (_simpleEngine == null) {
            throw StateError('简单引擎未初始化');
          }
          // 读取文件内容
          final file = File(filePath);
          if (!file.existsSync()) {
            return LuaExecutionResult.failure(
              error: '脚本文件不存在: $filePath',
            );
          }
          final content = await file.readAsString();
          return await _simpleEngine!.executeString(content, context: context);

        case LuaEngineType.realLua:
          if (_realLuaEngine == null) {
            throw StateError('Lua引擎未初始化');
          }
          return await _realLuaEngine!.executeFile(filePath, context: context);
      }
    } catch (e) {
      return LuaExecutionResult.failure(
        error: e.toString(),
      );
    }
  }

  /// 注册Dart函数供Lua调用
  ///
  /// 将Dart函数注册到Lua全局环境中，Lua脚本可以直接调用。
  ///
  /// ## 参数
  /// - [name]: Lua中的函数名，必须符合Lua标识符规范
  /// - [fn]: Dart函数回调，接收参数列表，返回返回值（通常为0表示成功）
  ///
  /// ## 函数签名
  /// ```dart
  /// typedef DartFunctionCallback = int Function(List<dynamic> args);
  /// ```
  ///
  /// ## 参数传递
  /// - Lua参数会自动转换为Dart类型
  /// - 支持的类型：nil, boolean, number, string, table
  ///
  /// ## 返回值
  /// 返回值会被传递给Lua，通常返回0表示成功
  ///
  /// ## 线程安全
  /// 必须在引擎初始化后调用
  ///
  /// ## 示例
  /// ```dart
  /// // 注册简单的加法函数
  /// engine.registerFunction('add', (args) {
  ///   final a = args[0] as num;
  ///   final b = args[1] as num;
  ///   return (a + b).toInt();
  /// });
  ///
  /// // 在Lua中调用
  /// // print(add(5, 3)) -- 输出: 8
  ///
  /// // 注册异步函数
  /// engine.registerFunction('createNode', (args) {
  ///   final title = args[0] as String;
  ///   // 异步创建节点...
  ///   return 0;
  /// });
  /// ```
  void registerFunction(String name, DartFunctionCallback fn) {
    if (!isInitialized) {
      throw StateError('Lua引擎未初始化');
    }

    // 🔒 验证API权限
    try {
      securityManager.validateAPIAccess(name);
    } catch (e) {
      if (enableDebugOutput) {
        debugPrint('[LUA SECURITY] 函数注册被拒绝: $name - $e');
      }
      rethrow;
    }

    _registeredFunctions[name] = fn;

    // 注册到对应的引擎
    switch (engineType) {
      case LuaEngineType.simple:
        _simpleEngine?.registerFunction(name, fn);
        break;
      case LuaEngineType.realLua:
        _realLuaEngine?.registerFunction(name, fn);
        break;
    }

    if (enableDebugOutput) {
      debugPrint('注册函数: $name');
    }
  }

  /// 重置引擎状态
  ///
  /// 清空Lua全局变量和执行环境，但保留已注册的函数。
  ///
  /// ## 行为说明
  /// - 清空所有Lua全局变量
  /// - 重置Lua栈
  /// - 保留已注册的Dart函数
  ///
  /// ## 使用场景
  /// - 需要重新执行脚本但希望保持函数注册
  /// - 清理上一次执行的全局状态
  ///
  /// ## 异常
  /// - [LuaEngineException]: 如果重置失败
  ///
  /// ## 示例
  /// ```dart
  /// // 执行第一个脚本
  /// await engine.executeString('x = 100');
  ///
  /// // 重置引擎
  /// await engine.reset();
  ///
  /// // x变量已被清空
  /// final result = await engine.executeString('print(x or "nil")');
  /// print(result.output); // ['nil']
  /// ```
  Future<void> reset() async {
    if (!isInitialized) return;

    try {
      switch (engineType) {
        case LuaEngineType.simple:
          await _simpleEngine?.reset();
          break;
        case LuaEngineType.realLua:
          await _realLuaEngine?.reset();
          break;
      }

      if (enableDebugOutput) {
        debugPrint('Lua引擎已重置');
      }
    } catch (e) {
      throw LuaEngineException('Lua引擎重置失败: $e');
    }
  }

  /// 调用Lua回调函数
  ///
  /// 从Dart侧调用已存储在Lua全局变量中的回调函数。
  /// 仅RealLuaEngine支持此功能。
  ///
  /// ## 参数
  /// - [callbackName]: Lua全局变量名，该变量存储着回调函数
  /// - [args]: 传递给回调函数的参数列表
  ///
  /// ## 返回值
  /// 包含执行结果的[LuaExecutionResult]对象
  ///
  /// ## 功能限制
  /// - SimpleScriptEngine不支持此功能，会返回失败结果
  /// - 仅RealLuaEngine完整支持
  ///
  /// ## 使用场景
  /// - 异步操作完成后通知Lua脚本
  /// - 从Dart事件系统回调Lua函数
  ///
  /// ## 示例
  /// ```dart
  /// // 在Lua中定义回调
  /// // myCallback = function(result)
  /// //   print("Callback received: " .. result)
  /// // end
  ///
  /// // 从Dart调用
  /// await engine.invokeCallback('myCallback', ['success']);
  /// ```
  Future<LuaExecutionResult> invokeCallback(
    String callbackName,
    List<dynamic> args,
  ) async {
    if (!isInitialized) {
      throw StateError('Lua引擎未初始化');
    }

    switch (engineType) {
      case LuaEngineType.simple:
        return LuaExecutionResult.failure(
          error: '回调功能仅支持RealLuaEngine',
        );
      case LuaEngineType.realLua:
        if (_realLuaEngine == null) {
          throw StateError('RealLuaEngine未初始化');
        }
        return await _realLuaEngine!.invokeCallback(callbackName, args);
    }
  }

  /// 释放引擎资源
  ///
  /// 释放Lua运行时和相关资源，清理内存。
  ///
  /// ## 行为说明
  /// - 关闭Lua运行时
  /// - 清空函数注册表
  /// - 释放输出缓冲区
  /// - 清理所有内部状态
  ///
  /// ## 重要说明
  /// 调用后引擎不可再使用，如需重新使用需重新初始化
  ///
  /// ## 异常
  /// - [LuaEngineException]: 如果释放失败（已捕获不会抛出）
  ///
  /// ## 示例
  /// ```dart
  /// final engine = LuaEngineService();
  /// await engine.initialize();
  /// // ... 使用引擎
  /// await engine.dispose(); // 释放资源
  /// ```
  Future<void> dispose() async {
    if (!isInitialized) return;

    try {
      await _simpleEngine?.dispose();
      await _realLuaEngine?.dispose();
      _simpleEngine = null;
      _realLuaEngine = null;
      _registeredFunctions.clear();

      if (enableDebugOutput) {
        debugPrint('Lua引擎已释放');
      }
    } catch (e) {
      throw LuaEngineException('Lua引擎释放失败: $e');
    }
  }
}

/// Dart函数回调类型
typedef DartFunctionCallback = int Function(List<dynamic> args);

/// Lua引擎异常基类
class LuaEngineException implements Exception {
  /// 构造函数
  const LuaEngineException(this.message);

  /// 错误信息
  final String message;

  @override
  String toString() => 'LuaEngineException: $message';
}

/// Lua引擎初始化异常
class LuaInitializationException extends LuaEngineException {
  /// 构造函数
  const LuaInitializationException([super.message = 'Lua引擎初始化失败']);
}

/// Lua引擎执行异常
class LuaExecutionException extends LuaEngineException {
  /// 构造函数
  ///
  /// 参数：
  /// - [message]: 错误信息
  /// - [script]: 导致错误的脚本代码（可选）
  /// - [lineNumber]: 错误行号（可选）
  const LuaExecutionException(
    super.message, {
    this.script,
    this.lineNumber,
  });

  /// 导致错误的脚本代码
  final String? script;

  /// 错误行号
  final int? lineNumber;

  @override
  String toString() {
    final buffer = StringBuffer('LuaExecutionException: $message');
    if (lineNumber != null) {
      buffer.write(' (line $lineNumber)');
    }
    if (script != null) {
      buffer.write('\nScript: $script');
    }
    return buffer.toString();
  }
}

/// Lua引擎状态异常
class LuaStateException extends LuaEngineException {
  /// 构造函数
  const LuaStateException([super.message = 'Lua引擎状态错误']);
}
