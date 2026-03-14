# UI Hook 系统设计文档

## 1. 概述

### 1.1 职责
UI Hook 系统允许插件扩展和定制用户界面，实现：
- 在 UI 特定位置插入自定义组件
- 拦截和修改 UI 事件
- 注册自定义菜单项
- 添加工具栏按钮
- 扩展上下文菜单
- 自定义对话框和面板

### 1.2 目标
- **灵活性**: 支持在多个 UI 位置插入组件
- **类型安全**: 提供类型安全的 Hook API
- **生命周期**: 正确管理 Hook 组件的生命周期
- **性能**: Hook 开销最小化
- **隔离性**: 插件 UI 组件与主系统隔离

### 1.3 关键挑战
- **Hook 点设计**: 确定合适的 Hook 位置
- **数据传递**: Hook 上下文的数据传递
- **事件协调**: 插件 UI 事件与主系统的协调
- **布局管理**: 插件组件的布局和样式
- **资源清理**: 插件卸载时的资源清理

## 2. 架构设计

### 2.1 组件结构

```
UIHookSystem
    │
    ├── HookPoint (Hook 点定义)
    │   ├── id (唯一标识)
    │   ├── location (位置描述)
    │   └── context (上下文数据)
    │
    ├── UIHook (Hook 接口)
    │   ├── build() (构建 UI 组件)
    │   ├── onInit() (初始化)
    │   └── onDispose() (清理)
    │
    ├── HookRegistry (Hook 注册表)
    │   ├── registerHook() (注册 Hook)
    │   ├── unregisterHook() (注销 Hook)
    │   └── getHooks() (获取 Hook)
    │
    └── HookWidget (Hook 容器组件)
        ├── hookPoint (Hook 点)
        └── child (子组件)
```

### 2.2 接口定义

#### Hook 点定义

```dart
/// Hook 点标识
enum HookPointId {
  /// 主工具栏
  mainToolbar,

  /// 节点上下文菜单
  nodeContextMenu,

  /// 图上下文菜单
  graphContextMenu,

  /// 侧边栏顶部
  sidebarTop,

  /// 侧边栏底部
  sidebarBottom,

  /// 导航菜单
  navigationMenu,

  /// 节点详情面板
  nodeDetailPanel,

  /// 搜索栏
  searchBar,

  /// 导出菜单
  exportMenu,

  /// 导入菜单
  importMenu,

  /// 状态栏
  statusBar,
}

/// Hook 点定义
class HookPoint {
  /// Hook 点标识
  final HookPointId id;

  /// Hook 点位置描述
  final String location;

  /// Hook 点支持的组件类型
  final Type widgetType;

  /// Hook 点上下文数据结构
  final Type contextType;

  const HookPoint({
    required this.id,
    required this.location,
    required this.widgetType,
    required this.contextType,
  });

  /// 创建 Hook 上下文
  HookContext createContext(Map<String, dynamic> data) {
    return HookContext(
      hookPoint: this,
      data: data,
    );
  }
}

/// Hook 上下文
class HookContext {
  /// Hook 点
  final HookPoint hookPoint;

  /// 上下文数据
  final Map<String, dynamic> data;

  HookContext({
    required this.hookPoint,
    required this.data,
  });

  /// 获取上下文数据
  T get<T>(String key) {
    return data[key] as T;
  }

  /// 检查数据是否存在
  bool has(String key) {
    return data.containsKey(key);
  }
}
```

#### UI Hook 接口

```dart
/// UI Hook 接口
abstract class UIHook {
  /// Hook 元数据
  HookMetadata get metadata;

  /// Hook 点标识
  HookPointId get hookPointId;

  /// 构建 UI 组件
  Widget build(HookContext context);

  /// Hook 初始化
  Future<void> onInit(HookContext context);

  /// Hook 清理
  Future<void> onDispose();

  /// Hook 优先级（数值越小越靠前）
  int get priority => 100;
}

/// Hook 元数据
class HookMetadata {
  /// Hook 唯一标识符
  final String id;

  /// Hook 名称
  final String name;

  /// Hook 描述
  final String description;

  /// 插件 ID
  final String pluginId;

  HookMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.pluginId,
  });
}
```

#### Hook 注册表

