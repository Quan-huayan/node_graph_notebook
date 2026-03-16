import 'metadata_schema.dart';
import 'standard_metadata.dart';

/// 元数据验证器
///
/// 提供元数据验证功能，支持标准元数据和插件自定义元数据
class MetadataValidator {
  /// 创建验证器
  ///
  /// [strictMode] 严格模式：未知键会导致验证失败
  /// [allowExtraKeys] 是否允许未注册的额外键
  MetadataValidator({this.strictMode = false, this.allowExtraKeys = true});

  /// 是否启用严格模式
  final bool strictMode;

  /// 是否允许额外的未注册键
  final bool allowExtraKeys;

  /// 注册的自定义 Schema
  final Map<String, MetadataSchema> _customSchemas = {};

  /// 注册自定义 Schema
  ///
  /// [key] 元数据键
  /// [schema] Schema 定义
  void registerSchema(String key, MetadataSchema schema) {
    _customSchemas[key] = schema;
  }

  /// 批量注册 Schema
  ///
  /// [schemas] Schema 映射
  void registerSchemas(Map<String, MetadataSchema> schemas) {
    _customSchemas.addAll(schemas);
  }

  /// 验证元数据 Map
  ///
  /// [metadata] 要验证的元数据
  /// [context] 可选的上下文信息（用于错误消息）
  ///
  /// 返回验证结果列表
  List<MetadataValidationResult> validate(
    Map<String, dynamic> metadata, {
    String? context,
  }) {
    final results = <MetadataValidationResult>[];
    final standardSchemas = StandardSchemas.getAll();
    final allSchemas = {...standardSchemas, ..._customSchemas};

    // 验证每个键值对
    for (final entry in metadata.entries) {
      final key = entry.key;
      final value = entry.value;

      // 跳过插件元数据（在非严格模式下）
      if (StandardMetadata.isPluginKey(key) && !strictMode) {
        continue;
      }

      // 获取 Schema
      final schema = allSchemas[key];

      if (schema == null) {
        // 未找到 Schema
        if (!allowExtraKeys && !StandardMetadata.isPluginKey(key)) {
          results.add(
            MetadataValidationResult.invalid(
              'Unknown metadata key: $key${context != null ? ' (in $context)' : ''}',
            ),
          );
        }
        continue;
      }

      // 验证值
      final result = schema.validate(value);
      if (!result.isValid) {
        final contextStr = context != null ? ' (in $context)' : '';
        results.add(
          MetadataValidationResult.invalid(
            'Invalid value for "$key"$contextStr: ${result.errorMessage}',
          ),
        );
      } else {
        results.add(result);
      }
    }

    // 检查必需的值
    for (final entry in allSchemas.entries) {
      if (entry.value.required && !metadata.containsKey(entry.key)) {
        results.add(
          MetadataValidationResult.invalid(
            'Missing required metadata key: ${entry.key}${context != null ? ' (in $context)' : ''}',
          ),
        );
      }
    }

    return results;
  }

  /// 验证单个元数据值
  ///
  /// [key] 元数据键
  /// [value] 元数据值
  ///
  /// 返回验证结果
  MetadataValidationResult validateValue(String key, dynamic value) {
    final standardSchemas = StandardSchemas.getAll();
    final schema = _customSchemas[key] ?? standardSchemas[key];

    if (schema == null) {
      if (!allowExtraKeys && !StandardMetadata.isPluginKey(key)) {
        return MetadataValidationResult.invalid('Unknown metadata key: $key');
      }
      return MetadataValidationResult.valid();
    }

    return schema.validate(value);
  }

  /// 验证 NodeReference 的 properties
  ///
  /// [properties] NodeReference 的 properties Map
  /// [context] 可选的上下文信息
  ///
  /// 返回验证结果列表
  List<MetadataValidationResult> validateReferenceProperties(
    Map<String, dynamic> properties, {
    String? context,
  }) {
    // 引用的 properties 可以包含任意内容
    // 插件可以自由定义引用属性
    final results = <MetadataValidationResult>[];

    // 验证其他属性（如果有注册的 Schema）
    for (final entry in properties.entries) {
      final key = entry.key;

      final value = entry.value;
      final schema = _customSchemas['reference.$key'];

      if (schema != null) {
        final result = schema.validate(value);
        if (!result.isValid) {
          results.add(
            MetadataValidationResult.invalid(
              'Invalid reference property "$key"${context != null ? ' (in $context)' : ''}: ${result.errorMessage}',
            ),
          );
        }
      }
    }

    return results;
  }

  /// 检查元数据是否全部有效
  ///
  /// [metadata] 要验证的元数据
  ///
  /// 返回 true 如果所有元数据都有效
  bool isValid(Map<String, dynamic> metadata) {
    final results = validate(metadata);
    return results.every((r) => r.isValid);
  }

  /// 获取验证失败的错误信息
  ///
  /// [metadata] 要验证的元数据
  ///
  /// 返回错误信息列表
  List<String> getErrors(Map<String, dynamic> metadata) {
    final results = validate(metadata);
    return results
        .where((r) => !r.isValid)
        .map((r) => r.errorMessage ?? 'Unknown error')
        .toList();
  }

  /// 清理和规范化元数据
  ///
  /// 应用默认值并移除无效值
  ///
  /// [metadata] 要清理的元数据
  ///
  /// 返回清理后的元数据 Map
  Map<String, dynamic> sanitize(Map<String, dynamic> metadata) {
    final result = <String, dynamic>{};
    final standardSchemas = StandardSchemas.getAll();
    final allSchemas = {...standardSchemas, ..._customSchemas};

    for (final entry in metadata.entries) {
      final key = entry.key;
      final value = entry.value;
      final schema = allSchemas[key];

      if (schema != null) {
        // 验证值
        final validationResult = schema.validate(value);
        if (validationResult.isValid) {
          result[key] = value;
        } else if (schema.defaultValue != null) {
          // 值无效，使用默认值
          result[key] = schema.defaultValue;
        }
      } else if (allowExtraKeys || StandardMetadata.isPluginKey(key)) {
        // 保留未注册的键（如果允许）
        result[key] = value;
      }
    }

    // 添加缺失的默认值
    for (final entry in allSchemas.entries) {
      if (!result.containsKey(entry.key) && entry.value.defaultValue != null) {
        result[entry.key] = entry.value.defaultValue;
      }
    }

    return result;
  }
}

/// 元数据验证异常
class MetadataValidationException implements Exception {
  /// 创建元数据验证异常
  ///
  /// [errors] 错误列表
  MetadataValidationException(this.errors);

  /// 错误列表
  final List<String> errors;

  /// 转换为字符串表示
  @override
  String toString() {
    if (errors.isEmpty) return 'Metadata validation failed';
    if (errors.length == 1) return 'Metadata validation error: ${errors[0]}';
    return 'Metadata validation errors:\n  - ${errors.join('\n  - ')}';
  }
}
