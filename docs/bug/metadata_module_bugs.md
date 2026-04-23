# Metadata 模块 Bug 报告

审查范围: `lib/core/metadata/`

---

## Bug #1: `invalid` 工厂构造函数缺少 `const` 关键字

**文件**: [metadata_schema.dart:189](file:///d:/Projects/node_graph_notebook/lib/core/metadata/metadata_schema.dart#L189)

**严重程度**: 中等

**问题描述**:

`MetadataValidationResult.invalid()` 工厂构造函数缺少 `const` 关键字，而 `valid()` 工厂方法使用了 `const`。这导致了不一致的行为。

**问题代码**:

```dart
// 第184行 - 有 const
factory MetadataValidationResult.valid() => const MetadataValidationResult._(isValid: true);

// 第189行 - 缺少 const
factory MetadataValidationResult.invalid(String message) => MetadataValidationResult._(isValid: false, errorMessage: message);
```

**影响**:

1. 无法在编译时创建常量的 `invalid` 结果
2. 与 `valid()` 方法的设计不一致
3. 在需要常量表达式的场景中无法使用 `invalid()`

**建议修复**:

```dart
factory MetadataValidationResult.invalid(String message) => MetadataValidationResult._(isValid: false, errorMessage: message);
```

注意：由于 `errorMessage` 是运行时参数，无法添加 `const`。建议修改类设计，将私有构造函数改为非 const，或者在文档中说明这种不一致的原因。

---

## Bug #2: 验证成功时仍添加结果到列表

**文件**: [metadata_validator.dart:86-88](file:///d:/Projects/node_graph_notebook/lib/core/metadata/metadata_validator.dart#L86-L88)

**严重程度**: 低

**问题描述**:

在 `validate()` 方法中，即使验证成功也会将结果添加到返回列表中。这导致返回的结果列表包含大量无用的 `valid()` 结果。

**问题代码**:

```dart
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
  results.add(result);  // 问题：验证成功也添加结果
}
```

**影响**:

1. 返回的结果列表可能非常大，包含大量 `valid()` 结果
2. 内存浪费
3. 调用者需要额外过滤才能找到真正的错误
4. 违反了"只返回问题"的常见验证模式

**建议修复**:

删除 `else` 分支，只在验证失败时添加结果：

```dart
final result = schema.validate(value);
if (!result.isValid) {
  final contextStr = context != null ? ' (in $context)' : '';
  results.add(
    MetadataValidationResult.invalid(
      'Invalid value for "$key"$contextStr: ${result.errorMessage}',
    ),
  );
}
```

---

## Bug #3: 标准元数据键与 Schema 定义不一致

**文件**: 
- [standard_metadata.dart:96-121](file:///d:/Projects/node_graph_notebook/lib/core/metadata/standard_metadata.dart#L96-L121)
- [metadata_schema.dart:317-331](file:///d:/Projects/node_graph_notebook/lib/core/metadata/metadata_schema.dart#L317-L331)

**严重程度**: 高

**问题描述**:

`StandardMetadata` 类定义了以下标准键：
- `createdAt`
- `updatedAt`
- `accessedAt`
- `version`
- `author`

但是 `StandardSchemas.getAll()` 方法中没有为这些键提供对应的 Schema 定义。

**问题代码**:

`StandardMetadata` 中定义了时间戳和版本控制相关的键：

```dart
// standard_metadata.dart 第96-121行
static const String createdAt = 'createdAt';
static const String updatedAt = 'updatedAt';
static const String accessedAt = 'accessedAt';
static const String version = 'version';
static const String author = 'author';
```

但 `StandardSchemas.getAll()` 只返回了部分 Schema：

```dart
// metadata_schema.dart 第317-331行
static Map<String, MetadataSchema> getAll() => {
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
  // 缺少: createdAt, updatedAt, accessedAt, version, author
};
```

**影响**:

1. 时间戳和版本控制相关的标准键无法被验证
2. `sanitize()` 方法无法为这些键应用默认值
3. 在严格模式或禁用额外键时，这些标准键会被视为"未知键"
4. `isStandardKey()` 返回 `true`，但这些键在验证系统中实际上未注册

**建议修复**:

在 `StandardSchemas` 类中添加缺失的 Schema 定义：

```dart
/// 创建时间 Schema
static const MetadataSchema createdAt = MetadataSchema(
  type: MetadataType.dateTime,
  required: false,
  description: '节点创建时间',
);

/// 更新时间 Schema
static const MetadataSchema updatedAt = MetadataSchema(
  type: MetadataType.dateTime,
  required: false,
  description: '节点最后更新时间',
);

/// 访问时间 Schema
static const MetadataSchema accessedAt = MetadataSchema(
  type: MetadataType.dateTime,
  required: false,
  description: '节点最后访问时间',
);

/// 版本号 Schema
static const MetadataSchema version = MetadataSchema(
  type: MetadataType.string,
  required: false,
  description: '节点版本号',
);

/// 作者 Schema
static const MetadataSchema author = MetadataSchema(
  type: MetadataType.string,
  required: false,
  description: '节点创建者',
);
```

并在 `getAll()` 方法中添加这些 Schema。

---

## 总结

| Bug # | 文件 | 严重程度 | 状态 |
|-------|------|----------|------|
| 1 | metadata_schema.dart | 中等 | 待修复 |
| 2 | metadata_validator.dart | 低 | 待修复 |
| 3 | standard_metadata.dart + metadata_schema.dart | 高 | 待修复 |

**审查日期**: 2026-04-20
