# UI Layout 模块 Bug 报告

**审查日期**: 2026-04-20  
**审查范围**: `lib/core/ui_layout` 文件夹

---

## Bug 1: GridLayoutCalculator 中 cellWidth 计算使用了错误的变量

### 位置
- [layout_strategy.dart:464-466](file:///d:/Projects/node_graph_notebook/lib/core/ui_layout/layout_strategy.dart#L464-L466)

### 问题描述
在 `GridLayoutCalculator.calculate()` 方法中，计算 `cellWidth` 时使用了原始的 `columns` 变量，而不是经过验证的 `columnCount` 变量。

### 问题代码
```dart
final columns = config.columns ?? 2;
final columnCount = columns > 0 ? columns : 2;

// Calculate cell size
final availableWidth = hook.size.width - config.padding.horizontal;
final cellWidth = (availableWidth -
        (columns - 1) * config.crossAxisSpacing) /  // <-- 应该使用 columnCount
    columnCount;
```

### 影响
当 `config.columns` 为 0 或负数时：
- `columnCount` 被正确设置为 2
- 但 `cellWidth` 计算中仍然使用 `columns`（可能是 0 或负数）
- 导致 `(columns - 1)` 可能产生负数，从而计算出错误的单元格宽度
- 如果 `columns` 为 0，`(0 - 1) * config.crossAxisSpacing` 会产生负数偏移

### 修复建议
```dart
final cellWidth = (availableWidth -
        (columnCount - 1) * config.crossAxisSpacing) /
    columnCount;
```

---

## Bug 2: FlameRenderer._renderGrid() 中存在相同的 cellWidth 计算错误

### 位置
- [rendering/flame_renderer.dart:304](file:///d:/Projects/node_graph_notebook/lib/core/ui_layout/rendering/flame_renderer.dart#L304)

### 问题描述
与 Bug 1 相同的问题，在 Flame 渲染器的网格布局渲染中也存在。

### 问题代码
```dart
final columns = config.columns ?? 2;
final columnCount = columns > 0 ? columns : 2;

// ...

// Calculate cell size
final availableWidth = hook.size.width - config.padding.horizontal;
final cellWidth =
    (availableWidth - (columns - 1) * config.crossAxisSpacing) /  // <-- 应该使用 columnCount
        columnCount;
```

### 影响
与 Bug 1 相同，在 Flame 渲染器中使用网格布局时会产生错误的单元格宽度计算。

### 修复建议
```dart
final cellWidth =
    (availableWidth - (columnCount - 1) * config.crossAxisSpacing) /
        columnCount;
```

---

## Bug 3: 布局状态持久化丢失 sequential 位置的 index 信息

### 位置
- [ui_layout_service.dart:856](file:///d:/Projects/node_graph_notebook/lib/core/ui_layout/ui_layout_service.dart#L856)

### 问题描述
在 `_restoreLayout()` 方法中尝试读取 `index` 字段来恢复 `sequential` 类型的位置，但在 `_persistLayout()` 方法中从未保存该字段。

### 问题代码

**持久化代码 (第 796-808 行)**:
```dart
final data = {
  'nodeAttachments': _nodeToHookIndex.map((nodeId, hookId) {
    final hook = _hookIndex[hookId];
    final attachment = hook?.getAttachedNode(nodeId);
    return MapEntry(nodeId, {
      'hookId': hookId,
      'position': {
        'x': attachment?.localPosition.x ?? 0.0,
        'y': attachment?.localPosition.y ?? 0.0,
        'type': attachment?.localPosition.type.name ?? 'absolute',
        // 注意：没有保存 'index' 字段！
      },
      'zIndex': attachment?.zIndex ?? 0,
    });
  }),
};
```

**恢复代码 (第 856 行)**:
```dart
final index = positionData['index'] as int?;  // 永远为 null！
```

### 影响
- 当节点使用 `LocalPosition.sequential(index: n)` 位置时
- 持久化后恢复会丢失原始的 `index` 值
- 恢复时 `index` 总是 `null`，导致使用默认值 `0`
- 所有 sequential 位置的节点恢复后都会被放置在索引 0 的位置

### 修复建议

在 `_persistLayout()` 方法中添加 `index` 字段的保存：

```dart
'position': {
  'x': attachment?.localPosition.x ?? 0.0,
  'y': attachment?.localPosition.y ?? 0.0,
  'type': attachment?.localPosition.type.name ?? 'absolute',
  'index': attachment?.localPosition.type == PositionType.sequential 
      ? attachment?.localPosition.x.toInt()  // sequential 类型中 x 存储的是 index
      : null,
},
```

---

## 总结

| Bug ID | 严重程度 | 文件 | 问题类型 |
|--------|----------|------|----------|
| Bug 1 | 中 | layout_strategy.dart | 变量使用错误 |
| Bug 2 | 中 | flame_renderer.dart | 变量使用错误（与 Bug 1 相同） |
| Bug 3 | 高 | ui_layout_service.dart | 数据丢失 |

### 优先级建议
1. **Bug 3** 应优先修复，因为它会导致用户数据丢失
2. **Bug 1 & 2** 应尽快修复，因为它们会导致网格布局在边界条件下产生错误的渲染结果
