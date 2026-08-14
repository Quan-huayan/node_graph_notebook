/// AI 工具参数验证器（M7.3，archive/ai 资产原样带走）——防 AI 恶意
/// 参数：原型污染（__proto__/constructor/prototype）、参数注入、
/// DoS（超大字符串/深度嵌套）、类型混淆。
library;

/// 参数验证失败异常。
class AIToolParameterValidationException implements Exception {
  /// 构造异常。
  const AIToolParameterValidationException(this.message);

  /// 错误消息。
  final String message;

  @override
  String toString() => 'AIToolParameterValidationException: $message';
}

/// AI 工具参数验证器。
class AIToolParameterValidator {
  /// 配置安全阈值。
  const AIToolParameterValidator({
    this.strictMode = false,
    this.enableSecurityChecks = true,
    this.maxStringLength = 100000,
    this.maxNestingDepth = 10,
  });

  /// 严格模式：未知参数拒绝。
  final bool strictMode;

  /// 安全检查（原型污染/DoS）。
  final bool enableSecurityChecks;

  /// 最大字符串长度（DoS 防护）。
  final int maxStringLength;

  /// 最大嵌套深度（堆栈溢出防护）。
  final int maxNestingDepth;

  /// 危险键（原型污染）。
  static const Set<String> dangerousKeys = <String>{
    '__proto__',
    'constructor',
    'prototype',
  };

  /// 验证参数（失败抛 [AIToolParameterValidationException]）。
  void validateParameters(
    String toolId,
    Map<String, dynamic> arguments,
    Map<String, dynamic> schema,
  ) {
    if (enableSecurityChecks) {
      _checkForPrototypePollution(arguments);
      _checkForDoS(arguments);
    }
    final errors = _validateAgainstSchema(arguments, schema);
    if (errors.isNotEmpty) {
      throw AIToolParameterValidationException(
        'Tool "$toolId" parameter validation failed:\n  - ${errors.join('\n  - ')}',
      );
    }
  }

  void _checkForPrototypePollution(Map<String, dynamic> arguments) {
    for (final key in arguments.keys) {
      if (dangerousKeys.contains(key)) {
        throw AIToolParameterValidationException(
          'Security violation: dangerous key "$key" detected in parameters. '
          'Prototype pollution attack prevented.',
        );
      }
    }
    for (final value in arguments.values) {
      if (value is Map<String, dynamic>) {
        _checkForPrototypePollution(value);
      }
    }
  }

  void _checkForDoS(Map<String, dynamic> arguments, [int depth = 0]) {
    if (depth > maxNestingDepth) {
      throw AIToolParameterValidationException(
        'Security violation: maximum nesting depth ($maxNestingDepth) exceeded. '
        'Possible DoS attack prevented.',
      );
    }
    for (final value in arguments.values) {
      if (value is String) {
        if (value.length > maxStringLength) {
          throw AIToolParameterValidationException(
            'Security violation: string length (${value.length}) exceeds maximum ($maxStringLength). '
            'Possible DoS attack prevented.',
          );
        }
      } else if (value is Map<String, dynamic>) {
        _checkForDoS(value, depth + 1);
      } else if (value is List) {
        _checkListForDoS(value, depth + 1);
      }
    }
  }

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

  List<String> _validateAgainstSchema(
    Map<String, dynamic> arguments,
    Map<String, dynamic> schema,
  ) {
    final errors = <String>[];
    final propertiesRaw = schema['properties'];
    if (propertiesRaw is! Map) {
      return errors; // 无 properties 定义 → 跳过。
    }
    final properties = Map<String, dynamic>.from(propertiesRaw);
    final requiredParams = schema['required'] is List
        ? Set<String>.from(schema['required'] as List)
        : <String>{};
    for (final requiredParam in requiredParams) {
      if (!arguments.containsKey(requiredParam)) {
        errors.add('Missing required parameter: "$requiredParam"');
      }
    }
    for (final entry in arguments.entries) {
      final paramName = entry.key;
      final paramValue = entry.value;
      final paramSchemaRaw = properties[paramName];
      if (paramSchemaRaw == null) {
        if (strictMode) {
          errors.add('Unknown parameter: "$paramName"');
        }
        continue;
      }
      final paramSchema = paramSchemaRaw is Map
          ? Map<String, dynamic>.from(paramSchemaRaw)
          : <String, dynamic>{};
      final type = paramSchema['type'] as String?;
      if (type != null) {
        final typeError = _validateType(
          paramName,
          paramValue,
          type,
          paramSchema,
        );
        if (typeError != null) {
          errors.add(typeError);
        }
      }
    }
    return errors;
  }

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
      case 'integer':
        if (value is! int) {
          return 'Parameter "$paramName" must be integer, got ${value.runtimeType}';
        }
        if (schema['minimum'] is num && value < (schema['minimum'] as num)) {
          return 'Parameter "$paramName" must be >= ${schema['minimum']}';
        }
        if (schema['maximum'] is num && value > (schema['maximum'] as num)) {
          return 'Parameter "$paramName" must be <= ${schema['maximum']}';
        }
      case 'number':
        if (value is! num) {
          return 'Parameter "$paramName" must be number, got ${value.runtimeType}';
        }
        if (schema['minimum'] is num && value < (schema['minimum'] as num)) {
          return 'Parameter "$paramName" must be >= ${schema['minimum']}';
        }
        if (schema['maximum'] is num && value > (schema['maximum'] as num)) {
          return 'Parameter "$paramName" must be <= ${schema['maximum']}';
        }
      case 'boolean':
        if (value is! bool) {
          return 'Parameter "$paramName" must be boolean, got ${value.runtimeType}';
        }
      case 'array':
        if (value is! List) {
          return 'Parameter "$paramName" must be array, got ${value.runtimeType}';
        }
        final itemsSchemaRaw = schema['items'];
        if (itemsSchemaRaw is Map) {
          final itemsSchema = Map<String, dynamic>.from(itemsSchemaRaw);
          final itemType = itemsSchema['type'] as String?;
          if (itemType != null) {
            for (var i = 0; i < value.length; i++) {
              final itemError = _validateType(
                '$paramName[$i]',
                value[i],
                itemType,
                itemsSchema,
              );
              if (itemError != null) {
                return itemError;
              }
            }
          }
        }
      case 'object':
        if (value is! Map<String, dynamic>) {
          return 'Parameter "$paramName" must be object, got ${value.runtimeType}';
        }
        if (schema.containsKey('properties')) {
          final nestedErrors = _validateAgainstSchema(
            value,
            Map<String, dynamic>.from(schema),
          );
          if (nestedErrors.isNotEmpty) {
            return nestedErrors.join('; ');
          }
        }
      default:
        break;
    }
    return null;
  }
}
