# UI Bars 模块 Bug 报告

**审查日期**: 2026-04-21
**审查范围**: `lib/ui/bars` 文件夹

---

## Bug 1: NoteAppBarWidget 缺少响应式监听，钩子变更时不会重建（严重）

### 位置
- [note_app_bar.dart:17-38](file:///d:/Projects/node_graph_notebook/lib/ui/bars/note_app_bar.dart#L17-L38)

### 问题描述
`NoteAppBarWidget` 在 `build()` 方法中直接调用 `hookRegistry.getHookWrappers('main.toolbar')` 获取钩子列表，但没有使用 `AnimatedBuilder` / `ListenableBuilder` 监听 `hookRegistry`（`ChangeNotifier`）的变化。当钩子被动态注册或注销时，该组件**不会重建**，UI 将显示过时的工具栏内容。

### 问题代码
```dart
@override
Widget build(BuildContext context) {
  final hookWrappers = hookRegistry.getHookWrappers('main.toolbar');  // 直接读取，无监听

  return AppBar(
    title: const Text('Node Graph Notebook'),
    actions: [
      ...hookWrappers.map((hookWrapper) {
        // ...
      }).whereType<Widget>(),
    ],
  );
}
```

### 对比正确实现
同文件夹中的 [core_toolbar.dart](file:///d:/Projects/node_graph_notebook/lib/ui/bars/core_toolbar.dart#L23-L52) 正确使用了 `AnimatedBuilder`：

```dart
Widget _buildDefaultToolbar(BuildContext context) => AnimatedBuilder(
    animation: hookRegistry,  // 监听 hookRegistry 变化
    builder: (context, child) {
      final hookWrappers = hookRegistry.getHookWrappers('main.toolbar');
      // ...
    },
  );
```

### 影响
- 插件动态注册/注销工具栏钩子后，`NoteAppBarWidget` 不会反映变化
- 用户必须手动刷新页面才能看到新的工具栏按钮
- 与 `CoreToolbar` 行为不一致，可能导致不同页面出现不同的工具栏状态

### 修复建议
使用 `AnimatedBuilder` 包裹 `build` 内容，监听 `hookRegistry` 变化：

```dart
@override
Widget build(BuildContext context) {
  return AnimatedBuilder(
    animation: hookRegistry,
    builder: (context, child) {
      final hookWrappers = hookRegistry.getHookWrappers('main.toolbar');

      return AppBar(
        title: const Text('Node Graph Notebook'),
        actions: [
          ...hookWrappers.map((hookWrapper) {
            final hook = hookWrapper.hook;
            final hookContext = MainToolbarHookContext(
              data: {'buildContext': context},
              pluginContext: hookWrapper.parentPlugin?.context,
              hookAPIRegistry: hookRegistry.apiRegistry,
            );
            if (hook.isVisible(hookContext)) {
              return hook.render(hookContext);
            }
            return null;
          }).whereType<Widget>(),
        ],
      );
    },
  );
}
```

---

## Bug 2: _deleteSelectedNode 中 firstWhere 的 orElse 错误回退到第一个节点（严重）

### 位置
- [sidebar.dart:88-91](file:///d:/Projects/node_graph_notebook/lib/ui/bars/sidebar.dart#L88-L91)

### 问题描述
在 `_deleteSelectedNode()` 方法中，`firstWhere` 的 `orElse` 回退返回了 `nodeState.nodes.first`。当 `_selectedNodeId` 对应的节点不在当前列表中时（例如节点已被其他操作删除），代码会**错误地选中第一个节点**并弹出删除确认对话框，用户确认后会**删除错误的节点**。

### 问题代码
```dart
final node = nodeState.nodes.firstWhere(
  (n) => n.id == _selectedNodeId,
  orElse: () => nodeState.nodes.first,  // 危险！回退到第一个节点
);
```

### 影响
- 当选中节点已被外部删除时，用户会被提示删除一个完全无关的节点
- 如果用户不仔细阅读确认对话框内容，会误删第一个节点
- 数据丢失风险

### 修复建议
当找不到选中节点时，应提前返回而不是回退：

```dart
Future<void> _deleteSelectedNode() async {
  if (_selectedNodeId == null) return;

  final nodeBloc = context.read<NodeBloc>();
  final nodeState = nodeBloc.state;
  if (nodeState.nodes.isEmpty) return;

  final nodeIndex = nodeState.nodes.indexWhere((n) => n.id == _selectedNodeId);
  if (nodeIndex == -1) {
    // 选中节点已不存在，清除选中状态并返回
    setState(() {
      _selectedNodeId = null;
    });
    return;
  }
  final node = nodeState.nodes[nodeIndex];
  // ... 后续删除逻辑
}
```

---

## Bug 3: context.select 选择整个 state，与注释意图不符（中等）

### 位置
- [sidebar.dart:126-129](file:///d:/Projects/node_graph_notebook/lib/ui/bars/sidebar.dart#L126-L129)

### 问题描述
代码注释明确说明"只有当节点列表发生变化时才重建此组件"，但 `context.select` 实际选择了整个 `bloc.state` 对象。这意味着 Bloc 状态的**任何**变化（包括与节点列表无关的状态变更）都会触发组件重建，违背了细粒度订阅的设计意图。

### 问题代码
```dart
// 使用 context.select 进行细粒度状态订阅，避免不必要的重建
// 只有当节点列表发生变化时才重建此组件
final nodeState = context.select((NodeBloc bloc) => bloc.state);  // 选择了整个 state！
final allNodes = nodeState.nodes;
```

### 影响
- 当 NodeBloc 的非节点列表状态变化时（如加载状态、错误状态等），Sidebar 也会不必要地重建
- 在状态频繁变化的场景下，可能导致性能问题
- 注释与实现不一致，误导后续开发者

### 修复建议
如果只需要节点列表，应直接选择 `nodes`：

```dart
final allNodes = context.select((NodeBloc bloc) => bloc.state.nodes);
```

如果还需要其他状态字段，应分别选择：

```dart
final allNodes = context.select((NodeBloc bloc) => bloc.state.nodes);
final isLoading = context.select((NodeBloc bloc) => bloc.state.isLoading);
```

---

## Bug 4: _buildDefaultNodesTabHookWrapper 在 orElse 中每次创建新实例（中等）

### 位置
- [sidebar.dart:480-485](file:///d:/Projects/node_graph_notebook/lib/ui/bars/sidebar.dart#L480-L485)
- [sidebar.dart:512-522](file:///d:/Projects/node_graph_notebook/lib/ui/bars/sidebar.dart#L512-L522)

### 问题描述
`_buildTabContent` 方法中 `firstWhere` 的 `orElse` 回调指向 `_buildDefaultNodesTabHookWrapper`，该方法每次调用都会创建新的 `_DefaultNodesSidebarTabHook` 实例和 `HookLifecycleManager` 实例。由于 `_buildTabContent` 在每次 `build` 时都会被调用，当 `_selectedTabId` 不匹配任何已注册标签时，会**反复创建不必要的对象**。

### 问题代码
```dart
final selectedHookWrapper = tabHooks
    .where((hw) => hw.hook is SidebarTabHookBase)
    .firstWhere(
      (hw) => (hw.hook as SidebarTabHookBase).tabId == _selectedTabId,
      orElse: _buildDefaultNodesTabHookWrapper,  // 每次 build 都可能创建新实例
    );
```

```dart
HookWrapper _buildDefaultNodesTabHookWrapper() {
  final hook = _DefaultNodesSidebarTabHook();  // 每次创建新实例
  final lifecycle = HookLifecycleManager(hook.metadata.id)
    ..transitionTo(HookState.initialized, () async {});  // 每次创建新生命周期管理器
  return HookWrapper(
    hook,
    lifecycle,
    0,
    parentPlugin: null,
  );
}
```

### 影响
- 每次 Widget 重建时创建新的 Hook 和 Lifecycle 对象，增加 GC 压力
- `HookLifecycleManager.transitionTo` 被反复调用，可能导致生命周期状态不一致
- 与正常 Hook 的生命周期管理方式不一致（正常 Hook 只初始化一次）

### 修复建议
将默认 Hook 包装器缓存为类字段，只创建一次：

```dart
class _SidebarState extends State<Sidebar> {
  // ...

  HookWrapper? _defaultNodesTabHookWrapper;

  HookWrapper _getDefaultNodesTabHookWrapper() {
    return _defaultNodesTabHookWrapper ??= _createDefaultNodesTabHookWrapper();
  }

  HookWrapper _createDefaultNodesTabHookWrapper() {
    final hook = _DefaultNodesSidebarTabHook();
    final lifecycle = HookLifecycleManager(hook.metadata.id)
      ..transitionTo(HookState.initialized, () async {});
    return HookWrapper(hook, lifecycle, 0, parentPlugin: null);
  }
}
```

---

## Bug 5: CoreToolbar 与 NoteAppBarWidget 行为不一致（低）

### 位置
- [core_toolbar.dart:23-52](file:///d:/Projects/node_graph_notebook/lib/ui/bars/core_toolbar.dart#L23-L52)
- [note_app_bar.dart:17-38](file:///d:/Projects/node_graph_notebook/lib/ui/bars/note_app_bar.dart#L17-L38)

### 问题描述
两个组件功能高度重叠（都是主工具栏），但实现行为存在多处不一致：

| 行为 | CoreToolbar | NoteAppBarWidget |
|------|-------------|------------------|
| 响应式监听 | 使用 `AnimatedBuilder` | 无监听（Bug 1） |
| 钩子渲染顺序 | `.reversed`（反转） | 原始顺序 |
| 调试日志 | 包含 `_log.info` 和 `debugPrint` | 无 |

### 影响
- 不同页面使用不同工具栏组件时，工具栏按钮顺序不一致
- 反转逻辑只在 `CoreToolbar` 中存在，可能导致插件开发者困惑
- 维护两份功能相同的代码增加了出错概率

### 修复建议
统一为一个组件，消除重复代码。如果确实需要两个变体，应提取公共逻辑到基类或工具方法中，确保行为一致。

---

## Bug 6: _selectedTabId 在钩子动态注销后可能变为悬空引用（低）

### 位置
- [sidebar.dart:41](file:///d:/Projects/node_graph_notebook/lib/ui/bars/sidebar.dart#L41)
- [sidebar.dart:480-485](file:///d:/Projects/node_graph_notebook/lib/ui/bars/sidebar.dart#L480-L485)

### 问题描述
`_selectedTabId` 在 `initState` 中初始化后，不会随钩子注册表的变化而更新。如果当前选中的标签页钩子被动态注销，`_selectedTabId` 将引用一个不存在的标签 ID。虽然 `firstWhere` 的 `orElse` 会回退到默认标签，但这会导致：

1. 每次重建都创建新的默认 Hook 包装器（Bug 4）
2. 用户看到的标签页突然切换到默认标签，没有明确的反馈

### 影响
- 插件热加载/卸载场景下，侧边栏标签页状态可能异常
- 用户体验不连贯

### 修复建议
监听 `hookRegistry` 变化，当当前选中的标签被注销时自动切换到有效标签：

```dart
@override
void initState() {
  super.initState();
  _selectedTabId = _getDefaultTabId();
  hookRegistry.addListener(_onHookRegistryChanged);
}

void _onHookRegistryChanged() {
  final tabHooks = hookRegistry.getHookWrappers('sidebar.tab');
  final validTabIds = tabHooks
      .where((hw) => hw.hook is SidebarTabHookBase)
      .map((hw) => (hw.hook as SidebarTabHookBase).tabId)
      .toSet();

  if (_selectedTabId != null && !validTabIds.contains(_selectedTabId)) {
    setState(() {
      _selectedTabId = validTabIds.isNotEmpty ? validTabIds.first : 'nodes';
    });
  }
}

@override
void dispose() {
  hookRegistry.removeListener(_onHookRegistryChanged);
  _focusNode.dispose();
  _editFocusNode.dispose();
  _editController.dispose();
  super.dispose();
}
```

---

## 总结

| Bug ID | 严重程度 | 文件 | 问题类型 |
|--------|----------|------|----------|
| Bug 1 | 严重 | note_app_bar.dart | 缺少响应式监听 |
| Bug 2 | 严重 | sidebar.dart | 错误回退导致误删节点 |
| Bug 3 | 中等 | sidebar.dart | 状态订阅粒度过粗 |
| Bug 4 | 中等 | sidebar.dart | orElse 中反复创建对象 |
| Bug 5 | 低 | core_toolbar.dart / note_app_bar.dart | 行为不一致 |
| Bug 6 | 低 | sidebar.dart | 悬空标签引用 |

### 优先级建议
1. **Bug 2** 应最优先修复，存在数据丢失风险，用户可能误删无关节点
2. **Bug 1** 应尽快修复，动态钩子系统是核心功能，缺少响应式监听会导致 UI 不更新
3. **Bug 3 & 4** 建议在下一个迭代中修复，影响性能和代码质量
4. **Bug 5 & 6** 可作为技术债务在后续版本中处理
