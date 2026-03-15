import 'standard_metadata.dart';

/// 元数据 Schema 定义
///
/// 定义元数据值的类型和验证规则
class MetadataSchema {
  const MetadataSchema({
    required this.type,
    this.required = false,
    this.defaultValue,
    this.allowedValues,
    this.minValue,
    this.maxValue,
    this.description,
  });

  /// 元数据值类型
  final MetadataType type;

  /// 是否必需
  final bool required;

  /// 默认值
  final dynamic defaultValue;

  /// 允许的值列表（用于枚举类型）
  final List<dynamic>? allowedValues;

  /// 最小值（用于数字类型）
  final num? minValue;

  /// 最大值（用于数字类型）
  final num? maxValue;

  /// 描述信息
  final String? description;

  /// 验证值是否符合 Schema
  ///
  /// 返回验证结果，包含是否有效和错误信息
  MetadataValidationResult validate(dynamic value) {
    // 检查必需值
    if (required && value == null) {
      return MetadataValidationResult.invalid('Required value is missing');
    }

    // 允许 null 值（如果不是必需的）
    if (value == null) {
      return MetadataValidationResult.valid();
    }

    // 类型检查
    switch (type) {
      case MetadataType.string:
        if (value is! String) {
          return MetadataValidationResult.invalid('Expected String, got ${value.runtimeType}');
        }
        break;

      case MetadataType.bool:
        if (value is! bool) {
          return MetadataValidationResult.invalid('Expected bool, got ${value.runtimeType}');
        }
        break;

      case MetadataType.int:
        if (value is! int) {
          return MetadataValidationResult.invalid('Expected int, got ${value.runtimeType}');
        }
        if (minValue != null && value < minValue!) {
          return MetadataValidationResult.invalid('Value must be >= $minValue');
        }
        if (maxValue != null && value > maxValue!) {
          return MetadataValidationResult.invalid('Value must be <= $maxValue');
        }
        break;

      case MetadataType.double:
        if (value is! double && value is! int) {
          return MetadataValidationResult.invalid('Expected double, got ${value.runtimeType}');
        }
        final numValue = value is double ? value : (value as int).toDouble();
        if (minValue != null && numValue < minValue!) {
          return MetadataValidationResult.invalid('Value must be >= $minValue');
        }
        if (maxValue != null && numValue > maxValue!) {
          return MetadataValidationResult.invalid('Value must be <= $maxValue');
        }
        break;

      case MetadataType.stringList:
        if (value is! List) {
          return MetadataValidationResult.invalid('Expected List, got ${value.runtimeType}');
        }
        if (value.any((e) => e is! String)) {
          return MetadataValidationResult.invalid('List must contain only Strings');
        }
        break;

      case MetadataType.map:
        if (value is! Map) {
          return MetadataValidationResult.invalid('Expected Map, got ${value.runtimeType}');
        }
        break;

      case MetadataType.dateTime:
        if (value is! String && value is! DateTime) {
          return MetadataValidationResult.invalid('Expected DateTime or String, got ${value.runtimeType}');
        }
        break;
    }

    // 允许值检查
    if (allowedValues != null && !allowedValues!.contains(value)) {
      return MetadataValidationResult.invalid(
        'Value must be one of: ${allowedValues!.join(', ')}',
      );
    }

    return MetadataValidationResult.valid();
  }
}

/// 元数据值类型
enum MetadataType {
  /// 字符串
  string,

  /// 布尔值
  bool,

  /// 整数
  int,

  /// 浮点数
  double,

  /// 字符串列表
  stringList,

  /// Map（键值对）
  map,

  /// 日期时间
  dateTime,
}

/// 元数据验证结果
class MetadataValidationResult {
  const MetadataValidationResult._({
    required this.isValid,
    this.errorMessage,
  });

  /// 创建有效结果
  factory MetadataValidationResult.valid() {
    return const MetadataValidationResult._(isValid: true);
  }

  /// 创建无效结果
  factory MetadataValidationResult.invalid(String message) {
    return MetadataValidationResult._(
      isValid: false,
      errorMessage: message,
    );
  }

