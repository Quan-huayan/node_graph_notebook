# UI Pages Bug 报告

**审查日期**: 2026-04-21  
**审查范围**: `lib/ui/pages` 文件夹

---

## Bug 1: GlobalMessageService.setContext() 在 build() 中调用，存储了可能失效的 BuildContext

### 位置
- [home_page.dart:31](file:///d:/Projects/node_graph_notebook/lib/ui/pages/home_page.dart#L31)

### 严重程度
**高**

### 问题描述
`GlobalMessageService.setContext(context)` 在 `build()` 方法中被调用。`build()` 方法在 widget 的每次重建时都会执行，而 `GlobalMessageService` 是一个纯静态工具类，将 `BuildContext` 存储在静态变量 `_context` 中。

这存在两个严重问题：

1. **存储的 context 可能已失效**：当 `HomePage` 被 dispose 后，其 `BuildContext` 将不再有效。但 `GlobalMessageService._context` 仍然持有该引用。此后如果 Lua 插件通过 `showMessage()`/`showWarning()`/`showError()` 使用这个失效的 context，将导致运行时崩溃。

2. **在 build() 中执行副作用**：`build()` 方法应该是纯函数，不应产生副作用。在 `build()` 中修改全局静态状态违反了 Flutter 的设计原则，可能导致不可预期的行为。

### 问题代码
```dart
@override
Widget build(BuildContext context) {
  // ✅ 设置全局消息服务的 context
  GlobalMessageService.setContext(context);  // 危险：存储可能失效的 context

  return Scaffold(
    appBar: const CoreToolbar(),
    body: _buildBody(),
  );
}
```

### 影响
- 当 `HomePage` 被销毁后，`GlobalMessageService` 持有的 context 失效
- Lua 插件调用 `GlobalMessageService.showMessage()`/`showWarning()`/`showError()` 时，使用失效的 `ScaffoldMessenger.of(_context!)` 会抛出异常
- 在某些导航场景下（如页面切换），可能导致应用崩溃

### 修复建议

使用 `NavigatorState` 或 `GlobalKey<NavigatorState>` 代替直接存储 `BuildContext`，或者在 `initState`/`didChangeDependencies` 中设置，并在 `dispose` 中清除：

```dart
class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalMessageService.setContext(context);
    });
  }

  @override
  void dispose() {
    GlobalMessageService.setContext(null);  // 清除失效的 context
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CoreToolbar(),
      body: _buildBody(),
    );
  }
}
```

更优方案是修改 `GlobalMessageService` 使其存储 `GlobalKey<NavigatorState>` 或 `ScaffoldMessengerState`，而非 `BuildContext`。

---

## Bug 2: 未处理 GraphState 的加载和错误状态

### 位置
- [home_page.dart:39-86](file:///d:/Projects/node_graph_notebook/lib/ui/pages/home_page.dart#L39-L86)

### 严重程度
**中**

### 问题描述
`HomePage._buildBody()` 使用 `BlocBuilder<GraphBloc, GraphState>` 监听图状态，但完全没有处理 `GraphState.loadingState`。当图处于 `LoadingState.initial` 或 `LoadingState.loading` 状态时，`graphState.hasGraph` 为 `false`，此时：
- 侧边栏不会显示（因为 `uiState.isSidebarOpen && graphState.hasGraph` 为 `false`）
- `GraphView` 会在没有图数据的情况下渲染，可能导致空状态或错误

同样，当 `graphState.hasError` 为 `true` 时，没有任何错误提示展示给用户。

### 问题代码
```dart
Widget _buildBody() => BlocBuilder<GraphBloc, GraphState>(
    builder: (context, graphState) => BlocBuilder<NodeBloc, NodeState>(
      builder: (context, nodeState) => BlocBuilder<UIBloc, UIState>(
        builder: (context, uiState) => Row(
          // 直接渲染，没有检查 loadingState 或 error
          children: [
            if (uiState.isSidebarOpen && graphState.hasGraph)
              // ...
            const Expanded(
              child: GraphView(),
            ),
          ],
        ),
      ),
    ),
  );
```

### 影响
- 应用启动时，用户可能短暂看到空白界面，没有任何加载指示
- 图加载失败时，用户看不到任何错误信息，无法知道发生了什么
- `GraphView` 在无图数据时可能渲染异常或显示空白

### 修复建议

添加加载和错误状态的处理：

```dart
Widget _buildBody() => BlocBuilder<GraphBloc, GraphState>(
    builder: (context, graphState) {
      if (graphState.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      if (graphState.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(graphState.error ?? 'Unknown error'),
              ElevatedButton(
                onPressed: () => context.read<GraphBloc>().add(RetryEvent()),
                child: Text(I18n.of(context).t('Retry')),
              ),
            ],
          ),
        );
      }

      return BlocBuilder<NodeBloc, NodeState>(
        builder: (context, nodeState) => BlocBuilder<UIBloc, UIState>(
          builder: (context, uiState) => Row(
            children: [
              // ...
            ],
          ),
        ),
      );
    },
  );
```

---

## Bug 3: 三层嵌套 BlocBuilder 缺少 buildWhen 条件，导致不必要的重建

### 位置
- [home_page.dart:39-86](file:///d:/Projects/node_graph_notebook/lib/ui/pages/home_page.dart#L39-L86)

### 严重程度
**低**

### 问题描述
`_buildBody()` 中使用了三层嵌套的 `BlocBuilder`，且都没有指定 `buildWhen` 参数。这意味着：

- 当 `NodeState` 的任何字段变化时（如 `selectedNode` 变化），即使 `nodes` 列表未变，也会触发整个 body 重建
- 当 `UIState` 的任何字段变化时（如 `isToolbarExpanded` 变化），即使 `isSidebarOpen` 和 `sidebarWidth` 未变，也会触发重建
- 当 `GraphState` 的任何字段变化时（如 `selectionState` 变化），即使 `graph` 和 `hasGraph` 未变，也会触发重建

三层嵌套意味着任何一个 BLoC 的任何状态变化都会导致整个 body（包括 `Sidebar` 和 `GraphView`）重建。

### 问题代码
```dart
Widget _buildBody() => BlocBuilder<GraphBloc, GraphState>(  // 无 buildWhen
    builder: (context, graphState) => BlocBuilder<NodeBloc, NodeState>(  // 无 buildWhen
      builder: (context, nodeState) => BlocBuilder<UIBloc, UIState>(  // 无 buildWhen
        builder: (context, uiState) => Row(
          children: [ /* ... */ ],
        ),
      ),
    ),
  );
```

### 影响
- 频繁的不必要重建，影响性能
- 在低端设备上可能导致界面卡顿
- `Sidebar` 和 `GraphView` 在不相关的状态变化时被重建

### 修复建议

为每个 `BlocBuilder` 添加 `buildWhen` 条件，仅监听相关字段的变化：

```dart
Widget _buildBody() => BlocBuilder<GraphBloc, GraphState>(
    buildWhen: (prev, curr) =>
        prev.graph != curr.graph ||
        prev.hasGraph != curr.hasGraph,
    builder: (context, graphState) => BlocBuilder<NodeBloc, NodeState>(
      buildWhen: (prev, curr) => prev.nodes != curr.nodes,
      builder: (context, nodeState) => BlocBuilder<UIBloc, UIState>(
        buildWhen: (prev, curr) =>
            prev.isSidebarOpen != curr.isSidebarOpen ||
            prev.sidebarWidth != curr.sidebarWidth,
        builder: (context, uiState) => Row(
          children: [ /* ... */ ],
        ),
      ),
    ),
  );
```

---

## Bug 4: 侧边栏拖拽调整宽度时每个像素都触发事件，缺少节流

### 位置
- [home_page.dart:57-62](file:///d:/Projects/node_graph_notebook/lib/ui/pages/home_page.dart#L57-L62)

### 严重程度
**低**

### 问题描述
`GestureDetector.onPanUpdate` 在拖拽过程中，每移动一个像素就会触发一次 `UISetSidebarWidthEvent`。每次事件都会导致 `UIBloc` 发射新状态，进而触发整个 `_buildBody()` 重建。

在快速拖拽时，这会产生大量事件（每秒可能数百次），每次都触发三层嵌套 `BlocBuilder` 的重建，可能导致界面卡顿。

### 问题代码
```dart
GestureDetector(
  onPanUpdate: (details) {
    final newWidth = uiState.sidebarWidth + details.delta.dx;
    context.read<UIBloc>().add(
      UISetSidebarWidthEvent(newWidth),  // 每像素触发一次
    );
  },
  // ...
)
```

### 影响
- 拖拽时大量事件涌入 BLoC，造成不必要的重建
- 在低端设备上可能导致拖拽不流畅
- 三层嵌套 BlocBuilder 放大了性能问题

### 修复建议

使用 `onPanEnd` 仅在拖拽结束时发送最终宽度，或使用节流（throttle）限制事件频率：

```dart
double _dragWidth = 0;

GestureDetector(
  onPanStart: (details) {
    _dragWidth = uiState.sidebarWidth;
  },
  onPanUpdate: (details) {
    setState(() {
      _dragWidth = (_dragWidth + details.delta.dx).clamp(150.0, 500.0);
    });
  },
  onPanEnd: (details) {
    context.read<UIBloc>().add(
      UISetSidebarWidthEvent(_dragWidth),
    );
  },
  child: /* ... */,
)
```

---

## Bug 5: 插件数据在 itemBuilder 中重复创建

### 位置
- [plugin_market_page.dart:48-84](file:///d:/Projects/node_graph_notebook/lib/ui/pages/plugin_market_page.dart#L48-L84)

### 严重程度
**低**

### 问题描述
`_buildPluginCard` 方法中，`plugins` 列表定义在方法体内。由于 `_buildPluginCard` 是 `ListView.builder` 的 `itemBuilder`，它会被调用 `itemCount` 次（当前为 5 次）。这意味着 `plugins` 列表及其包含的 5 个 `Map` 对象会被创建 5 次，共 25 个 `Map` 实例。

### 问题代码
```dart
Widget _buildPluginCard(BuildContext context, int index) {
    final i18n = I18n.of(context);
    // 示例插件数据
    final plugins = [  // 每次调用 _buildPluginCard 都会重新创建
      {
        'nameKey': 'Markdown Enhancer',
        // ... 5 个插件项
      },
    ];

    final plugin = plugins[index];
    // ...
}
```

### 影响
- 不必要的内存分配和 GC 压力
- 代码逻辑上不清晰——数据应该只创建一次

### 修复建议

将 `plugins` 列表提升为类级别的静态常量或字段：

```dart
class PluginMarketPage extends StatelessWidget {
  const PluginMarketPage({super.key});

  static const _plugins = [
    {
      'nameKey': 'Markdown Enhancer',
      'descriptionKey': 'Enhanced markdown editing with advanced features',
      'version': '1.0.0',
      'author': 'Plugin Developer',
      'icon': Icons.text_format,
    },
    // ...
  ];

  @override
  Widget build(BuildContext context) {
    // ...
    Expanded(
      child: ListView.builder(
        itemCount: _plugins.length,
        itemBuilder: _buildPluginCard,
      ),
    ),
    // ...
  }

  Widget _buildPluginCard(BuildContext context, int index) {
    final plugin = _plugins[index];
    // ...
  }
}
```

---

## Bug 6: i18n.t() 传入的是显示文本而非翻译键

### 位置
- [plugin_market_page.dart:87-88](file:///d:/Projects/node_graph_notebook/lib/ui/pages/plugin_market_page.dart#L87-L88)
- [plugin_market_page.dart:50-83](file:///d:/Projects/node_graph_notebook/lib/ui/pages/plugin_market_page.dart#L50-L83)

### 严重程度
**中**

### 问题描述
`plugins` 列表中的 `nameKey` 和 `descriptionKey` 字段存储的是英文显示文本（如 `'Markdown Enhancer'`、`'Enhanced markdown editing with advanced features'`），而非翻译键（如 `'plugin.markdown_enhancer.name'`）。这些值随后被传入 `i18n.t()` 进行翻译。

`i18n.t()` 的查找顺序是：动态翻译 > 静态翻译 > 原文本回退。由于这些英文文本不是有效的翻译键，`i18n.t()` 永远找不到对应的翻译条目，总是回退到原文本。这使得国际化完全失效——即使用户切换到中文，插件名称和描述仍然显示英文。

### 问题代码
```dart
final plugins = [
  {
    'nameKey': 'Markdown Enhancer',           // 这是显示文本，不是翻译键
    'descriptionKey': 'Enhanced markdown editing with advanced features',  // 同上
    // ...
  },
  // ...
];

final pluginName = i18n.t(plugin['nameKey'] as String);           // 永远返回原文本
final pluginDescription = i18n.t(plugin['descriptionKey'] as String);  // 永远返回原文本
```

### 影响
- 国际化功能对插件名称和描述完全失效
- 切换语言后，插件名称和描述仍然显示英文
- 字段名 `nameKey`/`descriptionKey` 暗示它们应该是翻译键，但实际值与命名意图不符

### 修复建议

使用规范的翻译键格式：

```dart
final plugins = [
  {
    'nameKey': 'plugin.market.markdown_enhancer.name',
    'descriptionKey': 'plugin.market.markdown_enhancer.description',
    'version': '1.0.0',
    'author': 'Plugin Developer',
    'icon': Icons.text_format,
  },
  // ...
];
```

并在翻译文件中添加对应的翻译条目。

---

## Bug 7: itemCount 硬编码为 5，与数据源不同步

### 位置
- [plugin_market_page.dart:34](file:///d:/Projects/node_graph_notebook/lib/ui/pages/plugin_market_page.dart#L34)

### 严重程度
**中**

### 问题描述
`ListView.builder` 的 `itemCount` 被硬编码为 `5`，而插件数据列表也恰好包含 5 项。如果未来有人修改了插件列表（增加或删除项），`itemCount` 不会自动更新，可能导致：
- 列表项增加时，新增的插件不会显示
- 列表项减少时，访问 `plugins[index]` 会抛出 `RangeError`

### 问题代码
```dart
Expanded(
  child: ListView.builder(
    itemCount: 5,  // 硬编码，与 plugins 列表长度不同步
    itemBuilder: _buildPluginCard,
  ),
),
```

### 影响
- 数据与显示不同步的风险
- 维护时容易遗漏更新 `itemCount`
- 如果 `plugins` 列表长度变化，可能导致 `RangeError` 崩溃或数据丢失

### 修复建议

使用数据源的长度作为 `itemCount`：

```dart
Expanded(
  child: ListView.builder(
    itemCount: _plugins.length,  // 从数据源获取
    itemBuilder: _buildPluginCard,
  ),
),
```

---

## Bug 8: 安装按钮为空操作，用户可能误以为安装成功

### 位置
- [plugin_market_page.dart:134-152](file:///d:/Projects/node_graph_notebook/lib/ui/pages/plugin_market_page.dart#L134-L152)

### 严重程度
**中**

### 问题描述
"Install" 按钮的 `onPressed` 回调仅显示一个 "Installing..." 的 SnackBar，2 秒后消失，没有任何实际的安装逻辑。用户点击后会看到 "Installing..." 提示，可能误以为插件正在安装或已经安装成功。

更严重的是，按钮使用的是 `ElevatedButton` 样式，视觉上暗示这是一个可操作的功能按钮，而非禁用状态的占位符。

### 问题代码
```dart
ElevatedButton(
  onPressed: () {
    // 当前：仅显示安装提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${i18n.t('Installing...')} $pluginName'),
        duration: const Duration(seconds: 2),
      ),
    );
  },
  child: Text(i18n.t('Install')),
),
```

### 影响
- 用户可能误以为插件已安装，导致困惑
- 没有任何错误提示或"功能未实现"的说明
- 重复点击会产生多个 SnackBar

### 修复建议

方案一：禁用按钮并添加提示

```dart
ElevatedButton(
  onPressed: null,  // 禁用状态
  child: Text(i18n.t('Coming Soon')),
),
```

方案二：显示"功能未实现"的明确提示

```dart
ElevatedButton(
  onPressed: () {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(i18n.t('This feature is not yet implemented')),
        duration: const Duration(seconds: 2),
      ),
    );
  },
  child: Text(i18n.t('Install')),
),
```

---

## Bug 9: PluginMarketPage 中 i18n.t() 对带冒号标签的翻译可能产生格式问题

### 位置
- [plugin_market_page.dart:118-129](file:///d:/Projects/node_graph_notebook/lib/ui/pages/plugin_market_page.dart#L118-L129)

### 严重程度
**低**

### 问题描述
`i18n.t('Version:')` 和 `i18n.t('Author:')` 将英文标签（含冒号）作为翻译键。在不同语言中，标签与值的排列格式可能不同。例如中文使用全角冒号 `：`，而英文使用半角冒号 `:`。当前实现通过字符串拼接 `'${i18n.t('Version:')} ${plugin['version']}'` 来组合标签和值，无法适应不同语言的格式差异。

### 问题代码
```dart
Text(
  '${i18n.t('Version:')} ${plugin['version']}',  // 英文半角冒号硬编码
  // ...
),
Text(
  '${i18n.t('Author:')} ${plugin['author']}',  // 同上
  // ...
),
```

### 影响
- 中文环境下显示半角冒号，不符合中文排版规范
- 某些语言可能需要不同的标签-值排列方式（如日语可能需要冒号后无空格）

### 修复建议

使用带参数的翻译键：

```dart
Text(
  i18n.t('plugin.market.version', args: {'version': plugin['version']}),
  // ...
),
```

或在翻译值中包含格式：

```dart
// 翻译文件中:
// en: "plugin.market.version" => "Version: {version}"
// zh: "plugin.market.version" => "版本：{version}"
```

---

## 总结

| Bug ID | 严重程度 | 文件 | 问题类型 |
|--------|----------|------|----------|
| Bug 1 | 高 | home_page.dart | BuildContext 生命周期管理错误 |
| Bug 2 | 中 | home_page.dart | 缺少加载/错误状态处理 |
| Bug 3 | 低 | home_page.dart | 性能 - 缺少 buildWhen 条件 |
| Bug 4 | 低 | home_page.dart | 性能 - 拖拽事件无节流 |
| Bug 5 | 低 | plugin_market_page.dart | 数据重复创建 |
| Bug 6 | 中 | plugin_market_page.dart | 国际化键值错误 |
| Bug 7 | 中 | plugin_market_page.dart | 硬编码 itemCount |
| Bug 8 | 中 | plugin_market_page.dart | 空操作按钮误导用户 |
| Bug 9 | 低 | plugin_market_page.dart | 国际化格式问题 |

### 优先级建议
1. **Bug 1** 应立即修复，存储失效的 BuildContext 可能导致运行时崩溃
2. **Bug 2** 应尽快修复，缺少加载/错误状态处理影响用户体验
3. **Bug 6, 7, 8** 应在功能完善时修复，影响国际化和用户交互
4. **Bug 3, 4, 5, 9** 可在性能优化阶段处理
