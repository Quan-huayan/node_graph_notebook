# Graph 模块 Bug 报告

**审查日期**: 2026-04-20  
**审查范围**: `lib/core/graph` 文件夹

---

## Bug 1: QuadTree.update() 方法状态不一致

**严重程度**: 高 (数据完整性问题)

**位置**: [quad_tree.dart:229-240](file:///d:/Projects/node_graph_notebook/lib/core/graph/spatial/quad_tree.dart#L229-L240)

**问题描述**:  
`update` 方法先调用 `remove` 移除旧位置的项，然后更新项的位置，最后调用 `insert` 插入新位置。如果 `insert` 失败（例如位置超出边界），项的位置已经被更新，但项不在树中，导致状态不一致。

**问题代码**:
```dart
bool update(QuadTreeItem item, Vector2 newPosition) {
  // 移除旧位置
  if (!remove(item)) {
    return false;
  }

  // 更新位置
  item.position = newPosition;  // 位置已更新

  // 插入新位置
  return insert(item);  // 如果失败，item 不在树中但位置已改变
}
```

**影响**:  
- 如果新位置超出边界，项会从树中丢失
- 项的位置状态与树中的位置不一致
- 可能导致后续查询找不到该项

**修复建议**:
```dart
bool update(QuadTreeItem item, Vector2 newPosition) {
  // 先检查新位置是否有效
  if (!bounds.containsVector2(newPosition)) {
    return false;
  }
  
  // 移除旧位置
  if (!remove(item)) {
    return false;
  }

  // 更新位置
  item.position = newPosition;

  // 插入新位置（此时应该不会失败）
  final success = insert(item);
  if (!success) {
    // 恢复原位置（防御性编程）
    item.position = item.position;  // 无法恢复，因为旧位置已丢失
  }
  
  return success;
}
```

或者更好的方案是保存旧位置：
```dart
bool update(QuadTreeItem item, Vector2 newPosition) {
  final oldPosition = item.position;
  
  // 移除旧位置
  if (!remove(item)) {
    return false;
  }

  // 更新位置
  item.position = newPosition;

  // 插入新位置
  final success = insert(item);
  if (!success) {
    // 恢复旧位置
    item.position = oldPosition;
    insert(item);  // 重新插入到旧位置
    return false;
  }
  
  return true;
}
```

---

## Bug 2: AdjacencyList.removeNode() 效率问题

**严重程度**: 中 (性能问题)

**位置**: [adjacency_list.dart:120-136](file:///d:/Projects/node_graph_notebook/lib/core/graph/adjacency_list.dart#L120-L136)

**问题描述**:  
`removeNode` 方法遍历所有出边和入边来移除节点引用，时间复杂度为 O(E)，其中 E 是边数。对于大型图，这可能成为性能瓶颈。

**问题代码**:
```dart
void removeNode(String nodeId) {
  // 删除所有出边
  _outgoingEdges.remove(nodeId);

  // 删除所有入边
  _incomingEdges.remove(nodeId);

  // 从其他节点的出边中移除此节点 - O(E)
  for (final edges in _outgoingEdges.values) {
    edges.remove(nodeId);
  }

  // 从其他节点的入边中移除此节点 - O(E)
  for (final edges in _incomingEdges.values) {
    edges.remove(nodeId);
  }
}
```

**影响**:  
- 删除节点操作效率低
- 大型图中可能影响用户体验

**修复建议**:  
利用已有的入边和出边索引来优化：
```dart
void removeNode(String nodeId) {
  // 获取该节点的所有入边邻居
  final incomingNeighbors = _incomingEdges[nodeId];
  if (incomingNeighbors != null) {
    for (final neighbor in incomingNeighbors) {
      _outgoingEdges[neighbor]?.remove(nodeId);
    }
  }

  // 获取该节点的所有出边邻居
  final outgoingNeighbors = _outgoingEdges[nodeId];
  if (outgoingNeighbors != null) {
    for (final neighbor in outgoingNeighbors) {
      _incomingEdges[neighbor]?.remove(nodeId);
    }
  }

  // 删除节点本身
  _outgoingEdges.remove(nodeId);
  _incomingEdges.remove(nodeId);
}
```

这样时间复杂度从 O(E) 降低到 O(d)，其中 d 是节点的度数。

---

## Bug 3: QuadTree._subdivide() 后项目可能丢失

**严重程度**: 中 (数据完整性问题)

**位置**: [quad_tree.dart:148-152](file:///d:/Projects/node_graph_notebook/lib/core/graph/spatial/quad_tree.dart#L148-L152)

**问题描述**:  
在 `_subdivide` 方法中，将现有项目重新分配到子节点时，如果某个项目无法插入到任何子节点（例如位于边界线上），它会被保留在当前节点。但代码先清空了 `_items`，然后逐个插入，如果插入失败，项目就会丢失。

**问题代码**:
```dart
// 将现有项目重新分配到子节点
final itemsToRedistribute = List<QuadTreeItem>.from(_items);
_items.clear();  // 先清空

itemsToRedistribute.forEach(insert);  // 如果 insert 失败，项目丢失
```

**影响**:  
- 位于边界上的项目可能丢失
- 空间索引不完整

**修复建议**:
```dart
// 将现有项目重新分配到子节点
final itemsToRedistribute = List<QuadTreeItem>.from(_items);
_items.clear();

for (final item in itemsToRedistribute) {
  if (!insert(item)) {
    // 如果无法插入到子节点，保留在当前节点
    _items.add(item);
  }
}
```

---

## Bug 4: GraphPartitioner 分区边界处理

**严重程度**: 低 (边界条件)

**位置**: [graph_partitioner.dart](file:///d:/Projects/node_graph_notebook/lib/core/graph/partition/graph_partitioner.dart)

**问题描述**:  
当节点恰好位于分区边界线上时，可能被分配到多个分区或没有任何分区。

**影响**:  
- 边界节点可能重复或丢失
- 跨分区查询可能返回不完整结果

**修复建议**:  
明确定义边界节点的归属规则，例如统一归属到左/上分区。

---

## 总结

| Bug ID | 严重程度 | 文件 | 问题类型 |
|--------|----------|------|----------|
| Bug 1 | 高 | quad_tree.dart | 数据完整性 |
| Bug 2 | 中 | adjacency_list.dart | 性能问题 |
| Bug 3 | 中 | quad_tree.dart | 数据完整性 |
| Bug 4 | 低 | graph_partitioner.dart | 边界条件 |

**建议优先级**:  
1. Bug 1 应立即修复，因为它会导致数据丢失
2. Bug 2 和 Bug 3 应尽快修复，以提高性能和数据完整性
3. Bug 4 可以在后续版本中处理
