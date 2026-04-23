# Editor 模块 Bug 报告

审查日期: 2026-04-20  
审查范围: `lib/plugins/editor`

---

## 严重 Bug

### 1. 跨平台兼容性问题 - dart:io 在 Web 平台不可用

**文件**: [markdown_editor_page.dart:1](file:///d:/Projects/node_graph_notebook/lib/plugins/editor/ui/markdown_editor_page.dart#L1)

**问题描述**:
文件顶部导入了 `dart:io`，但该库在 Web 平台上不可用，会导致编译错误。

```dart
import 'dart:io';
```

**影响范围**:
- Web 平台无法编译此文件
- 任何使用 `MarkdownEditorPage` 或 `MarkdownViewer` 的功能在 Web 平台上都无法使用

**建议修复**:
使用条件导入或平台检测库（如 `universal_io` 或 `platform` 包）来处理跨平台兼容性。

---

### 2. 平台检测代码在 Web 平台会崩溃

**文件**: [markdown_editor_page.dart:467-473](file:///d:/Projects/node_graph_notebook/lib/plugins/editor/ui/markdown_editor_page.dart#L467-L473)

**问题描述**:
在 `_handleLinkClick` 方法中使用了 `Platform.isWindows`、`Platform.isMacOS`、`Platform.isLinux` 进行平台检测，这些 API 在 Web 平台上会抛出异常。

```dart
if (Platform.isWindows) {
  await Process.run('cmd', ['/c', 'start', '', uri.toString()]);
} else if (Platform.isMacOS) {
  await Process.run('open', [uri.toString()]);
} else if (Platform.isLinux) {
  await Process.run('xdg-open', [uri.toString()]);
}
```

**影响范围**:
- Web 平台上点击外部链接会导致应用崩溃
- 用户无法在 Web 版本中打开任何外部链接

**建议修复**:
使用 `url_launcher` 包来处理跨平台的 URL 打开，该包支持所有平台包括 Web。

---

## 中等 Bug

### 3. 不可靠的异步操作等待机制

**文件**: [markdown_editor_page.dart:354](file:///d:/Projects/node_graph_notebook/lib/plugins/editor/ui/markdown_editor_page.dart#L354)

**问题描述**:
在 `_saveNode` 方法中使用硬编码的 100ms 延迟来等待 Bloc 操作完成，这是不可靠的做法。

```dart
// 等待操作完成
await Future.delayed(const Duration(milliseconds: 100));

if (mounted) {
  Navigator.pop(context);
  // ...
}
```

**影响范围**:
- 如果 Bloc 操作耗时超过 100ms，用户会在操作完成前看到页面关闭
- 如果 Bloc 操作失败，用户不会收到错误提示
- 数据可能未正确保存就关闭了页面

**建议修复**:
使用 `BlocListener` 监听状态变化，或在 Bloc 中添加完成回调机制。

---

### 4. 类名冲突 - 重复定义 NodeEditorPanelHook

**文件**: 
- [node_editor_panel_hook.dart:40](file:///d:/Projects/node_graph_notebook/lib/plugins/editor/ui/node_editor_panel_hook.dart#L40)
- [node_editor_panel_hook_simple.dart:32](file:///d:/Projects/node_graph_notebook/lib/plugins/editor/ui/node_editor_panel_hook_simple.dart#L32)

**问题描述**:
两个文件定义了相同名称的 `NodeEditorPanelHook` 类，但 `editor_plugin.dart` 只导入了简化版本。

```dart
// editor_plugin.dart 第7行
import 'ui/node_editor_panel_hook_simple.dart';

// 第34行
List<HookFactory> registerHooks() => [
  NodeEditorPanelHook.new,
];
```

**影响范围**:
- 完整版的 `NodeEditorPanelHook`（包含拖拽功能）从未被使用
- 代码维护困难，容易混淆
- 可能导致开发者误以为使用了完整版功能

**建议修复**:
- 重命名其中一个类以避免冲突
- 或者删除未使用的版本
- 明确文档说明两个版本的区别和用途

---

## 低优先级 Bug

### 5. 类型转换可能失败

**文件**: [node_editor_panel_hook.dart:171-179](file:///d:/Projects/node_graph_notebook/lib/plugins/editor/ui/node_editor_panel_hook.dart#L171-L179)

**问题描述**:
代码假设 `nodeState.nodes` 中的元素实现了 `NodeEditorData` 接口，但没有类型检查。

```dart
final nodeDataList = nodeState.nodes.whereType<NodeEditorData>();
NodeEditorData? node;

for (final n in nodeDataList) {
  if (n.id == editingNodeId) {
    node = n;
    break;
  }
}
```

**影响范围**:
- 如果节点类未实现 `NodeEditorData` 接口，编辑功能将无法工作
- 不会抛出错误，但会静默失败

**建议修复**:
添加类型检查和错误日志，或确保所有节点类都实现了该接口。

---

### 6. HookContext.set 可能不支持 null 值

**文件**: [node_editor_panel_hook.dart:454](file:///d:/Projects/node_graph_notebook/lib/plugins/editor/ui/node_editor_panel_hook.dart#L454)

**问题描述**:
尝试将 `editingNodeId` 设置为 `null`，但不确定 `HookContext.set` 方法是否支持 null 值。

```dart
widget.hookContext.set('editingNodeId', null);
```

**影响范围**:
- 如果 `HookContext.set` 不支持 null，可能抛出异常
- 关闭编辑器功能可能失败

**建议修复**:
检查 `HookContext` 的实现，或使用 `remove` 方法（如果存在）来清除值。

---

## 总结

共发现 **6 个 Bug**：
- 严重: 2 个
- 中等: 2 个
- 低优先级: 2 个

**最紧急的问题**是跨平台兼容性问题，这会导致应用无法在 Web 平台上编译和运行。建议优先修复 Bug #1 和 #2。

**建议的修复优先级**:
1. Bug #1 和 #2 - 跨平台兼容性（使用 `url_launcher` 和条件导入）
2. Bug #3 - 异步操作等待机制（使用 BlocListener）
3. Bug #4 - 类名冲突（重命名或删除重复类）
4. Bug #5 和 #6 - 类型安全和 API 使用问题
