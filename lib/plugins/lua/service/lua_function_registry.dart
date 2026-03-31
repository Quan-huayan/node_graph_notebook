import '../../../core/utils/logger.dart';
import 'lua_function_schema.dart';

/// Lua 函数注册表
///
/// 类型安全的 Lua 函数管理系统，防止动态类型导致的安全问题：
/// - 函数签名验证
/// - 参数类型检查
/// - 插件权限控制
/// - 函数所有权追踪
class LuaFunctionRegistry {
  /// 创建函数注册表
  ///
  /// [enableTypeValidation] 是否启用类型验证（默认启用）
  /// [allowOverride] 是否允许插件覆盖其他插件的函数
  LuaFunctionRegistry({
    this.enableTypeValidation = true,
    this.allowOverride = false,
  })  : _functions = {},
        _functionOwners = {};

  /// 是否启用类型验证
  ///
  /// 启用时会验证所有函数调用的参数类型
  final bool enableTypeValidation;

  /// 是否允许覆盖函数
  ///
  /// 禁用时，插件不能覆盖其他插件已注册的函数
  final bool allowOverride;

  /// 已注册的函数
  /// key: function name, value: function schema and handler
  final Map<String, _RegisteredFunction> _functions;

  /// 函数拥有者映射
  /// key: function name, value: plugin ID
  final Map<String, String> _functionOwners;

  /// 注册函数
  ///
  /// [schema] 函数 Schema
  /// [handler] 函数处理程序
  /// [pluginId] 插件 ID（用于权限控制）
  ///
  /// 如果函数已存在且不允许覆盖，抛出 [LuaFunctionRegistrationException]
  void registerFunction(
    LuaFunctionSchema schema,
    dynamic Function(Map<String, dynamic>) handler, {
    required String pluginId,
  }) {
    // 检查函数是否已被注册
    final existing = _functions[schema.name];
    if (existing != null) {
      final existingOwner = _functionOwners[schema.name];

      if (!allowOverride && existingOwner != pluginId) {
        throw LuaFunctionRegistrationException(
          'Function "${schema.name}" is already registered by plugin "$existingOwner". '
          'Cannot override with plugin "$pluginId".',
        );
      }

      const AppLogger('LuaFunctionRegistry').warning(
        'Function "${schema.name}" registered by "$pluginId" '
        'overrides existing registration from "$existingOwner"',
      );
    }

    // 注册函数
    _functions[schema.name] = _RegisteredFunction(
      schema: schema,
      handler: handler,
    );
    _functionOwners[schema.name] = pluginId;

    const AppLogger('LuaFunctionRegistry').info(
      'Registered function: ${schema.signature} by $pluginId',
    );
  }

  /// 批量注册函数
  ///
  /// [functions] 函数列表（schema 和 handler 的对）
  /// [pluginId] 插件 ID
  void registerFunctions(
    List<LuaFunctionRegistryEntry> functions, {
    required String pluginId,
  }) {
    for (final entry in functions) {
      registerFunction(entry.schema, entry.handler, pluginId: pluginId);
    }
  }

  /// 注销函数
  ///
  /// [functionName] 函数名称
  /// [pluginId] 插件 ID（必须匹配函数拥有者）
  ///
  /// 如果插件不拥有该函数，静默忽略
  void unregisterFunction(String functionName, {required String pluginId}) {
    final owner = _functionOwners[functionName];

    if (owner == null) {
      // 函数不存在，静默忽略
      return;
    }

    if (owner != pluginId) {
      const AppLogger('LuaFunctionRegistry').warning(
        'Plugin "$pluginId" attempted to unregister function "$functionName" '
        'owned by "$owner"',
      );
      return;
    }

    _functions.remove(functionName);
    _functionOwners.remove(functionName);

    const AppLogger('LuaFunctionRegistry').info(
      'Unregistered function: $functionName by $pluginId',
    );
  }

  /// 注销插件的所有函数
  ///
  /// [pluginId] 插件 ID
  void unregisterAllByPlugin(String pluginId) {
    final functionsToRemove = _functionOwners.entries
        .where((entry) => entry.value == pluginId)
        .map((entry) => entry.key)
        .toList();

    for (final functionName in functionsToRemove) {
      _functions.remove(functionName);
      _functionOwners.remove(functionName);
    }

    if (functionsToRemove.isNotEmpty) {
      const AppLogger('LuaFunctionRegistry').info(
        'Unregistered ${functionsToRemove.length} functions by plugin $pluginId',
      );
    }
  }

