# Bug Report: models 文件夹

## 审查范围
`lib/core/models/` 文件夹下的所有 Dart 文件

---

## Bug 1: GraphViewConfig.toJson() 冗余序列化

### 文件位置
`lib/core/models/graph.dart`

### 位置
第 56-57 行

### 问题描述
`toJson()` 方法中，`_$GraphViewConfigToJson(this)` 已经会序列化所有字段（包括 `camera`），但代码又手动设置了一次 `camera`，导致冗余操作。

### 问题代码
```dart
Map<String, dynamic> toJson() =>
    _$GraphViewConfigToJson(this)..['camera'] = camera.toJson();
```

### 影响
1. **性能浪费**：`camera` 字段被序列化两次
2. **潜在数据不一致**：如果 `_$GraphViewConfigToJson` 和手动序列化产生不同结果，可能导致问题

### 建议修复
```dart
Map<String, dynamic> toJson() => _$GraphViewConfigToJson(this);
```

---

## Bug 2: Graph.toJson() 冗余序列化

### 文件位置
`lib/core/models/graph.dart`

### 位置
第 253-254 行

### 问题描述
与 Bug 1 类似，`toJson()` 方法中，`_$GraphToJson(this)` 已经会序列化所有字段（包括 `viewConfig`），但代码又手动设置了一次 `viewConfig`。

### 问题代码
```dart
Map<String, dynamic> toJson() =>
    _$GraphToJson(this)..['viewConfig'] = viewConfig.toJson();
```

### 影响
1. **性能浪费**：`viewConfig` 字段被序列化两次
2. **潜在数据不一致**：如果 `_$GraphToJson` 和手动序列化产生不同结果，可能导致问题

### 建议修复
```dart
Map<String, dynamic> toJson() => _$GraphToJson(this);
```

---

## Bug 3: Node.hashCode 与 == 操作符不一致

### 文件位置
`lib/core/models/node.dart`

### 位置
第 214-231 行

### 问题描述
`==` 操作符比较了多个字段（id, title, content, references, position, size, viewMode, color, createdAt, updatedAt, metadata），但 `hashCode` 只使用了 `id.hashCode`。

### 问题代码
```dart
@override
bool operator ==(Object other) =>
    identical(this, other) ||
    other is Node &&
        runtimeType == other.runtimeType &&
        id == other.id &&
        title == other.title &&
        content == other.content &&
        _mapEquals(references, other.references) &&
        position == other.position &&
        size == other.size &&
        viewMode == other.viewMode &&
        color == other.color &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        _mapEquals(metadata, other.metadata);

@override
int get hashCode => id.hashCode;
```

### 影响
1. **违反最佳实践**：虽然不严格违反 Dart 契约（相等的对象必须有相同的 hashCode），但会导致大量哈希冲突
2. **性能问题**：当 Node 对象用作 Map 的 key 或存入 Set 时，会导致性能下降

### 建议修复
```dart
@override
int get hashCode => Object.hash(
  id,
  title,
  content,
  position,
  size,
  viewMode,
  color,
  createdAt,
  updatedAt,
);
```
注意：由于 `references` 和 `metadata` 是 Map 类型，无法直接用于 `Object.hash`，可以考虑忽略它们或使用其他方式计算。

---

## Bug 4: NodeReference.== 忽略 properties 字段

### 文件位置
`lib/core/models/node_reference.dart`

### 位置
第 59-68 行

### 问题描述
`==` 操作符只比较 `nodeId` 和 `type`，完全忽略了 `properties` 字段。这意味着两个具有相同 `nodeId` 和 `type` 但不同 `properties` 的 `NodeReference` 会被认为相等。

### 问题代码
```dart
@override
bool operator ==(Object other) =>
    identical(this, other) ||
    other is NodeReference &&
        runtimeType == other.runtimeType &&
        nodeId == other.nodeId &&
        type == other.type;
```

### 影响
1. **语义错误**：两个具有不同属性（如不同的 `role` 或自定义属性）的引用被认为是相等的
2. **数据丢失风险**：在 Set 或 Map 中存储 NodeReference 时，可能会丢失不同的 properties

### 示例
```dart
final ref1 = NodeReference(
  nodeId: 'node1',
  properties: {'type': 'contains', 'role': 'parent'},
);
final ref2 = NodeReference(
  nodeId: 'node1',
  properties: {'type': 'contains', 'role': 'child'},
);

print(ref1 == ref2);  // true，但它们的 role 不同！
```

### 建议修复
```dart
@override
bool operator ==(Object other) =>
    identical(this, other) ||
    other is NodeReference &&
        runtimeType == other.runtimeType &&
        nodeId == other.nodeId &&
        type == other.type &&
        _mapEquals(properties, other.properties);

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}
```

---

## Bug 5: _PlaceholderNodeComponent 使用已弃用的 position 字段

### 文件位置
`lib/core/models/node_rendering.dart`

### 位置
第 302-305 行

### 问题描述
`_PlaceholderNodeComponent` 的构造函数中使用了 `node.position` 字段，但根据代码注释（第 100-122 行），`position` 字段已弃用，将在第6阶段移除。

### 问题代码
```dart
// 设置组件位置
position = Vector2(
  node.position.dx,
  node.position.dy,
);
```

### 影响
1. **未来兼容性问题**：当 `position` 字段被移除后，此代码将无法编译
2. **架构不一致**：代码注释明确指出位置应由 `UILayoutService` 管理，但这里直接使用了 `node.position`

### 建议修复
应该从 `UILayoutService` 获取节点位置，而不是直接使用 `node.position`。或者，在构造函数中接收位置参数：
```dart
_PlaceholderNodeComponent({
  required this.node,
  required Offset position,
}) {
  size = Vector2(
    node.size.width.isFinite ? node.size.width : 200,
    node.size.height.isFinite ? node.size.height : 80,
  );
  this.position = Vector2(position.dx, position.dy);
}
```

---

## 总结

| Bug | 严重程度 | 影响范围 |
|-----|---------|---------|
| Bug 1 | 低 | 性能浪费 |
| Bug 2 | 低 | 性能浪费 |
| Bug 3 | 中 | 哈希冲突，性能下降 |
| Bug 4 | 高 | 数据语义错误 |
| Bug 5 | 中 | 未来兼容性问题 |
