# Search 插件 Bug 报告

## Bug 1: 未使用的 NodeService 字段

**文件**: [search_bloc.dart:43-44](file:///d:/Projects/node_graph_notebook/lib/plugins/search/bloc/search_bloc.dart#L43-L44)

**严重程度**: 低

**问题描述**:
`SearchBloc` 中声明了 `_nodeService` 字段但从未使用，代码中使用了 `// ignore: unused_field` 注释来抑制警告。

```dart
// ignore: unused_field
final NodeService _nodeService;
```

**影响**:
- 代码冗余，增加维护成本
- 可能导致混淆，开发者可能误以为该服务在某处被使用

**建议修复**:
1. 如果确实不需要 `NodeService`，应删除该字段及其构造函数参数
2. 如果需要使用（例如作为备用搜索方式），应实现相关逻辑

---

## Bug 2: PopupMenuButton 预设选择功能不完整

**文件**: [search_sidebar_panel.dart:252-264](file:///d:/Projects/node_graph_notebook/lib/plugins/search/ui/search_sidebar_panel.dart#L252-L264)

**严重程度**: 高

**问题描述**:
`PopupMenuButton` 的实现存在两个问题：
1. `onSelected` 回调为空，即使选择了预设也不会执行任何操作
2. `itemBuilder` 只返回一个禁用的菜单项和分隔符，没有实际的预设选项

```dart
suffixIcon: _selectedPreset != null
    ? const Icon(Icons.star, color: Colors.amber)
    : PopupMenuButton<String>(
        icon: const Icon(Icons.star_border),
        tooltip: i18n.t('Saved searches'),
        onSelected: (presetId) {
          // 这个会在下面的 BlocBuilder 中处理
        },
        itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Text(i18n.t('Saved searches')),
            ),
            const PopupMenuDivider(),
          ],
      ),
```

**影响**:
- 用户无法通过星形图标的弹出菜单选择已保存的搜索预设
- 该功能完全不可用，用户只能通过下方的预设列表来加载预设

**建议修复**:
应该在 `itemBuilder` 中遍历 `state.presets` 并生成可点击的菜单项，同时在 `onSelected` 中调用 `_loadPreset` 方法。

---

## Bug 3: 保存预设的验证逻辑不完整

**文件**: [search_sidebar_panel.dart:102-107](file:///d:/Projects/node_graph_notebook/lib/plugins/search/ui/search_sidebar_panel.dart#L102-L107)

**严重程度**: 中

**问题描述**:
`_saveAsPreset` 方法只检查 `_searchController.text` 是否为空，但 `SearchQuery` 包含多个查询字段（titleQuery、contentQuery、tags）。如果用户只使用高级过滤器而没有输入主要搜索文本，验证会错误地阻止保存。

```dart
if (_searchController.text.trim().isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(i18n.t('Please enter a search query first'))),
  );
  return;
}
```

**影响**:
- 用户无法保存仅包含高级过滤器（标题、内容、标签）的搜索预设
- 功能不完整，限制了用户的使用场景

**建议修复**:
应该检查整个 `SearchQuery` 是否为空，而不是只检查主要搜索文本：
```dart
final query = SearchQuery(...);
if (query.isEmpty) {
  // 显示错误提示
  return;
}
```

---

## Bug 4: 更新预设时覆盖创建时间

**文件**: [save_search_preset_handler.dart:35-43](file:///d:/Projects/node_graph_notebook/lib/plugins/search/handler/save_search_preset_handler.dart#L35-L43)

**严重程度**: 中

**问题描述**:
当更新现有预设时（`command.id` 不为 null），处理器会创建一个新的 `SearchPreset` 并将 `createdAt` 设置为 `DateTime.now()`，这会覆盖原有的创建时间。

```dart
final preset = SearchPreset(
  id: command.id ?? _uuid.v4(),
  name: command.presetName,
  titleQuery: command.titleQuery,
  contentQuery: command.contentQuery,
  tags: command.tags,
  createdAt: DateTime.now(),  // 问题所在
  lastUsed: DateTime.now(),
);
```

**影响**:
- 更新预设后，原有的创建时间丢失
- 无法追踪预设的实际创建时间
- 预设排序可能受到影响（如果按创建时间排序）

**建议修复**:
更新预设时应该保留原有的 `createdAt`：
```dart
final existingPreset = command.id != null 
    ? await _service.getPreset(command.id!) 
    : null;

final preset = SearchPreset(
  id: command.id ?? _uuid.v4(),
  name: command.presetName,
  titleQuery: command.titleQuery,
  contentQuery: command.contentQuery,
  tags: command.tags,
  createdAt: existingPreset?.createdAt ?? DateTime.now(),
  lastUsed: DateTime.now(),
);
```

---

## Bug 5: SearchState.copyWith 无法将 currentQuery 设置为 null

**文件**: [search_state.dart:71-85](file:///d:/Projects/node_graph_notebook/lib/plugins/search/bloc/search_state.dart#L71-L85)

**严重程度**: 低

**问题描述**:
`copyWith` 方法中 `currentQuery` 参数类型为 `SearchQuery?`，但使用了 `?? this.currentQuery`，这意味着无法通过该方法将 `currentQuery` 设置为 `null`。

```dart
SearchState copyWith({
  // ...
  SearchQuery? currentQuery,
  // ...
}) => SearchState(
      // ...
      currentQuery: currentQuery ?? this.currentQuery,
      // ...
    );
```

**影响**:
- 当前在 `_onClear` 方法中通过直接创建新的 `SearchState` 绕过了这个问题
- 但这违反了使用 `copyWith` 的一致性原则
- 未来如果 `SearchState` 添加新字段，`_onClear` 方法可能会遗漏

**建议修复**:
使用可空包装器模式或添加一个 `clearCurrentQuery` 参数：
```dart
SearchState copyWith({
  // ...
  Object? currentQuery = _sentinel,
  // ...
}) => SearchState(
      // ...
      currentQuery: currentQuery == _sentinel 
          ? this.currentQuery 
          : currentQuery as SearchQuery?,
      // ...
    );
```