```dart
/// Hook 注册表
class HookRegistry {
  final Map<HookPointId, List<UIHook>> _hooks = {};

  /// 注册 Hook
  void registerHook(UIHook hook) {
    final hookPointId = hook.hookPointId;

    _hooks.putIfAbsent(hookPointId, () => []);
    _hooks[hookPointId]!.add(hook);

    // 按优先级排序
    _hooks[hookPointId]!.sort((a, b) => a.priority.compareTo(b.priority));

    _logger.i('注册 UI Hook: ${hook.metadata.id} at $hookPointId');
  }

  /// 注销 Hook
  void unregisterHook(UIHook hook) {
    final hookPointId = hook.hookPointId;

    final hooks = _hooks[hookPointId];
    if (hooks != null) {
      hooks.remove(hook);
      _logger.i('注销 UI Hook: ${hook.metadata.id}');
    }
  }

  /// 获取指定 Hook 点的所有 Hook
  List<UIHook> getHooks(HookPointId hookPointId) {
    return _hooks[hookPointId] ?? [];
  }

  /// 清空所有 Hook
  void clear() {
    _hooks.clear();
  }

  /// 注销指定插件的所有 Hook
  void unregisterPluginHooks(String pluginId) {
    for (final entry in _hooks.entries) {
      entry.value.removeWhere((hook) =>
          hook.metadata.pluginId == pluginId);
    }
  }
}
```

#### Hook 容器组件

```dart
/// Hook 容器组件
class HookContainerWidget extends StatelessWidget {
  /// Hook 点标识
  final HookPointId hookPointId;

  /// Hook 上下文数据
  final Map<String, dynamic> contextData;

  /// 子组件（显示在 Hook 组件之后）
  final Widget? child;

  /// 布局方向
  final Axis direction;

  /// 对齐方式
  final MainAxisAlignment alignment;

  const HookContainerWidget({
    super.key,
    required this.hookPointId,
    this.contextData = const {},
    this.child,
    this.direction = Axis.horizontal,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    // 获取 Hook 注册表
    final registry = context.watch<HookRegistry>();
    final hooks = registry.getHooks(hookPointId);

    if (hooks.isEmpty && child == null) {
      return const SizedBox.shrink();
    }

    // 构建 Hook 上下文
    final hookContext = HookContext(
      hookPoint: _getHookPoint(hookPointId),
      data: contextData,
    );

    // 构建所有 Hook 组件
    final hookWidgets = hooks.map((hook) {
      return Builder(
        key: ValueKey(hook.metadata.id),
        builder: (context) => hook.build(hookContext),
      );
    }).toList();

    // 根据布局方向排列
    if (direction == Axis.horizontal) {
      return Row(
        mainAxisAlignment: alignment,
        children: [
          ...hookWidgets,
          if (child != null) child!,
        ],
      );
    } else {
      return Column(
        mainAxisAlignment: alignment,
        children: [
          ...hookWidgets,
          if (child != null) child!,
        ],
      );
    }
  }

  HookPoint _getHookPoint(HookPointId id) {
    // 根据ID返回Hook点定义
    return HookPoint(
      id: id,
      location: id.name,
      widgetType: Widget,
      contextType: HookContext,
    );
  }
}
```

### 2.3 具体Hook点实现

#### 工具栏 Hook

```dart
/// 主工具栏 Hook 点
class MainToolbarHookPoint {
  static const HookPoint point = HookPoint(
    id: HookPointId.mainToolbar,
    location: '主工具栏右侧',
    widgetType: ToolbarAction,
    contextType: MainToolbarContext,
  );

  /// 在工具栏中插入 Hook 容器
  static Widget buildToolbar({
    required List<Widget> actions,
    Map<String, dynamic> contextData = const {},
  }) {
    return HookContainerWidget(
      hookPointId: HookPointId.mainToolbar,
      contextData: contextData,
      direction: Axis.horizontal,
      child: Row(children: actions),
    );
  }
}

/// 工具栏操作组件
typedef ToolbarAction = Widget Function();

/// 主工具栏上下文
class MainToolbarContext extends HookContext {
  /// 当前视图模式
  ViewMode get viewMode => get('viewMode');

  /// 选中的节点
  List<Node> get selectedNodes => get('selectedNodes');

  /// 当前图
  Graph? get currentGraph => get('currentGraph');
}
```

#### 上下文菜单 Hook

