/// Lua 函数参数 Schema
///
/// 定义 Lua 函数的参数类型和验证规则
class LuaFunctionParameterSchema {
  /// 创建参数 Schema
  ///
  /// [name] 参数名称
  /// [type] 参数类型
  /// [required] 是否必需
  /// [defaultValue] 默认值
  /// [description] 参数描述
  const LuaFunctionParameterSchema({
    required this.name,
    required this.type,
    this.required = true,
    this.defaultValue,
    this.description,
  });

  /// 参数名称
  final String name;

  /// 参数类型
  final LuaType type;

  /// 是否必需
  final bool required;

  /// 默认值
  final dynamic defaultValue;

  /// 参数描述
  final String? description;

  /// 验证参数值
  ///
  /// 返回错误信息，如果验证通过则返回 null
  String? validate(dynamic value) {
    // 检查必需值
    if (required && value == null) {
      return 'Required parameter "$name" is missing';
    }

    // 允许 null 值（如果不是必需的）
    if (value == null) {
      return null;
    }

    // 类型检查
    switch (type) {
      case LuaType.any:
        // 接受任何类型
        break;

      case LuaType.string:
        if (value is! String) {
          return 'Parameter "$name" must be string, got ${value.runtimeType}';
        }
        break;

      case LuaType.number:
        if (value is! num) {
          return 'Parameter "$name" must be number, got ${value.runtimeType}';
        }
        break;

      case LuaType.integer:
        if (value is! int) {
          return 'Parameter "$name" must be integer, got ${value.runtimeType}';
        }
        break;

      case LuaType.boolean:
        if (value is! bool) {
          return 'Parameter "$name" must be boolean, got ${value.runtimeType}';
        }
        break;

      case LuaType.table:
        if (value is! Map) {
          return 'Parameter "$name" must be table (Map), got ${value.runtimeType}';
        }
        break;

      case LuaType.array:
        if (value is! List) {
          return 'Parameter "$name" must be array (List), got ${value.runtimeType}';
        }
        break;

      case LuaType.function:
        if (value is! Function) {
          return 'Parameter "$name" must be function, got ${value.runtimeType}';
        }
        break;
    }

    return null;
  }
}

/// Lua 类型枚举
///
/// 对应 Lua 中的基本类型
enum LuaType {
  /// 任意类型
  any,

  /// 字符串
  string,

  /// 数字（整数或浮点数）
  number,

  /// 整数
  integer,

  /// 布尔值
  boolean,

  /// 表（对象/字典）
  table,

  /// 数组
  array,

  /// 函数
  function,
}

/// Lua 函数 Schema
///
/// 定义 Lua 函数的完整签名和元数据
class LuaFunctionSchema {
  /// 创建函数 Schema
  ///
  /// [name] 函数名称
  /// [parameters] 参数列表
  /// [returnType] 返回值类型
  /// [description] 函数描述
  /// [category] 函数分类
  /// [pluginId] 注册此函数的插件 ID
  const LuaFunctionSchema({
    required this.name,
    this.parameters = const [],
    this.returnType = LuaType.any,
    this.description,
    this.category,
    this.pluginId,
  });

  /// 函数名称
  final String name;

  /// 参数列表
  final List<LuaFunctionParameterSchema> parameters;

  /// 返回值类型
  final LuaType returnType;

  /// 函数描述
  final String? description;

  /// 函数分类（用于组织和查找）
  final String? category;

  /// 插件 ID
  final String? pluginId;

  /// 验证参数列表
  ///
  /// [args] Lua 调用时提供的参数列表（按位置）
  ///
  /// 返回验证后的参数 Map，key 为参数名
  /// 如果验证失败，抛出 [LuaFunctionValidationException]
  Map<String, dynamic> validateArguments(List<dynamic> args) {
    final result = <String, dynamic>{};

    // 检查参数数量
    if (args.length > parameters.length) {
      throw LuaFunctionValidationException(
        'Function "$name" expects at most ${parameters.length} arguments, '
        'but got ${args.length}',
      );
    }

    // 验证每个参数
    for (var i = 0; i < parameters.length; i++) {
      final param = parameters[i];

      // 获取参数值（如果提供了）
      final value = i < args.length ? args[i] : null;

      // 验证参数
      final error = param.validate(value);
      if (error != null) {
        throw LuaFunctionValidationException(
          'Function "$name" parameter ${i + 1} ($name): $error',
        );
      }

      // 使用提供的值或默认值
      if (value != null) {
        result[param.name] = value;
      } else if (param.defaultValue != null) {
        result[param.name] = param.defaultValue;
      } else if (!param.required) {
        // 可选参数没有提供，也没有默认值，设置为 null
        result[param.name] = null;
      }
    }

    return result;
  }

  /// 生成函数签名字符串（用于文档和错误消息）
  String get signature {
    final params = parameters.map((p) {
      final optional = !p.required ? '?' : '';
      final typeStr = p.type == LuaType.any ? 'any' : p.type.name;
      return '$typeStr$optional ${p.name}';
    }).join(', ');

    return '$name($params)';
  }
}

/// Lua 函数验证异常
///
/// 函数参数验证失败时抛出此异常
class LuaFunctionValidationException implements Exception {
  /// 创建函数验证异常
  ///
  /// [message] 错误消息
  const LuaFunctionValidationException(this.message);

  /// 错误消息
  final String message;

  @override
  String toString() => 'LuaFunctionValidationException: $message';
}
