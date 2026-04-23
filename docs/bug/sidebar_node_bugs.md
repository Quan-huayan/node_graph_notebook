# SidebarNode 模块 Bug 报告

## 文件位置
`lib/plugins/sidebarNode/ui/`

---

## Bug 1: 节点高亮清除逻辑错误（严重）

### 文件
- [sidebar_hook_renderer.dart](file:///d:/Projects/node_graph_notebook/lib/plugins/sidebarNode/ui/sidebar_hook_renderer.dart)
- [sidebar_hook_renderer_simple.dart](file:///d:/Projects/node_graph_notebook/lib/plugins/sidebarNode/ui/sidebar_hook_renderer_simple.dart)

### 位置
`sidebar_hook_renderer.dart:202-232` - `_handleNodeTap` 方法

### 问题描述
在 `_handleNodeTap` 方法中，清除之前选中节点高亮的逻辑存在严重的时序错误：

```dart
void _handleNodeTap(NodeData nodeData) {
  // ...
  
  // 更新选中状态
  setState(() {
    _selectedNodeId = nodeData.id;  // 第206行：_selectedNodeId 已被更新为当前节点ID
  });

  // 高亮选中的节点
  if (_layoutService != null) {
    try {
      // 清除之前选中节点的高亮
      if (_selectedNodeId != null && _selectedNodeId != nodeData.id) {  // 第215行：条件永远为 false！
        _layoutService!.updateNodeRenderState(
          nodeId: _selectedNodeId!,
          renderState: 'rendering',
        );
      }
      // ...
    }
  }
}
```

### 根本原因
`setState` 在第206行已经将 `_selectedNodeId` 更新为 `nodeData.id`，因此在第215行检查 `_selectedNodeId != nodeData.id` 时，条件**永远为 false**。这意味着：
- 之前选中节点的高亮状态**永远不会被清除**
- 用户切换选择时，会出现多个节点同时高亮的情况

### 影响范围
- 两个文件都存在相同问题
- 严重影响用户体验，导致节点选择状态混乱

### 修复建议
在调用 `setState` 之前保存旧的选中节点ID：

```dart
void _handleNodeTap(NodeData nodeData) {
  _log.debug('Node tapped: ${nodeData.id}');

  // 保存旧的选中节点ID
  final previousSelectedId = _selectedNodeId;

  // 更新选中状态
  setState(() {
    _selectedNodeId = nodeData.id;
  });

  // 高亮选中的节点
  if (_layoutService != null) {
    try {
      // 清除之前选中节点的高亮
      if (previousSelectedId != null && previousSelectedId != nodeData.id) {
        _layoutService!.updateNodeRenderState(
          nodeId: previousSelectedId,
          renderState: 'rendering',
        );
      }
      // ...
    }
  }
}
```

---

## Bug 2: 空状态检查逻辑错误（中等）

### 文件
[sidebar_hook_renderer_simple.dart](file:///d:/Projects/node_graph_notebook/lib/plugins/sidebarNode/ui/sidebar_hook_renderer_simple.dart)

### 位置
`sidebar_hook_renderer_simple.dart:153-158` - `build` 方法

### 问题描述
空状态检查的顺序不正确：

```dart
@override
Widget build(BuildContext context) {
  // 获取节点数据
  final nodes = widget.hookContext.get<List<Object>>('nodes') ?? [];

  if (nodes.isEmpty) {  // 第153行：检查原始列表是否为空
    return _buildEmptyState(context);
  }

  // 转换为类型安全的NodeData
  final nodeDataList = nodes.whereType<NodeData>().toList();  // 第158行：过滤后可能为空
  // ...
}
```

### 根本原因
代码先检查 `nodes.isEmpty`，再进行类型过滤。如果 `nodes` 列表包含非 `NodeData` 类型的对象：
- `nodes.isEmpty` 返回 `false`，不会显示空状态
- 但 `nodeDataList` 可能为空，导致 `ListView.builder` 显示空白列表

### 对比
`sidebar_hook_renderer.dart` 的实现是正确的：

```dart
// 类型安全：过滤并转换节点数据
final nodeDataList = nodes.whereType<NodeData>().toList();

if (nodeDataList.isEmpty) {  // 先过滤，再检查
  return _buildEmptyState(context);
}
```

### 影响范围
- 仅影响 `sidebar_hook_renderer_simple.dart`
- 当传入非 `NodeData` 类型对象时，UI 可能显示异常

### 修复建议
将过滤操作移到空状态检查之前：

```dart
@override
Widget build(BuildContext context) {
  final nodes = widget.hookContext.get<List<Object>>('nodes') ?? [];
  
  // 先过滤，再检查
  final nodeDataList = nodes.whereType<NodeData>().toList();

  if (nodeDataList.isEmpty) {
    return _buildEmptyState(context);
  }
  // ...
}
```

---

## 总结

| Bug | 严重程度 | 文件 | 状态 |
|-----|---------|------|------|
| 节点高亮清除逻辑错误 | 严重 | 两个文件 | 待修复 |
| 空状态检查顺序错误 | 中等 | simple版本 | 待修复 |
