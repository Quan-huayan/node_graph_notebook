# Layout 插件 Bug 报告

## Bug 1: ApplyLayoutCommand.undo() 中 orElse 使用不当导致数据损坏风险

**文件**: [layout_commands.dart:56-58](file:///d:/Projects/node_graph_notebook/lib/plugins/layout/command/layout_commands.dart#L56-L58)

**严重程度**: 高

**问题描述**:
在 `ApplyLayoutCommand.undo()` 方法中，当查找节点时使用了 `orElse: () => nodes.first`：

```dart
final node = nodes.firstWhere(
  (n) => n.id == entry.key,
  orElse: () => nodes.first,
);
```

**问题**:
1. 如果找不到对应ID的节点，会错误地返回第一个节点
2. 如果 `nodes` 列表为空，`nodes.first` 会抛出 `StateError`
3. 这会导致错误节点的位置被修改，造成数据损坏

**建议修复**:
```dart
final node = nodes.firstWhere(
  (n) => n.id == entry.key,
  orElse: () => null,
);
if (node != null) {
  await repository.save(node.copyWith(position: entry.value));
}
```

---

## Bug 2: BatchMoveNodesCommand.oldPositions 使用 late 关键字可能导致运行时错误

**文件**: [layout_commands.dart:90](file:///d:/Projects/node_graph_notebook/lib/plugins/layout/command/layout_commands.dart#L90)

**严重程度**: 高

**问题描述**:
`oldPositions` 字段声明为 `late`，但没有初始化：

```dart
late Map<String, Offset> oldPositions;
```

**问题**:
1. 如果 `undo()` 方法在 `execute()` 之前被调用，会抛出 `LateInitializationError`
2. 如果 `BatchMoveNodesHandler` 未被正确注册，`execute()` 不会被调用，直接调用 `undo()` 会崩溃
3. 没有默认值或初始化逻辑

**建议修复**:
```dart
Map<String, Offset>? oldPositions;
```
并在 `undo()` 方法中添加空值检查。

---

## Bug 3: BatchMoveNodesHandler 未注册导致命令执行失败

**文件**: [layout_plugin.dart:70-73](file:///d:/Projects/node_graph_notebook/lib/plugins/layout/layout_plugin.dart#L70-L73)

**严重程度**: 高

**问题描述**:
在 `LayoutPlugin._registerCommandHandlers()` 中只注册了 `ApplyLayoutHandler`：

```dart
commandBus.registerHandler<ApplyLayoutCommand>(
  ApplyLayoutHandler(graphService, layoutService, commandBus),
  ApplyLayoutCommand,
);
```

但 `ApplyLayoutHandler.execute()` 方法会调用 `BatchMoveNodesCommand`：

```dart
await _commandBus.dispatch(BatchMoveNodesCommand(positions: positions));
```

**问题**:
1. `BatchMoveNodesCommand` 没有注册对应的处理器
2. 当执行布局命令时，会因为没有处理器而失败
3. `BatchMoveNodesHandler` 类已定义但从未使用

**建议修复**:
在 `_registerCommandHandlers()` 中添加：
```dart
commandBus.registerHandler<BatchMoveNodesCommand>(
  BatchMoveNodesHandler(context.read<NodeRepository>()),
  BatchMoveNodesCommand,
);
```

---

## Bug 4: IncrementalLayoutEngine BFS 边界条件错误

**文件**: [incremental_layout_engine.dart:131](file:///d:/Projects/node_graph_notebook/lib/plugins/layout/service/incremental_layout_engine.dart#L131)

**严重程度**: 中

**问题描述**:
在 `_determineAffectedNodes()` 方法的 BFS 循环中：

```dart
while (queue.isNotEmpty && currentRadius < influenceRadius) {
```

**问题**:
1. 当 `currentRadius` 等于 `influenceRadius - 1` 时，循环会处理该层节点
2. 但当 `currentRadius` 等于 `influenceRadius` 时，循环终止
3. 这意味着影响半径边界上的邻居节点不会被包含在受影响节点集合中
4. 例如，如果 `influenceRadius = 2`，只会处理半径为 0 和 1 的节点，半径为 2 的节点被忽略

**建议修复**:
```dart
while (queue.isNotEmpty && currentRadius <= influenceRadius) {
```

---

## Bug 5: ApplyLayoutCommand 撤销功能不完整

**文件**: [apply_layout_handler.dart:58-62](file:///d:/Projects/node_graph_notebook/lib/plugins/layout/handler/apply_layout_handler.dart#L58-L62)

**严重程度**: 中

**问题描述**:
保存原始位置的代码被注释掉：

```dart
// 保存原始位置用于撤销（注释掉，因为无法访问命令的私有字段）
// final originalPositions = <String, Offset>{};
// for (final node in graphNodes) {
//   originalPositions[node.id] = node.position;
// }
```

**问题**:
1. `ApplyLayoutCommand.undo()` 依赖 `_originalPositions` 字段
2. 但 Handler 从未设置这个值
3. 撤销操作实际上不会恢复任何节点位置

**建议修复**:
需要设计一种机制让 Handler 能够设置命令的原始位置数据，例如：
- 将 `_originalPositions` 改为公共字段
- 或在命令构造时传入原始位置

---

## Bug 6: 硬编码的布局边界值

**文件**: [layout_service.dart:292-293](file:///d:/Projects/node_graph_notebook/lib/plugins/layout/service/layout_service.dart#L292-L293)

**严重程度**: 低

**问题描述**:
力导向布局中使用了硬编码的边界值：

```dart
positions[node.id] = Vector2(
  newPos.x.clamp(50.0, 1200.0),
  newPos.y.clamp(50.0, 800.0),
);
```

**问题**:
1. 边界值硬编码，无法适应不同大小的画布
2. 如果实际画布大小不同，节点可能被限制在错误的位置
3. 应该作为参数或从配置中获取

**建议修复**:
将边界值作为 `ForceDirectedOptions` 的参数，或从画布配置中获取。

---

## 总结

| Bug ID | 严重程度 | 文件 | 问题简述 |
|--------|----------|------|----------|
| 1 | 高 | layout_commands.dart | orElse 返回错误节点 |
| 2 | 高 | layout_commands.dart | late 变量未初始化 |
| 3 | 高 | layout_plugin.dart | BatchMoveNodesHandler 未注册 |
| 4 | 中 | incremental_layout_engine.dart | BFS 边界条件错误 |
| 5 | 中 | apply_layout_handler.dart | 撤销功能不完整 |
| 6 | 低 | layout_service.dart | 硬编码边界值 |
