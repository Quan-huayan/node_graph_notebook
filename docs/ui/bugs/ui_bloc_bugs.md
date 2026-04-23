# UI BLoC 模块 Bug 报告

**审查日期**: 2026-04-21  
**审查范围**: `lib/ui/bloc` 文件夹（`ui_bloc.dart`、`ui_event.dart`、`ui_state.dart`）

---

## Bug 1: `_onSetDefaultViewMode` 与 `_onSetNodeViewMode` 行为完全相同

### 位置
- [ui_bloc.dart:33-38](file:///d:/Projects/node_graph_notebook/lib/ui/bloc/ui_bloc.dart#L33-L38)

### 问题描述
`_onSetDefaultViewMode` 处理器的实现与 `_onSetNodeViewMode` 完全一致，都是设置 `state.copyWith(nodeViewMode: event.mode)`。"默认视图模式"本应是一个独立的持久化设置，与"当前视图模式"是两个不同的概念，但当前实现将两者混为一谈。

### 问题代码
```dart
// 设置节点显示模式
void _onSetNodeViewMode(UISetNodeViewModeEvent event, Emitter<UIState> emit) {
  emit(state.copyWith(nodeViewMode: event.mode));
}

// 设置默认节点显示模式
void _onSetDefaultViewMode(
  UISetDefaultViewModeEvent event,
  Emitter<UIState> emit,
) {
  emit(state.copyWith(nodeViewMode: event.mode));  // <-- 与上面完全相同
}
```

### 影响
- 用户在设置对话框中选择"默认视图模式"时，实际上修改的是当前视图模式
- 无法保存和恢复独立的默认视图模式设置
- `UISetDefaultViewModeEvent` 和 `UISetNodeViewModeEvent` 功能重复，调用者无法区分两者行为

### 修复建议
`UIState` 需要新增 `defaultNodeViewMode` 字段，`_onSetDefaultViewMode` 应修改该字段而非 `nodeViewMode`：

```dart
// ui_state.dart
const UIState({
  required this.nodeViewMode,
  required this.defaultNodeViewMode,  // 新增
  // ...
});

// ui_bloc.dart
void _onSetDefaultViewMode(
  UISetDefaultViewModeEvent event,
  Emitter<UIState> emit,
) {
  emit(state.copyWith(defaultNodeViewMode: event.mode));
}
```

---

## Bug 2: `defaultViewMode` getter 只是 `nodeViewMode` 的别名

### 位置
- [ui_state.dart:61](file:///d:/Projects/node_graph_notebook/lib/ui/bloc/ui_state.dart#L61)

### 问题描述
`UIState` 中的 `defaultViewMode` getter 直接返回 `nodeViewMode`，而不是一个独立的默认值字段。这使得"默认视图模式"与"当前视图模式"无法区分。

### 问题代码
```dart
NodeViewMode get defaultViewMode => nodeViewMode;
```

### 影响
- 设置对话框（[settings_dialog.dart:124](file:///d:/Projects/node_graph_notebook/lib/ui/dialogs/settings_dialog.dart#L124)）中显示的"默认视图模式"实际是当前视图模式
- 用户无法查看或设置与当前模式不同的默认模式
- 该 getter 提供了错误语义，让调用者误以为存在独立的默认值

### 修复建议
移除该 getter，改为在 `UIState` 中添加独立的 `defaultNodeViewMode` 字段：

```dart
final NodeViewMode defaultNodeViewMode;
```

---

## Bug 3: 设置对话框使用 `nodeViewMode` 初始化"默认视图模式"选择器

### 位置
- [settings_dialog.dart:193](file:///d:/Projects/node_graph_notebook/lib/ui/dialogs/settings_dialog.dart#L193)

### 问题描述
在 `_showViewModeSelector` 方法中，使用 `uiBloc.state.nodeViewMode`（当前视图模式）作为"默认视图模式"选择器的初始选中值，而非使用独立的默认视图模式。

### 问题代码
```dart
void _showViewModeSelector(BuildContext context) {
  final uiBloc = context.read<UIBloc>();
  final currentMode = uiBloc.state.nodeViewMode;  // <-- 应该使用 defaultNodeViewMode
  // ...
  RadioGroup<NodeViewMode>(
    groupValue: currentMode,  // <-- 显示的是当前模式，不是默认模式
    // ...
  ),
}
```

### 影响
- 用户打开"默认视图模式"选择器时，看到的是当前视图模式被选中，而非之前保存的默认模式
- 如果当前模式与默认模式不同，用户会被误导
- 此 Bug 与 Bug 1、Bug 2 相关联，根因是 `UIState` 缺少独立的 `defaultNodeViewMode` 字段

### 修复建议
```dart
final currentMode = uiBloc.state.defaultNodeViewMode;
```

---

## Bug 4: `UIBloc` 未从 `SettingsService` 加载已保存的默认视图模式

### 位置
- [ui_bloc.dart:10](file:///d:/Projects/node_graph_notebook/lib/ui/bloc/ui_bloc.dart#L10)

### 问题描述
`UIBloc` 构造函数使用 `UIState.initial()` 初始化状态，其中 `nodeViewMode` 硬编码为 `NodeViewMode.titleWithPreview`。即使 `SettingsService` 中已经保存了用户的默认视图模式偏好（参见 [app.dart:222-229](file:///d:/Projects/node_graph_notebook/lib/app.dart#L222-L229) 中的 `core.defaultViewMode` 设置注册），`UIBloc` 也不会读取该值。

### 问题代码
```dart
UIBloc() : super(UIState.initial()) {
```

`UIState.initial()` 中的硬编码值：
```dart
factory UIState.initial() => const UIState(
  nodeViewMode: NodeViewMode.titleWithPreview,  // <-- 硬编码，未读取用户设置
  // ...
);
```

### 影响
- 用户每次启动应用时，视图模式都会重置为 `titleWithPreview`
- 即使之前在设置中选择了不同的默认视图模式，也不会被应用
- `SettingsService` 中的 `core.defaultViewMode` 设置形同虚设

### 修复建议
`UIBloc` 应接受 `SettingsService` 依赖，在初始化时加载已保存的设置：

```dart
UIBloc({required SettingsService settingsService})
    : super(UIState.fromSettings(settingsService)) {
  // ...
}
```

或者通过事件机制在 `UIBloc` 创建后立即加载设置。

---

## Bug 5: `copyWith` 中 `bool?` 参数无法区分"未传入"与"传入 false"

### 位置
- [ui_state.dart:66-82](file:///d:/Projects/node_graph_notebook/lib/ui/bloc/ui_state.dart#L66-L82)

### 问题描述
`copyWith` 方法对 `bool` 类型字段使用了可空参数（`bool?`），通过 `??` 运算符提供默认值。这种模式在当前代码中恰好能工作（因为所有调用点都显式传入了 `true`/`false`），但这是一个已知的 BLoC 反模式，会在未来引发 bug。

### 问题代码
```dart
UIState copyWith({
  bool? showConnections,    // <-- 无法区分"未传入"和"传入 false"
  bool? isSidebarOpen,      // <-- 同上
  bool? isToolbarExpanded,  // <-- 同上
}) => UIState(
  showConnections: showConnections ?? this.showConnections,
  isSidebarOpen: isSidebarOpen ?? this.isSidebarOpen,
  isToolbarExpanded: isToolbarExpanded ?? this.isToolbarExpanded,
);
```

### 影响
- 当前代码中所有调用点都显式传入布尔值，所以暂时不会出错
- 但如果未来有人想通过 `copyWith` 将某个布尔字段设为 `false`，可能会因为疏忽而传入 `null`（即不传参），导致字段保持原值而非被设为 `false`
- 这是 BLoC 模式中常见的 bug 来源

### 修复建议
使用包装类或单独的 `copyWith` 变体来处理布尔字段的重置。一种常见方案：

```dart
UIState copyWith({
  NodeViewMode? nodeViewMode,
  BackgroundStyle? backgroundStyle,
  String? selectedTab,
  double? sidebarWidth,
  bool? showConnections,
  bool? isSidebarOpen,
  bool? isToolbarExpanded,
}) {
  return UIState(
    nodeViewMode: nodeViewMode ?? this.nodeViewMode,
    showConnections: showConnections ?? this.showConnections,
    backgroundStyle: backgroundStyle ?? this.backgroundStyle,
    isSidebarOpen: isSidebarOpen ?? this.isSidebarOpen,
    selectedTab: selectedTab ?? this.selectedTab,
    sidebarWidth: sidebarWidth ?? this.sidebarWidth,
    isToolbarExpanded: isToolbarExpanded ?? this.isToolbarExpanded,
  );
}
```

或者更严格地，为每个布尔字段提供独立的 `copyWithXxx` 方法。

---

## 总结

| Bug ID | 严重程度 | 文件 | 问题类型 |
|--------|----------|------|----------|
| Bug 1 | 高 | ui_bloc.dart | 逻辑错误：默认模式与当前模式处理相同 |
| Bug 2 | 高 | ui_state.dart | 设计缺陷：getter 语义错误 |
| Bug 3 | 中 | settings_dialog.dart | 数据源错误：使用当前模式初始化默认模式选择器 |
| Bug 4 | 高 | ui_bloc.dart | 功能缺失：未加载已保存的用户设置 |
| Bug 5 | 低 | ui_state.dart | 潜在风险：copyWith 布尔参数反模式 |

### 优先级建议
1. **Bug 1、2、3、4** 应作为一组优先修复——它们共同构成了"默认视图模式"功能的系统性缺陷。根因是 `UIState` 缺少独立的 `defaultNodeViewMode` 字段，且 `UIBloc` 未与 `SettingsService` 集成
2. **Bug 5** 建议在下次重构时一并处理，当前不会造成运行时错误，但属于技术债务