  /// 调用函数
  ///
  /// [functionName] 函数名称
  /// [args] 参数列表（按位置）
  ///
  /// 返回函数执行结果
  ///
  /// 如果函数不存在或参数验证失败，抛出异常
  dynamic callFunction(String functionName, List<dynamic> args) {
    final registered = _functions[functionName];

    if (registered == null) {
      throw LuaFunctionCallException(
        'Function "$functionName" is not registered',
      );
    }

    // 类型验证
    Map<String, dynamic> validatedArgs;
    if (enableTypeValidation) {
      try {
        validatedArgs = registered.schema.validateArguments(args);
      } on LuaFunctionValidationException {
        rethrow;
      } catch (e) {
        throw LuaFunctionCallException(
          'Failed to validate arguments for "$functionName": $e',
        );
      }
    } else {
      // 跳过验证，直接转换参数
      validatedArgs = _skipValidation(args, registered.schema);
    }

    // 调用处理函数
    try {
      return registered.handler(validatedArgs);
    } catch (e) {
      throw LuaFunctionCallException(
        'Error executing function "$functionName": $e',
      );
    }
  }

  /// 跳过验证的参数转换
  ///
  /// 当类型验证禁用时使用
  Map<String, dynamic> _skipValidation(
    List<dynamic> args,
    LuaFunctionSchema schema,
  ) {
    final result = <String, dynamic>{};

    for (var i = 0; i < schema.parameters.length; i++) {
      if (i < args.length) {
        result[schema.parameters[i].name] = args[i];
      } else if (schema.parameters[i].defaultValue != null) {
        result[schema.parameters[i].name] = schema.parameters[i].defaultValue;
      }
    }

    return result;
  }

  /// 检查函数是否存在
  ///
  /// [functionName] 函数名称
  bool hasFunction(String functionName) => _functions.containsKey(functionName);

  /// 获取函数 Schema
  ///
  /// [functionName] 函数名称
  ///
  /// 返回函数 Schema，如果不存在则返回 null
  LuaFunctionSchema? getSchema(String functionName) => _functions[functionName]?.schema;

  /// 获取所有函数名称
  List<String> getFunctionNames() => _functions.keys.toList();

  /// 按分类获取函数
  ///
  /// [category] 分类名称
  List<String> getFunctionsByCategory(String category) => _functions.entries
        .where((entry) => entry.value.schema.category == category)
        .map((entry) => entry.key)
        .toList();

  /// 获取函数拥有者
  ///
  /// [functionName] 函数名称
  ///
  /// 返回插件 ID，如果函数不存在则返回 null
  String? getOwner(String functionName) => _functionOwners[functionName];

  /// 清空所有函数
  ///
  /// 主要用于测试
  void clear() {
    _functions.clear();
    _functionOwners.clear();
  }

  /// 获取已注册的函数数量
  int get functionCount => _functions.length;
}

/// 已注册的函数
class _RegisteredFunction {
  /// 创建已注册的函数
  const _RegisteredFunction({
    required this.schema,
    required this.handler,
  });

  /// 函数 Schema
  final LuaFunctionSchema schema;

  /// 函数处理程序
  final dynamic Function(Map<String, dynamic>) handler;
}

/// Lua 函数注册表条目
///
/// 用于批量注册函数
class LuaFunctionRegistryEntry {
  /// 创建注册表条目
  const LuaFunctionRegistryEntry({
    required this.schema,
    required this.handler,
  });

  /// 函数 Schema
  final LuaFunctionSchema schema;

  /// 函数处理程序
  final dynamic Function(Map<String, dynamic>) handler;
}

/// Lua 函数注册异常
///
/// 函数注册失败时抛出此异常
class LuaFunctionRegistrationException implements Exception {
  /// 创建函数注册异常
  ///
  /// [message] 错误消息
  const LuaFunctionRegistrationException(this.message);

  /// 错误消息
  final String message;

  @override
  String toString() => 'LuaFunctionRegistrationException: $message';
}

/// Lua 函数调用异常
///
/// 函数调用失败时抛出此异常
class LuaFunctionCallException implements Exception {
  /// 创建函数调用异常
  ///
  /// [message] 错误消息
  const LuaFunctionCallException(this.message);

  /// 错误消息
  final String message;

  @override
  String toString() => 'LuaFunctionCallException: $message';
}
