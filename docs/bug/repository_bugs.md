# Repository 层 Bug 报告

审查日期：2026-04-20
审查范围：`lib/core/repositories` 文件夹

---

## Bug 1: 异步操作缺少 await 关键字

**文件**: [node_repository.dart](file:///d:/Projects/node_graph_notebook/lib/core/repositories/node_repository.dart#L169)

**严重程度**: 高

**问题描述**:
在 `save` 方法中，`_adjacencyList!.save()` 调用缺少 `await` 关键字，而其他地方（如第146行、第196行）都正确使用了 `await`。

**问题代码**:
```dart
// 第169行
_adjacencyList!.save();  // 缺少 await
```

**正确代码参考** (第196行):
```dart
await _adjacencyList!.save();
```

**影响**:
- 异步操作可能在完成前就返回，导致数据未正确保存
- 邻接表状态可能不一致
- 在应用关闭或崩溃时可能丢失数据

**建议修复**:
```dart
await _adjacencyList!.save();
```

---

## Bug 2: 数组索引不匹配

**文件**: [node_repository.dart](file:///d:/Projects/node_graph_notebook/lib/core/repositories/node_repository.dart#L524)

**严重程度**: 高

**问题描述**:
在 `_parseContentAndTitle` 方法中，循环使用 `trimmedContentLines.length` 作为边界，但内部访问的是 `contentLines[i]`，这两个数组的长度可能不同，导致索引越界或访问错误的数据。

**问题代码**:
```dart
// 第522-524行
for (var i = 0; i < trimmedContentLines.length; i++) {
  final line = contentLines[i];  // 错误：应该使用 trimmedContentLines[i]
  final trimmed = line.trim();
```

**影响**:
- 当 `contentLines` 和 `trimmedContentLines` 长度不同时，可能抛出 `RangeError`
- 可能读取到错误的内容行，导致标题解析错误

**建议修复**:
```dart
for (var i = 0; i < trimmedContentLines.length; i++) {
  final line = trimmedContentLines[i];  // 使用正确的数组
  final trimmed = line.trim();
```

---

## Bug 3: 不安全的类型转换

**文件**: [node_repository.dart](file:///d:/Projects/node_graph_notebook/lib/core/repositories/node_repository.dart#L571)

**严重程度**: 中

**问题描述**:
在 `_parseReferences` 方法中，直接将 `frontmatter['references']` 强制转换为 `Map<String, dynamic>`，没有进行类型检查。如果YAML文件格式错误，会导致运行时异常。

**问题代码**:
```dart
// 第571行
(frontmatter['references'] as Map<String, dynamic>).forEach((key, value) {
```

**影响**:
- 如果 `references` 字段格式不正确（如为null、字符串、列表等），会抛出 `TypeError`
- 损坏的节点文件会导致整个节点无法加载

**建议修复**:
```dart
final refsData = frontmatter['references'];
if (refsData is! Map<String, dynamic>) {
  _log.warning('Invalid references format in node, skipping references');
  return references;
}

refsData.forEach((key, value) {
```

---

## Bug 4: JSON 序列化不一致

**文件**: [metadata_index.dart](file:///d:/Projects/node_graph_notebook/lib/core/repositories/metadata_index.dart#L109-L118)

**严重程度**: 中

**问题描述**:
`NodeMetadata` 类使用了 `@JsonSerializable()` 注解，但同时手动实现了 `toJson()` 方法。这可能导致序列化行为不一致，且如果将来修改字段时容易遗漏更新。

**问题代码**:
```dart
@JsonSerializable()
class NodeMetadata {
  // ...
  
  // 手动实现的 toJson，与注解生成的不一致
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    // ...
  };
}
```

**影响**:
- 如果存在生成的 `_$NodeMetadataToJson` 方法，可能导致混淆
- 手动维护容易出错，且与 `fromJson` 使用生成代码的方式不一致

**建议修复**:
方案一（推荐）：使用生成的代码
```dart
Map<String, dynamic> toJson() => _$NodeMetadataToJson(this);
```

方案二：移除 `@JsonSerializable()` 注解，保持手动实现

---

## 总结

| Bug编号 | 文件 | 严重程度 | 类型 |
|---------|------|----------|------|
| 1 | node_repository.dart:169 | 高 | 异步编程错误 |
| 2 | node_repository.dart:524 | 高 | 数组索引错误 |
| 3 | node_repository.dart:571 | 中 | 类型安全 |
| 4 | metadata_index.dart:109 | 中 | 代码一致性 |

**建议优先级**:
1. 立即修复 Bug 1 和 Bug 2（高严重程度）
2. 尽快修复 Bug 3（提高健壮性）
3. 计划修复 Bug 4（代码质量改进）