  /// 是否有效
  final bool isValid;

  /// 错误信息（无效时）
  final String? errorMessage;

  @override
  String toString() {
    if (isValid) return 'Valid';
    return 'Invalid: $errorMessage';
  }
}

/// 预定义的标准 Schema
///
/// 包含所有标准元数据键的 Schema 定义
class StandardSchemas {
  // 私有构造函数
  StandardSchemas._();

  /// 节点类型 Schema
  ///
  /// 节点类型由插件自由定义，不限制标准值
  static const MetadataSchema nodeType = MetadataSchema(
    type: MetadataType.string,
    required: false,
    description: '节点类型（由插件自由定义）',
  );

  /// 文件夹标记 Schema
  static const MetadataSchema isFolder = MetadataSchema(
    type: MetadataType.bool,
    required: false,
    defaultValue: false,
    description: '是否为文件夹节点',
  );

  /// AI 生成标记 Schema
  static const MetadataSchema isAI = MetadataSchema(
    type: MetadataType.bool,
    required: false,
    defaultValue: false,
    description: '是否由 AI 生成',
  );

  /// 图标 Schema
  static const MetadataSchema icon = MetadataSchema(
    type: MetadataType.string,
    required: false,
    description: '节点图标标识',
  );

  /// 颜色 Schema
  static const MetadataSchema color = MetadataSchema(
    type: MetadataType.string,
    required: false,
    description: '节点颜色（十六进制或命名颜色）',
  );

  /// 展开状态 Schema
  static const MetadataSchema expanded = MetadataSchema(
    type: MetadataType.bool,
    required: false,
    defaultValue: true,
    description: '文件夹节点的展开状态',
  );

  /// 可见性 Schema
  static const MetadataSchema visible = MetadataSchema(
    type: MetadataType.bool,
    required: false,
    defaultValue: true,
    description: '节点是否可见',
  );

  /// 锁定状态 Schema
  static const MetadataSchema locked = MetadataSchema(
    type: MetadataType.bool,
    required: false,
    defaultValue: false,
    description: '节点是否被锁定',
  );

  /// 摘要 Schema
  static const MetadataSchema summary = MetadataSchema(
    type: MetadataType.string,
    required: false,
    description: '节点内容摘要',
  );

  /// 标签列表 Schema
  static const MetadataSchema tags = MetadataSchema(
    type: MetadataType.stringList,
    required: false,
    defaultValue: [],
    description: '节点标签列表',
  );

  /// 优先级 Schema
  static const MetadataSchema priority = MetadataSchema(
    type: MetadataType.int,
    required: false,
    defaultValue: Priorities.normal,
    minValue: Priorities.lowest,
    maxValue: Priorities.highest,
    description: '节点优先级（0-10）',
  );

  /// AI 分数 Schema
  static const MetadataSchema aiScore = MetadataSchema(
    type: MetadataType.double,
    required: false,
    minValue: 0.0,
    maxValue: 1.0,
    description: 'AI 分析置信度分数（0.0-1.0）',
  );

  /// AI 分析结果 Schema
  static const MetadataSchema aiAnalysis = MetadataSchema(
    type: MetadataType.map,
    required: false,
    description: 'AI 分析详细结果',
  );

  /// 获取所有标准 Schema 的映射
  static Map<String, MetadataSchema> getAll() {
    return {
      StandardMetadata.nodeType: nodeType,
      StandardMetadata.isFolder: isFolder,
      StandardMetadata.isAI: isAI,
      StandardMetadata.icon: icon,
      StandardMetadata.color: color,
      StandardMetadata.expanded: expanded,
      StandardMetadata.visible: visible,
      StandardMetadata.locked: locked,
      StandardMetadata.summary: summary,
      StandardMetadata.tags: tags,
      StandardMetadata.priority: priority,
      StandardMetadata.aiScore: aiScore,
      StandardMetadata.aiAnalysis: aiAnalysis,
    };
  }
}
