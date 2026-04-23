# 菜单模块 Bug 报告

**审查日期**: 2026-04-21  
**审查范围**: `lib/plugins/graph/ui/node_menu.dart`、`lib/plugins/graph/service/node_context_menu.dart`、`lib/plugins/layout/ui/layout_menu.dart`

---

## Bug 1: "Connect to..." 菜单项无点击响应

### 位置
- [node_menu.dart:32-36](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/ui/node_menu.dart#L32-L36)

### 问题描述
`showNodeMenu` 函数中的 "Connect to..." 菜单项（`ListTile`）缺少 `onTap` 回调，用户点击该菜单项后无任何反应，菜单不会关闭，也不会触发任何连接操作。

### 问题代码
```dart
const ListTile(
  leading: Icon(Icons.link),
  title: Text('Connect to...'),
  trailing: Icon(Icons.chevron_right),
),
```

### 影响
- 用户无法通过节点菜单执行"连接到其他节点"操作
- 菜单项显示存在但功能缺失，造成用户困惑
- `trailing: Icon(Icons.chevron_right)` 暗示有子菜单或后续操作，但实际无响应

### 修复建议
添加 `onTap` 回调实现连接功能：
```dart
ListTile(
  leading: const Icon(Icons.link),
  title: const Text('Connect to...'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () {
    Navigator.pop(ctx);
    // 实现连接节点功能，例如显示节点选择器
    _showNodeSelectorForConnection(context, node);
  },
),
```

---

## Bug 2: "References" 菜单项无点击响应

### 位置
- [node_menu.dart:37-44](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/ui/node_menu.dart#L37-L44)

### 问题描述
`showNodeMenu` 函数中的 "References" 菜单项缺少 `onTap` 回调，用户点击后无任何反应。该菜单项显示节点的引用数量，但无法查看引用详情或执行相关操作。

### 问题代码
```dart
ListTile(
  leading: const Icon(Icons.info_outline),
  title: const Text('References'),
  trailing: Chip(
    label: Text('${node.references.length}'),
    padding: EdgeInsets.zero,
  ),
),
```

### 影响
- 用户无法查看节点的引用详情
- 菜单项仅作为信息展示，无交互功能
- 如果设计意图是仅展示信息，应使用 `enabled: false` 或其他非交互式组件

### 修复建议
添加 `onTap` 回调或明确标记为非交互：
```dart
ListTile(
  leading: const Icon(Icons.info_outline),
  title: const Text('References'),
  trailing: Chip(
    label: Text('${node.references.length}'),
    padding: EdgeInsets.zero,
  ),
  onTap: node.references.isNotEmpty ? () {
    Navigator.pop(ctx);
    _showReferencesDialog(context, node);
  } : null,
),
```

---

## Bug 3: 删除确认对话框 Context 使用不一致

### 位置
- [node_menu.dart:48-73](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/ui/node_menu.dart#L48-L73)

### 问题描述
在删除操作的确认对话框中，`showDialog` 使用 `ctx` 作为 context，但对话框内的 `Navigator.pop` 调用也使用 `ctx`。当用户确认删除后，代码先调用 `Navigator.pop(ctx, false/true)` 关闭对话框，然后检查 `ctx.mounted` 并再次调用 `Navigator.pop(ctx)` 关闭底部菜单。这种设计存在潜在问题：`ctx` 是 `showModalBottomSheet` 的 builder context，在对话框关闭后可能已经失效。

### 问题代码
```dart
onTap: () async {
  final confirmed = await showDialog<bool>(
    context: ctx,  // <-- 使用 ctx
    builder: (ctx) => AlertDialog(  // <-- 参数名遮蔽了外部的 ctx
      // ...
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),  // <-- 这里的 ctx 是 builder 参数
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),  // <-- 同上
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if ((confirmed ?? false) && ctx.mounted) {  // <-- 这里的 ctx 是外部的 builder context
    Navigator.pop(ctx);  // <-- 关闭底部菜单
    context.read<NodeBloc>().add(NodeDeleteEvent(node.id));
  }
},
```

### 影响
- 变量命名遮蔽（shadowing）导致代码可读性差
- 虽然当前代码能正常工作，但 `ctx` 的双重用途容易引起混淆
- 如果未来修改代码结构，可能导致 context 使用错误

### 修复建议
使用不同的变量名避免遮蔽：
```dart
onTap: () async {
  final confirmed = await showDialog<bool>(
    context: ctx,
    builder: (dialogCtx) => AlertDialog(
      // ...
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if ((confirmed ?? false) && ctx.mounted) {
    Navigator.pop(ctx);
    context.read<NodeBloc>().add(NodeDeleteEvent(node.id));
  }
},
```

---

## Bug 4: 复制节点时丢失视图模式

### 位置
- [node_context_menu.dart:460-469](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/service/node_context_menu.dart#L460-L469)

### 问题描述
`_handleDuplicate` 方法创建节点副本时，`NodeCreateEvent` 没有传递 `viewMode` 参数。根据 `NodeCreateEvent` 的定义，`viewMode` 不在其构造函数参数中，因此新节点会使用默认视图模式，而非复制原节点的视图模式。

### 问题代码
```dart
nodeBloc.add(
  NodeCreateEvent(
    title: newTitle,
    content: node.content,
    position: newPosition,
    color: node.color,
    metadata: Map<String, dynamic>.from(node.metadata),
  ),
);
```

`NodeCreateEvent` 定义（缺少 viewMode）：
```dart
class NodeCreateEvent extends NodeEvent {
  const NodeCreateEvent({
    required this.title,
    this.content,
    this.metadata,
    this.position,
    this.color,
    // 注意：没有 viewMode 参数
  });
}
```

### 影响
- 复制节点后，新节点的视图模式会重置为默认值
- 用户设置的节点显示偏好（如"仅标题"、"完整内容"等）在复制后丢失
- 与用户预期的"完全复制"行为不符

### 修复建议
方案一：在 `NodeCreateEvent` 中添加 `viewMode` 参数：
```dart
// node_event.dart
class NodeCreateEvent extends NodeEvent {
  const NodeCreateEvent({
    required this.title,
    this.content,
    this.metadata,
    this.position,
    this.color,
    this.viewMode,  // 新增
  });
  final NodeViewMode? viewMode;
}

// node_context_menu.dart
nodeBloc.add(
  NodeCreateEvent(
    title: newTitle,
    content: node.content,
    position: newPosition,
    color: node.color,
    viewMode: node.viewMode,  // 传递原节点的视图模式
    metadata: Map<String, dynamic>.from(node.metadata),
  ),
);
```

方案二：在 `metadata` 中存储视图模式（不推荐，因为 `viewMode` 是 Node 的一级字段）。

---

## Bug 5: 更改颜色时无法清除颜色

### 位置
- [node_context_menu.dart:356-413](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/service/node_context_menu.dart#L356-L413)

### 问题描述
`_handleChangeColor` 方法中，颜色选择对话框的第一个选项是 `null`（代表"无颜色"或"默认颜色"）。当用户选择这个选项时，`selectedColor` 为 `null`。然而，在更新节点时，代码检查 `selectedColor != null` 才执行更新，导致用户无法清除节点颜色。

### 问题代码
```dart
final colors = [
  null,  // <-- 第一个选项是 null，代表"无颜色"
  '#FF6B6B',
  // ...
];

// 用户选择第一个选项时，selectedColor 为 null
final selectedColor = await showDialog<String?>(...);

if (selectedColor != null && context.mounted) {  // <-- null 时不执行更新
  nodeBloc.add(NodeUpdateEvent(node.id, color: selectedColor));
}
```

### 影响
- 用户无法将已设置颜色的节点恢复为无颜色状态
- 颜色选择对话框中的第一个选项（灰色圆形）形同虚设
- 与用户直觉不符：既然提供了"无颜色"选项，就应该能够选择它

### 修复建议
区分"用户取消选择"和"用户选择无颜色"：
```dart
final colors = [
  '',  // 使用空字符串代表"清除颜色"，而非 null
  '#FF6B6B',
  // ...
];

// 在对话框中
final selectedColor = await showDialog<String?>(...);

if (selectedColor != null && context.mounted) {
  if (selectedColor.isEmpty) {
    // 清除颜色：传递空字符串或特殊标记
    nodeBloc.add(NodeUpdateEvent(node.id, color: null));
  } else {
    nodeBloc.add(NodeUpdateEvent(node.id, color: selectedColor));
  }
}
```

或者使用不同的返回机制：
```dart
// 返回一个记录类型或封装类
final result = await showDialog<_ColorSelectionResult>(...);

if (result != null && context.mounted) {
  nodeBloc.add(NodeUpdateEvent(node.id, color: result.color));
}

class _ColorSelectionResult {
  final String? color;
  final bool clear;  // 明确标记是否要清除颜色
}
```

---

## Bug 6: 删除节点后未从图中移除

### 位置
- [node_context_menu.dart:266-321](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/service/node_context_menu.dart#L266-L321)

### 问题描述
`_handleDelete` 方法在删除节点时，只调用了 `NodeBloc` 的 `NodeDeleteEvent`，但没有通知 `GraphBloc` 从当前图中移除该节点。根据架构设计，`GraphBloc` 维护着当前图中的节点 ID 列表（`graph.nodeIds`），删除节点后应该同步更新该列表。

### 问题代码
```dart
if ((confirmed ?? false) && context.mounted) {
  try {
    // 只删除节点本身，没有从图中移除
    nodeBloc.add(NodeDeleteEvent(node.id));
    // 缺少：graphBloc.add(NodeMoveOutEvent(node.id));
    // ...
  }
}
```

### 影响
- 删除节点后，`GraphBloc` 的 `state.graph.nodeIds` 仍然包含已删除节点的 ID
- 下次加载图时，会尝试加载不存在的节点，可能导致错误
- 图视图可能显示"幽灵节点"或出现数据不一致

### 修复建议
在删除节点时，同时通知 `GraphBloc`：
```dart
if ((confirmed ?? false) && context.mounted) {
  try {
    // 先从图中移除节点
    graphBloc.add(NodeMoveOutEvent(node.id));
    // 再删除节点本身
    nodeBloc.add(NodeDeleteEvent(node.id));
    // ...
  }
}
```

注意：根据 `GraphBloc` 的 `_handleNodeDataChanged` 方法，当收到 `NodeDataChangedEvent` 且 `action` 为 `delete` 时，会自动从图中移除节点。因此，如果 `NodeBloc` 在删除节点后发布了 `NodeDataChangedEvent`，则此 bug 可能不存在。需要确认 `NodeDeleteCommand` 的 handler 是否发布了正确的事件。

---

## Bug 7: `_handleFocus` 方法中 SnackBar 显示时机不当

### 位置
- [node_context_menu.dart:479-492](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/service/node_context_menu.dart#L479-L492)

### 问题描述
`_handleFocus` 方法在发送聚焦事件后，立即显示 SnackBar 提示。但此时聚焦操作是异步的，SnackBar 显示的是"正在聚焦"而非"聚焦完成"。如果聚焦操作失败，用户已经看到了成功提示，造成信息不一致。

### 问题代码
```dart
void _handleFocus(BuildContext context, Node node) {
  final i18n = I18n.of(context);

  context.read<GraphBloc>().add(FocusNodeEvent(node.id));

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${i18n.t('Focusing on')} ${node.title}')));
  }
}
```

### 影响
- SnackBar 提示时机过早，聚焦操作尚未完成
- 如果聚焦失败，用户仍看到成功提示
- 应该在聚焦成功后再显示提示，或者显示"正在聚焦..."

### 修复建议
方案一：在 `GraphBloc` 的 `FocusNodeEvent` 处理完成后显示 SnackBar（需要监听状态变化）：
```dart
void _handleFocus(BuildContext context, Node node) {
  final i18n = I18n.of(context);
  final graphBloc = context.read<GraphBloc>();
  
  // 监听状态变化
  final subscription = graphBloc.stream.listen((state) {
    if (!state.isLoading && state.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${i18n.t('Focused on')} ${node.title}')),
      );
    }
  });
  
  graphBloc.add(FocusNodeEvent(node.id));
}
```

方案二：简化提示文案，明确表示"正在聚焦"：
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('${i18n.t('Focusing on')} ${node.title}'),
    duration: const Duration(seconds: 1),  // 缩短显示时间
  ),
);
```

---

## Bug 8: `manageConnections` 菜单项未实现

### 位置
- [node_context_menu.dart:97-106](file:///d:/Projects/node_graph_notebook/lib/plugins/graph/service/node_context_menu.dart#L97-L106)

### 问题描述
`showNodeContextMenu` 中的 "Manage Connections" 菜单项在 `switch` 语句中没有对应的处理逻辑。用户点击该菜单项后，`selectedAction` 为 `_MenuAction.manageConnections`，但 `switch` 语句会进入 `default` 分支，尝试将其转换为视图模式，返回 `null`，导致无任何操作执行。

### 问题代码
```dart
switch (selectedAction) {
  case _MenuAction.delete:
    await _handleDelete(context, node, graphBloc, nodeBloc);
    break;

  case _MenuAction.editMetadata:
    await _handleEditMetadata(context, node);
    break;

  case _MenuAction.addIcon:
    await _handleAddIcon(context, node);
    break;

  case _MenuAction.changeColor:
    await _handleChangeColor(context, node, nodeBloc);
    break;

  case _MenuAction.duplicate:
    await _handleDuplicate(context, node, nodeBloc);
    break;

  case _MenuAction.focus:
    _handleFocus(context, node);
    break;

  default:
    // manageConnections 会进入这里，被当作视图模式处理
    final newMode = _actionToViewMode(selectedAction);
    if (newMode != null && newMode != node.viewMode) {
      nodeBloc.add(NodeUpdateEvent(node.id, viewMode: newMode));
    }
}
```

`_actionToViewMode` 方法：
```dart
NodeViewMode? _actionToViewMode(_MenuAction action) {
  switch (action) {
    case _MenuAction.titleOnly:
      return NodeViewMode.titleOnly;
    // ...
    default:
      return null;  // <-- manageConnections 返回 null
  }
}
```

### 影响
- 用户点击 "Manage Connections" 后无任何反应
- 菜单项存在但功能未实现
- 与 Bug 1、Bug 2 类似，属于"空壳"菜单项

### 修复建议
在 `switch` 语句中添加 `manageConnections` 的处理逻辑：
```dart
case _MenuAction.manageConnections:
  await _handleManageConnections(context, node, nodeBloc);
  break;

// 新增处理方法
Future<void> _handleManageConnections(
  BuildContext context,
  Node node,
  NodeBloc nodeBloc,
) async {
  // 实现连接管理对话框
  await showDialog(
    context: context,
    builder: (context) => ConnectionsManagementDialog(node: node),
  );
}
```

---

## 总结

| Bug ID | 严重程度 | 文件 | 问题类型 |
|--------|----------|------|----------|
| Bug 1 | 高 | node_menu.dart | 功能缺失：Connect to 菜单项无响应 |
| Bug 2 | 中 | node_menu.dart | 功能缺失：References 菜单项无响应 |
| Bug 3 | 低 | node_menu.dart | 代码质量：Context 变量遮蔽 |
| Bug 4 | 中 | node_context_menu.dart | 数据丢失：复制节点丢失视图模式 |
| Bug 5 | 中 | node_context_menu.dart | 功能缺陷：无法清除节点颜色 |
| Bug 6 | 高 | node_context_menu.dart | 数据不一致：删除节点未从图中移除 |
| Bug 7 | 低 | node_context_menu.dart | 用户体验：SnackBar 显示时机不当 |
| Bug 8 | 高 | node_context_menu.dart | 功能缺失：Manage Connections 未实现 |

### 优先级建议
1. **Bug 1、Bug 8** 应优先修复——菜单项存在但无功能，严重影响用户体验
2. **Bug 6** 需要确认——如果 `NodeDeleteCommand` 的 handler 已正确发布 `NodeDataChangedEvent`，则此 bug 可能不存在；否则会导致数据不一致
3. **Bug 4、Bug 5** 建议尽快修复——影响节点复制和颜色管理的基本功能
4. **Bug 2、Bug 3、Bug 7** 建议在下次迭代中处理——属于用户体验优化
