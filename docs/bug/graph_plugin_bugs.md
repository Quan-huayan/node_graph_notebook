# Graph 插件 Bug 报告

**审查日期**: 2026-04-20  
**审查范围**: `lib/plugins/graph` 文件夹

---

## 严重 Bug (Critical)

### 1. `catchError` 返回类型不匹配

**文件**: [graph_bloc.dart:305](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/bloc/graph_bloc.dart#L305)

**问题描述**:
`catchError` 回调返回了 `CommandResult<void>.failure(e.toString())`，但原始 Future 的类型是 `void`。`catchError` 的回调应该返回与原始 Future 相同类型的值，或者抛出异常。

**代码片段**:
```dart
_commandBus
    .dispatch(UpdateNodePositionCommand(...))
    .catchError((e) async {
  debugPrint('Failed to persist node position: $e');
  return CommandResult<void>.failure(e.toString()); // 类型错误
});
```

**影响**: 可能导致运行时类型错误，异步错误处理失效。

**修复建议**:
```dart
_commandBus
    .dispatch(UpdateNodePositionCommand(...))
    .catchError((e) {
  debugPrint('Failed to persist node position: $e');
  // 不返回值，或重新抛出异常
});
```

---

### 2. `firstWhere` 的 `orElse` 逻辑错误

**文件**: [node_bloc.dart:438-444](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/bloc/node_bloc.dart#L438-L444)

**问题描述**:
在 `_onDataChangedInternal` 方法中，`orElse: () => n` 的逻辑有问题。当 `firstWhere` 找不到匹配项时，它会返回 `n` 本身，但后续的条件判断 `updated.id == n.id` 会始终为 true，导致返回 `updated`（实际上是 `n`），这是逻辑错误。

**代码片段**:
```dart
final updatedNodes = state.nodes.map((n) {
  final updated = event.changedNodes.firstWhere(
    (u) => u.id == n.id,
    orElse: () => n, // 问题：返回 n 本身
  );
  return updated.id == n.id ? updated : n; // 条件始终为 true
}).toList();
```

**影响**: 节点更新逻辑可能无法正确识别需要更新的节点。

**修复建议**:
```dart
final updatedNodes = state.nodes.map((n) {
  final updated = event.changedNodes.firstWhere(
    (u) => u.id == n.id,
    orElse: () => n,
  );
  // 检查是否真的找到了更新的节点
  if (updated != n) {
    return updated;
  }
  return n;
}).toList();
```

---

### 3. 连接线边缘点计算未实现

**文件**: [connection_renderer.dart:127-132](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/flame/components/connection_renderer.dart#L127-L132)

**问题描述**:
`_calculateEdgePoint` 方法直接返回 `from`，没有实际计算边缘点。这意味着连接线总是从节点中心开始，而不是从节点边缘开始。

**代码片段**:
```dart
Vector2 _calculateEdgePoint(
  Vector2 from,
  Vector2 to, {
  required bool isStart,
}) =>
    from; // 直接返回起点，没有计算边缘点
```

**影响**: 连接线会穿过节点，而不是从节点边缘开始/结束，视觉效果不正确。

**修复建议**:
实现真正的边缘点计算，考虑节点的大小和形状。

---

## 高危 Bug (High)

### 4. 空间索引重建方法逻辑错误

**文件**: [spatial_index_manager.dart:162-169](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/flame/spatial_index_manager.dart#L162-L169)

**问题描述**:
`rebuild` 方法在清空后重新初始化，但 `_nodeComponents` 已经被清空了，所以 `addNode` 不会添加任何节点。

**代码片段**:
```dart
void rebuild() {
  if (_quadTree == null) return;

  final bounds = _quadTree!.bounds;
  clear(); // 清空了 _nodeComponents
  init(bounds);

  _nodeComponents.values.forEach(addNode); // _nodeComponents 已为空
}
```

**影响**: 调用 `rebuild` 后，空间索引将丢失所有节点信息。

**修复建议**:
```dart
void rebuild() {
  if (_quadTree == null) return;

  final bounds = _quadTree!.bounds;
  final nodesToRebuild = _nodeComponents.values.toList(); // 先保存
  clear();
  init(bounds);

  for (final node in nodesToRebuild) {
    addNode(node);
  }
}
```

---

### 5. 私有字段无法被外部设置

**文件**: [node_commands.dart:108](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/command/node_commands.dart#L108)

**问题描述**:
`DeleteNodeCommand` 中的 `_incomingConnections` 字段是私有的，但在 `undo` 方法中被使用来恢复连接。Handler 无法设置这个私有字段。

**代码片段**:
```dart
Map<String, NodeReference>? _incomingConnections; // 私有字段

@override
Future<void> undo(CommandContext context) async {
  // ...
  if (_incomingConnections != null) { // Handler 无法设置此字段
    // ...
  }
}
```

**影响**: 删除节点的撤销功能无法正常工作。

**修复建议**:
将字段改为公共字段，或在命令类中提供设置方法。

---

### 6. `reduce` 未处理空列表

**文件**: [node_sizing_task.dart:79](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/tasks/node_sizing_task.dart#L79)

**问题描述**:
使用了 `reduce` 但没有处理空列表的情况，如果 `titleWidth` 和 `contentWidth` 都为 0，会导致运行时错误。

**代码片段**:
```dart
final width = [titleWidth, contentWidth].reduce((a, b) => a > b ? a : b);
```

**影响**: 当标题和内容宽度都为 0 时，会抛出 `StateError: No element` 异常。

**修复建议**:
```dart
final width = [titleWidth, contentWidth].reduce((a, b) => a > b ? a : b);
// 或使用 fold 提供默认值
final width = [titleWidth, contentWidth].fold(0.0, (a, b) => a > b ? a : b);
```

---

## 中危 Bug (Medium)

### 7. 硬编码的游戏尺寸和相机位置

**文件**: [graph_widget.dart:346-363](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/flame/graph_widget.dart#L346-L363)

**问题描述**:
坐标转换逻辑使用了硬编码的游戏尺寸和相机位置，这可能与实际配置不一致，导致拖放位置不准确。

**代码片段**:
```dart
// Flame 游戏配置的虚拟分辨率
const gameWidth = 4096.0;
const gameHeight = 2160.0;

// 相机中心位置
const cameraX = 2048.0;
const cameraY = 1080.0;
```

**影响**: 拖放节点时位置计算可能不准确。

**修复建议**:
从实际的 `GraphGame` 或 `viewConfig` 中获取这些值。

---

### 8. 字段命名不一致

**文件**: [text_layout_task.dart:94](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/tasks/text_layout_task.dart#L94)

**问题描述**:
`lineCount` 字段类型是 `List<LineMetrics>`，但字段名是 `lineCount`，命名不一致。

**代码片段**:
```dart
final List<LineMetrics> lineCount; // 应该叫 lineMetrics
```

**影响**: 代码可读性降低，可能导致误解。

**修复建议**:
将字段名改为 `lineMetrics` 或将类型改为 `int`。

---

### 9. 未完成的方法调用

**文件**: [node_drag_controller.dart:110](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/flame/node_drag_controller.dart#L110)

**问题描述**:
注释掉了 `nodeComponent.onDragStart()` 调用，但这个方法需要参数，说明接口设计不完整。

**代码片段**:
```dart
// 通知节点进入拖拽状态
// nodeComponent.onDragStart(); // 这个方法需要参数，暂时注释
```

**影响**: 节点拖拽状态通知功能未实现。

**修复建议**:
完善 `NodeComponent` 的拖拽状态通知接口。

---

### 10. 方法命名不符合 Dart 惯例

**文件**: [graph_service.dart:239](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/service/graph_service.dart#L239)

**问题描述**:
`__generateId` 方法名使用了双下划线前缀，这在 Dart 中不是惯用做法，而且方法名看起来像是私有方法但实际是公共的。

**代码片段**:
```dart
String __generateId() => 'graph_${DateTime.now().millisecondsSinceEpoch}';
```

**影响**: 代码风格不一致，可能造成混淆。

**修复建议**:
```dart
String _generateId() => 'graph_${DateTime.now().millisecondsSinceEpoch}';
```

---

## 总结

| 严重程度 | 数量 |
|---------|------|
| Critical | 3 |
| High | 3 |
| Medium | 4 |
| **总计** | **10** |

建议优先修复 Critical 和 High 级别的 Bug，它们可能导致运行时错误或功能失效。