```dart
/// 节点上下文菜单 Hook 点
class NodeContextMenuHookPoint {
  static const HookPoint point = HookPoint(
    id: HookPointId.nodeContextMenu,
    location: '节点上下文菜单',
    widgetType: ContextMenuItem,
    contextType: NodeContextMenuContext,
  );

  /// 构建带 Hook 的上下文菜单
  static List<PopupMenuEntry<dynamic>> buildMenuItems({
    required List<PopupMenuEntry<dynamic>> items,
    required Map<String, dynamic> contextData,
    required BuildContext buildContext,
  }) {
    final registry = buildContext.watch<HookRegistry>();
    final hooks = registry.getHooks(HookPointId.nodeContextMenu);

    final hookContext = HookContext(
      hookPoint: point,
      data: contextData,
    );

    final menuItems = <PopupMenuEntry<dynamic>>[];

    // 添加 Hook 菜单项
    for (final hook in hooks) {
      final widget = hook.build(hookContext);
      if (widget is PopupMenuEntry) {
        menuItems.add(widget);
      }
    }

    // 添加分隔符
    if (menuItems.isNotEmpty && items.isNotEmpty) {
      menuItems.add(const PopupMenuDivider());
    }

    // 添加原始菜单项
    menuItems.addAll(items);

    return menuItems;
  }
}

/// 节点上下文菜单上下文
class NodeContextMenuContext extends HookContext {
  /// 被点击的节点
  Node get node => get('node');

  /// 节点位置（屏幕坐标）
  Offset get position => get('position');

  /// 当前图
  Graph get graph => get('graph');
}
```

#### 侧边栏 Hook

```dart
/// 侧边栏 Hook 点
class SidebarHookPoint {
  /// 侧边栏顶部 Hook
  static const topPoint = HookPoint(
    id: HookPointId.sidebarTop,
    location: '侧边栏顶部',
    widgetType: Widget,
    contextType: SidebarContext,
  );

  /// 侧边栏底部 Hook
  static const bottomPoint = HookPoint(
    id: HookPointId.sidebarBottom,
    location: '侧边栏底部',
    widgetType: Widget,
    contextType: SidebarContext,
  );

  /// 构建带 Hook 的侧边栏
  static Widget buildSidebar({
    required Widget content,
    Map<String, dynamic> contextData = const {},
    List<Widget>? topWidgets,
    List<Widget>? bottomWidgets,
  }) {
    return Column(
      children: [
        // 顶部 Hook
        HookContainerWidget(
          hookPointId: HookPointId.sidebarTop,
          contextData: contextData,
          direction: Axis.vertical,
        ),
        if (topWidgets != null) ...topWidgets,
        // 主内容
        Expanded(child: content),
        if (bottomWidgets != null) ...bottomWidgets,
        // 底部 Hook
        HookContainerWidget(
          hookPointId: HookPointId.sidebarBottom,
          contextData: contextData,
          direction: Axis.vertical,
        ),
      ],
    );
  }
}

/// 侧边栏上下文
class SidebarContext extends HookContext {
  /// 当前侧边栏宽度
  double get width => get('width');

  /// 侧边栏是否展开
  bool get isExpanded => get('isExpanded');
}
```

## 3. 插件 Hook 实现

### 3.1 自定义工具栏按钮

```dart
/// 自定义导出按钮 Hook
class ExportButtonHook implements UIHook {
  @override
  HookMetadata get metadata => HookMetadata(
        id: 'export_button',
        name: '导出按钮',
        description: '在工具栏添加导出按钮',
        pluginId: 'export_plugin',
      );

  @override
  HookPointId get hookPointId => HookPointId.mainToolbar;

  @override
  int get priority => 50;

  @override
  Widget build(HookContext context) {
    return IconButton(
      icon: const Icon(Icons.upload),
      tooltip: '导出',
      onPressed: () => _handleExport(context),
    );
  }

  @override
  Future<void> onInit(HookContext context) async {
    // 初始化逻辑
  }

  @override
  Future<void> onDispose() async {
    // 清理逻辑
  }

  void _handleExport(HookContext context) async {
    // 获取 Command Bus
    final commandBus = context.get<ICommandBus>('commandBus');

    // 执行导出 Command
    await commandBus.execute(ExportCommand());
  }
}
```

### 3.2 上下文菜单扩展

