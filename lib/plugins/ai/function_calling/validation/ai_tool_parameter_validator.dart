import '../../../../../core/utils/logger.dart';

/// AI 工具参数验证器
///
/// 防止 AI 提供的恶意参数导致安全问题：
/// - 原型污染攻击 (__proto__, constructor, prototype)
/// - 参数注入攻击
/// - DoS 攻击（超大字符串、深度嵌套）
/// - 类型混淆攻击
///
/// 复用现有的 MetadataValidator 实现参数验证
class AIToolParameterValidator {
  /// 创建参数验证器
  ///
  /// [strictMode] 严格模式：拒绝未知参数
  /// [enableSecurityChecks] 启用安全检查（原型污染等）
  /// [maxStringLength] 最大字符串长度（防止 DoS）
  /// [maxNestingDepth] 最大嵌套深度（防止堆栈溢出）
  const AIToolParameterValidator({
    this.strictMode = false,
    this.enableSecurityChecks = true,
    this.maxStringLength = 100000,
    this.maxNestingDepth = 10,
  });

  /// 是否启用严格模式
  ///
  /// 严格模式下，未知参数会导致验证失败
  final bool strictMode;

  /// 是否启用安全检查
  ///
  /// 启用时会检查原型污染等安全问题
  final bool enableSecurityChecks;

  /// 最大字符串长度
  ///
  /// 防止超大字符串导致 DoS
  final int maxStringLength;

  /// 最大嵌套深度
  ///
  /// 防止深度嵌套导致堆栈溢出
  final int maxNestingDepth;

  /// 危险键名列表
  ///
  /// 这些键名可能导致原型污染攻击
  static const Set<String> dangerousKeys = {
    '__proto__',
    'constructor',
    'prototype',
  };

  /// 验证工具参数
  ///
  /// [toolId] 工具 ID
  /// [arguments] AI 提供的参数
  /// [schema] 工具参数的 JSON Schema
  ///
  /// 抛出 [AIToolParameterValidationException] 如果验证失败
  void validateParameters(
    String toolId,
    Map<String, dynamic> arguments,
    Map<String, dynamic> schema,
  ) {
    // 安全检查：原型污染
    if (enableSecurityChecks) {
      _checkForPrototypePollution(arguments);
    }

    // 安全检查：DoS 防护
    if (enableSecurityChecks) {
      _checkForDoS(arguments);
    }

    // Schema 验证
    final errors = _validateAgainstSchema(arguments, schema);

    if (errors.isNotEmpty) {
      throw AIToolParameterValidationException(
        'Tool "$toolId" parameter validation failed:\n  - ${errors.join('\n  - ')}',
      );
    }

    const AppLogger('AIToolParameterValidator').debug(
      'Tool "$toolId" parameters validated successfully',
    );
  }

  /// 检查原型污染
  ///
  /// 检查参数中是否包含危险键名
  void _checkForPrototypePollution(Map<String, dynamic> arguments) {
    for (final key in arguments.keys) {
      if (dangerousKeys.contains(key)) {
        throw AIToolParameterValidationException(
          'Security violation: dangerous key "$key" detected in parameters. '
          'Prototype pollution attack prevented.',
        );
      }
    }

    // 递归检查嵌套对象
    for (final value in arguments.values) {
      if (value is Map<String, dynamic>) {
        _checkForPrototypePollution(value);
      }
    }
  }

  /// 检查 DoS 攻击
  ///
  /// 检查超大字符串和深度嵌套
  void _checkForDoS(Map<String, dynamic> arguments, [int depth = 0]) {
    // 检查嵌套深度
    if (depth > maxNestingDepth) {
      throw AIToolParameterValidationException(
        'Security violation: maximum nesting depth ($maxNestingDepth) exceeded. '
        'Possible DoS attack prevented.',
      );
    }

    for (final value in arguments.values) {
      if (value is String) {
        // 检查字符串长度
        if (value.length > maxStringLength) {
          throw AIToolParameterValidationException(
            'Security violation: string length (${value.length}) exceeds maximum ($maxStringLength). '
            'Possible DoS attack prevented.',
          );
        }
      } else if (value is Map<String, dynamic>) {
        // 递归检查嵌套对象
        _checkForDoS(value, depth + 1);
      } else if (value is List) {
        // 检查数组元素
        _checkListForDoS(value, depth + 1);
      }
    }
  }

  /// 检查列表中的 DoS 攻击
  void _checkListForDoS(List<dynamic> list, [int depth = 0]) {
    if (depth > maxNestingDepth) {
      throw AIToolParameterValidationException(
        'Security violation: maximum nesting depth ($maxNestingDepth) exceeded. '
        'Possible DoS attack prevented.',
      );
    }

    for (final item in list) {
      if (item is String) {
        if (item.length > maxStringLength) {
          throw AIToolParameterValidationException(
            'Security violation: string length (${item.length}) exceeds maximum ($maxStringLength). '
            'Possible DoS attack prevented.',
          );
        }
      } else if (item is Map<String, dynamic>) {
        _checkForDoS(item, depth + 1);
      } else if (item is List) {
        _checkListForDoS(item, depth + 1);
      }
    }
  }