```dart
/// 节点复制菜单项 Hook
class CopyNodeMenuHook implements UIHook {
  @override
  HookMetadata get metadata => HookMetadata(
        id: 'copy_node_menu',
        name: '复制节点菜单项',
        description: '在节点上下文菜单添加复制选项',
        pluginId: 'clipboard_plugin',
      );

  @override
  HookPointId get hookPointId => HookPointId.nodeContextMenu;

  @override
  int get priority => 10;

  @override
  Widget build(HookContext context) {
    return PopupMenuItem<void>(
      value: 'copy',
      child: Row(
        children: const [
          Icon(Icons.copy),
          SizedBox(width: 8),
          Text('复制'),
        ],
      ),
    );
  }

  @override
  Future<void> onInit(HookContext context) async {}

  @override
  Future<void> onDispose() async {}
}
```

### 3.3 侧边栏面板

```dart
/// 插件信息面板 Hook
class PluginInfoPanelHook implements UIHook {
  @override
  HookMetadata get metadata => HookMetadata(
        id: 'plugin_info_panel',
        name: '插件信息面板',
        description: '显示已加载的插件信息',
        pluginId: 'plugin_manager',
      );

  @override
  HookPointId get hookPointId => HookPointId.sidebarBottom;

  @override
  int get priority => 100;

  @override
  Widget build(HookContext context) {
    final pluginManager = context.get<IPluginManager>('pluginManager');

    return StreamBuilder<List<PluginMetadata>>(
      stream: pluginManager.pluginsChanged,
      builder: (context, snapshot) {
        final plugins = snapshot.data ?? [];

        if (plugins.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '已加载插件',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...plugins.map((plugin) => Text(
                      '• ${plugin.name} v${plugin.version}',
                      style: const TextStyle(fontSize: 12),
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Future<void> onInit(HookContext context) async {}

  @override
  Future<void> onDispose() async {}
}
```

## 4. Hook 生命周期管理

### 4.1 Hook 状态管理

```dart
/// Hook 状态管理器
class HookStateManager {
  final Map<String, HookState> _states = {};

  /// 注册 Hook 时创建状态
  void registerHook(UIHook hook, HookContext context) {
    final state = HookState(
      hook: hook,
      context: context,
      status: HookStatus.initialized,
    );
    _states[hook.metadata.id] = state;

    // 调用 onInit
    hook.onInit(context).then((_) {
      state.status = HookStatus.active;
    }).catchError((e) {
      state.status = HookStatus.error;
      state.error = e;
    });
  }

  /// 注销 Hook 时清理状态
  void unregisterHook(UIHook hook) async {
    final state = _states.remove(hook.metadata.id);

    if (state != null) {
      state.status = HookStatus.disposing;
      await hook.onDispose();
      state.status = HookStatus.disposed;
    }
  }

  /// 获取 Hook 状态
  HookState? getState(String hookId) {
    return _states[hookId];
  }
}

/// Hook 状态
class HookState {
  final UIHook hook;
  final HookContext context;
  HookStatus status;
  Object? error;

  HookState({
    required this.hook,
    required this.context,
    required this.status,
    this.error,
  });
}

/// Hook 状态枚举
enum HookStatus {
  /// 已初始化
  initialized,

  /// 活跃
  active,

  /// 错误
  error,

  /// 正在清理
  disposing,

  /// 已清理
  disposed,
}
```

## 5. 性能考虑

### 5.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| Hook 组件构建时间 | < 1ms | 单个 Hook 组件的构建时间 |
| Hook 注册开销 | < 0.1ms | 注册一个 Hook 的开销 |
| Hook 容器渲染 | < 2ms | Hook 容器的渲染时间 |

### 5.2 优化策略

1. **延迟加载**:
   - Hook 组件按需构建
   - 使用 `Builder` 或 `FutureBuilder`

2. **缓存**:
   - 缓存 Hook 组件实例
   - 避免重复构建

3. **条件渲染**:
   - 根据上下文条件性渲染 Hook
   - 减少不必要的 Widget 树

## 6. 关键文件清单

```
lib/core/plugin/ui_hooks/
├── hook_point.dart               # Hook 点定义
├── hook_context.dart             # Hook 上下文
├── ui_hook.dart                  # UI Hook 接口
├── hook_registry.dart            # Hook 注册表
├── hook_container.dart           # Hook 容器组件
├── hook_state_manager.dart       # Hook 状态管理
└── points/                       # 具体 Hook 点实现
    ├── toolbar_hook.dart         # 工具栏 Hook
    ├── context_menu_hook.dart    # 上下文菜单 Hook
    ├── sidebar_hook.dart         # 侧边栏 Hook
    ├── status_bar_hook.dart      # 状态栏 Hook
    └── search_bar_hook.dart      # 搜索栏 Hook
```

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