  /// 根据 Schema 验证参数
  ///
  /// 将 JSON Schema 转换为 MetadataSchema 并验证
  List<String> _validateAgainstSchema(
    Map<String, dynamic> arguments,
    Map<String, dynamic> schema,
  ) {
    final errors = <String>[];

    // 检查 schema 结构
    if (!schema.containsKey('properties')) {
      // 没有 properties 定义，跳过验证
      return errors;
    }

    final propertiesRaw = schema['properties'];
    if (propertiesRaw == null) {
      return errors;
    }

    final properties = propertiesRaw is Map<String, dynamic>
        ? propertiesRaw
        : Map<String, dynamic>.from(propertiesRaw as Map);

    // 获取必需参数列表
    final requiredParams = schema.containsKey('required')
        ? Set<String>.from(schema['required'] as List)
        : <String>{};

    // 检查必需参数
    for (final requiredParam in requiredParams) {
      if (!arguments.containsKey(requiredParam)) {
        errors.add('Missing required parameter: "$requiredParam"');
      }
    }

    // 验证每个参数的类型
    for (final entry in arguments.entries) {
      final paramName = entry.key;
      final paramValue = entry.value;

      // 检查是否为未知参数
      if (!properties.containsKey(paramName)) {
        if (strictMode) {
          errors.add('Unknown parameter: "$paramName"');
        }
        continue;
      }

      // 获取参数的 Schema
      final paramSchema = properties[paramName] as Map<dynamic, dynamic>?;
      if (paramSchema == null) continue;

      final type = paramSchema['type'] as String?;

      // 类型验证
      if (type != null) {
        final typeError = _validateType(
          paramName,
          paramValue,
          type,
          Map<String, dynamic>.from(paramSchema),
        );
        if (typeError != null) {
          errors.add(typeError);
        }
      }
    }

    return errors;
  }

  /// 验证参数类型
  ///
  /// 返回错误信息，如果验证通过则返回 null
  String? _validateType(
    String paramName,
    dynamic value,
    String type,
    Map<String, dynamic> schema,
  ) {
    switch (type) {
      case 'string':
        if (value is! String) {
          return 'Parameter "$paramName" must be string, got ${value.runtimeType}';
        }
        break;

      case 'integer':
        if (value is! int) {
          return 'Parameter "$paramName" must be integer, got ${value.runtimeType}';
        }
        // 检查范围
        if (schema.containsKey('minimum')) {
          final min = schema['minimum'] as num;
          if (value < min) {
            return 'Parameter "$paramName" must be >= $min';
          }
        }
        if (schema.containsKey('maximum')) {
          final max = schema['maximum'] as num;
          if (value > max) {
            return 'Parameter "$paramName" must be <= $max';
          }
        }
        break;

      case 'number':
        if (value is! num) {
          return 'Parameter "$paramName" must be number, got ${value.runtimeType}';
        }
        if (schema.containsKey('minimum')) {
          final min = schema['minimum'] as num;
          if (value < min) {
            return 'Parameter "$paramName" must be >= $min';
          }
        }
        if (schema.containsKey('maximum')) {
          final max = schema['maximum'] as num;
          if (value > max) {
            return 'Parameter "$paramName" must be <= $max';
          }
        }
        break;

      case 'boolean':
        if (value is! bool) {
          return 'Parameter "$paramName" must be boolean, got ${value.runtimeType}';
        }
        break;

      case 'array':
        if (value is! List) {
          return 'Parameter "$paramName" must be array, got ${value.runtimeType}';
        }
        // 检查数组元素类型
        if (schema.containsKey('items')) {
          final itemsSchema = schema['items'] as Map<dynamic, dynamic>?;
          if (itemsSchema == null) break;

          final itemType = itemsSchema['type'] as String?;
          if (itemType != null) {
            for (var i = 0; i < value.length; i++) {
              final itemError = _validateType(
                '$paramName[$i]',
                value[i],
                itemType,
                Map<String, dynamic>.from(itemsSchema),
              );
              if (itemError != null) {
                return itemError;
              }
            }
          }
        }
        break;

      case 'object':
        if (value is! Map<String, dynamic>) {
          return 'Parameter "$paramName" must be object, got ${value.runtimeType}';
        }
        // 递归验证嵌套对象
        if (schema.containsKey('properties')) {
          final nestedErrors = _validateAgainstSchema(
            value,
            Map<String, dynamic>.from(schema),
          );
          if (nestedErrors.isNotEmpty) {
            return nestedErrors.join('; ');
          }
        }
        break;

      default:
        // 未知类型，跳过验证
        break;
    }

    return null;
  }
}

/// AI 工具参数验证异常
///
/// 参数验证失败时抛出此异常
class AIToolParameterValidationException implements Exception {
  /// 创建参数验证异常
  ///
  /// [message] 错误消息
  const AIToolParameterValidationException(this.message);

  /// 错误消息
  final String message;

  @override
  String toString() => 'AIToolParameterValidationException: $message';
}
