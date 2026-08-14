# UI Design Overview (用户界面设计总览)

> 本文档从顶层到底层详细分析 Node Graph Notebook 的用户界面设计。

---

## 1. 核心设计理念：基于 Hook 树的声明式 UI

本项目的 UI 架构区别于传统的 Flutter 应用，采用了一套 **基于 Hook 树(Hook Tree) + 双渲染器(dual renderer)** 的声明式布局系统。

核心思想：

1. **"一切皆是 Hook"** — UI 区域（工具栏、侧边栏、图视图、状态栏）统一抽象为 `UIHookNode` 树上的节点
2. **"渲染器抽象"** — 同一棵 Hook 树可被 `FlutterRenderer` 或 `FlameRenderer` 消费，分别产出 Flutter Widget 或 Flame Component
3. **"插件注入"** — 任何插件可以通过注册 `HookRoleBase` 向指定 Hook Point 注入 UI，无需修改核心代码

---

## 2. 整体架构层次(Architecture Layers)

```
┌──────────────────────────────────────────────────────────────┐
│  应用入口层: main.dart → NodeGraphNotebookApp                │
│  负责: 依赖注入、插件加载、Provider树构建                     │
├──────────────────────────────────────────────────────────────┤
│  UI框架层: appframe (HomePage, UIBloc, HookBases)            │
│  负责: 页面结构、UI状态管理、UI Hook的类型定义               │
├──────────────────────────────────────────────────────────────┤
│  Hook布局引擎: core/plugin/hook/                             │
│  负责: Hook树管理、坐标系统、布局计算、渲染器桥接           │
├──────────────────────────────────────────────────────────────┤
│  插件层: graph, editor, folder, search, settings, ...        │
│  负责: 通过Hook向各个Hook Point注入实际UI内容                │
└──────────────────────────────────────────────────────────────┘
```

### 2.1 包依赖关系

```
core (UI布局引擎, Hook系统定义)
  ↑
appframe (UI框架: BLoC, 页面, 工具栏, Hook上下文)
  ↑
┌───────┬────────┬────────┬────────┬──────┐
graph   editor   folder   search   ... (具体插件, 实现各个Hook)
```

---

## 3. 初始化流程(Initialization Flow)

### 3.1 应用启动

`main.dart` → `runApp(NodeGraphNotebookApp())` → `_NodeGraphNotebookAppState`

应用有三个状态: `loading → ready | error`

### 3.2 严格分层的依赖注入

在 `_initialize()` 方法中，严格按照依赖顺序初始化：

```
步骤1: SharedPreferences (持久化层)
步骤2: CorePlugin → CommandBus, QueryBus, UILayoutService, HookRoleRegistry, I18n, ...
步骤3: AppFramePlugin → ThemeService, StoragePathService
步骤4: 文件系统仓库 (NodeRepository, GraphRepository)
步骤5: 业务插件 (Settings → Graph → Folder → Search → Editor)
步骤6: AppFrameInitializer → 注册标准Hook Point + 激活核心布局Hook
```

### 3.3 Provider 树

```
PluginProviderTree
  ├─ serviceRegistry.generateProviders()   # DI容器中的Provider (不重建)
  ├─ pluginManager.generateBlocProviders() # 插件BLoC (可重建)
  └─ Consumer<ThemeService>
       └─ MaterialApp
            └─ HomePage
                 └─ Consumer<HookRoleRegistry>  # Hook变化时重建
                      └─ FlutterRenderer
                           └─ 遍历layoutService.rootHook的UIHookNode树
                                ├─ 对每个节点, 查找其hookPointId对应的HookWrapper
                                ├─ 调用第一个可见的wrapper.render()
                                └─ 递归处理子节点和附加节点
```

---

## 4. Hook 树系统(The Hook Tree System)

### 4.1 核心概念

| 概念 | 类 | 说明 |
|------|-----|------|
| **Hook Point** | `HookPointDefinition` | 一个扩展点定义（如 `'main.toolbar'`, `'sidebar'`） |
| **Hook 角色** | `HookRoleBase` | 插件实现的具体UI行为（如 `MainToolbarHookRole`） |
| **Hook 包装器** | `HookWrapper` | 运行时对HookRoleBase的包装，含生命周期和状态 |
| **Hook 上下文** | `HookContext` | 向Hook传递渲染数据的键值容器（如positon, activeNode） |
| **UI Hook 节点** | `UIHookNode` | 布局树中的区域节点（含position, size, children, attachedNodes） |

### 4.2 标准 Hook Point 注册

`AppFrameInitializer._registerStandardHookPoints()` 注册以下 Hook Point：

| Hook Point ID | 用途 | 注册的Hook |
|---------------|------|------------|
| `root` | 根布局 | `RootLayoutHook` |
| `sidebar` | 侧边栏布局 | `SidebarLayoutHook` |
| `sidebar.tab` | 侧边栏Tab | `FolderSidebarTabHook`, `SearchSidebarHook`, `NodeEditorPanelHook` |
| `main.toolbar` | 主工具栏按钮 | `SettingsToolbarHook` |
| `graph.toolbar` | 图视图工具栏 | `GraphNodesToolbarHook`, `RefreshGraphToolbarHook`, `ToggleConnectionsToolbarHook` |
| `context_menu.node` | 节点右键菜单 | 预留 |
| `context_menu.graph` | 图右键菜单 | 预留 |
| `sidebar.bottom` | 侧边栏底部 | 预留 |
| `status.bar` | 状态栏 | 预留 |
| `help` | 帮助 | 预留 |

### 4.3 UIHookNode 树结构

```
root (Size.infinite)
├─ main.toolbar (height: 48, 顶部工具栏区域)
├─ sidebar (width: 300, 左侧侧边栏区域)
│   ├─ sidebar.top (height: 48)
│   └─ sidebar.bottom (弹性填充)
├─ graph (弹性填充, 图画布区域)
├─ context_menu.node (浮动, 节点右键菜单区域)
├─ context_menu.graph (浮动, 图右键菜单区域)
├─ status.bar (底栏区域)
└─ settings (设置区域)
```

### 4.4 Hook 注册和排序

`HookRoleRegistry` 管理所有Hook注册，按优先级排序：

```dart
_hooks[hookPointId]!.sort((a, b) {
  final cmp = a.hook.priority.value.compareTo(b.hook.priority.value);
  if (cmp != 0) return cmp;
  return a.registrationOrder.compareTo(b.registrationOrder);
});
```

排序规则：优先级值小的在前（`critical(0)` 最高），同优先级按注册顺序。

---

## 5. UI 布局系统(UILayoutService)

### 5.1 服务职责

`UILayoutService` 是整个布局系统的编排核心：

- 管理 `UIHookNode` 树（创建、查询、遍历）
- 管理 `NodeAttachment`（节点在 Hook 上的附着、分离、移动）
- 通过 `CommandBus` 发布布局事件
- 通过 `SharedPreferences` 持久化布局状态
- 集成 `NodeTemplateRegistry`（按模板创建节点）

### 5.2 字体坐标系统

```
LocalPosition (相对于父节点的局部坐标)
  ├─ absolute(x, y)     → 像素绝对坐标
  ├─ proportional(x, y) → 父节点大小的比例 (0.0~1.0)
  ├─ sequential(index)  → 顺序布局中的索引
  └─ fill()             → 填充整个父节点

GlobalPosition ← CoordinateSystem.localToGlobal() → 屏幕空间绝对坐标
```

四种定位模式通过 `toAbsolute(parentSize)` 统一为像素偏移，使布局引擎无需理解每种模式即可计算位置。

### 5.3 节点附着系统

`NodeAttachment` 是不可变对象，包含：
- `nodeId` — 被附着的 Node ID
- `localPosition` — 在 Hook 坐标系中的位置
- `zIndex` — 渲染层级（类似 CSS z-index）
- `size` — 可选大小
- `metadata` — 自定义数据（如 `renderState`）

关键约束：**一个节点同时只能附着到一个 Hook**（由 `_nodeToHookIndex` 映射保证）。

### 5.4 布局事件

所有布局变更通过 CommandBus 发布事件：

| 事件 | 触发时机 |
|------|----------|
| `NodeAttachedEvent` | 节点附着到Hook |
| `NodeDetachedEvent` | 节点从Hook分离 |
| `NodePositionUpdatedEvent` | 同Hook内位置变更 |
| `NodeMovedEvent` | 节点跨Hook移动 |
| `LayoutRecalculatedEvent` | 布局重算完成 |
| `HookTreeChangedEvent` | Hook树结构变更 |

---

## 6. 双渲染器架构(Dual Renderer Architecture)

### 6.1 渲染器接口

```dart
abstract class RendererBase<T> {
  T render(UIHookNode hook, Map<String, dynamic> context);
  T renderAttachedNode(NodeAttachment attachment, Map<String, dynamic> context);
  String get outputTypeName;  // 调试用
}
```

有两个完全独立的实现，产出不同的渲染结果。

### 6.2 FlutterRenderer（主渲染器）

**输入**: `UIHookNode` 树 + `BuildContext`  
**输出**: `Widget` 对象  
**位置**: `packages/core/lib/plugin/hook/rendering/flutter_renderer.dart`

**渲染流程**:
```
render(hook, context)
  ├─ hookRoleRegistry.getHookWrappers(hook.hookPointId)  → 查找Hook包装器
  ├─ 提取第一个可见的HookWrapper
  │   └─ wrapper.hook.isVisible(hookContext) && wrapper.render(hookContext)
  ├─ 如果无可见Hook → _renderDefaultContainer()
  │   ├─ 递归渲染子节点 (SingleChildScrollView > Column)
  │   └─ 渲染附加节点 (_DefaultNodeWidget)
  └─ _applySizeConstraint() → 施加Size约束
```

**核心逻辑**: 对每个 `UIHookNode`，根据其 `hookPointId` 查找已注册的 `HookWrapper`，按优先级排序，让第一个可见的 Hook 渲染。如果没有任何插件为该区域提供 Hook，则回退到递归子节点。

### 6.3 FlameRenderer（图渲染器）

**输入**: `UIHookNode` 树 + `FlameGame`  
**输出**: `FlameComponent` 对象  
**位置**: `packages/core/lib/plugin/hook/rendering/flame_renderer.dart`

**渲染流程**:
```
render(hook, context)
  ├─ _buildLayoutItems()  → 构建 Flattened 布局项列表
  ├─ _calculatorRegistry.calculate()  → 布局算法计算
  │   ├─ FlameAbsoluteCalculator  (绝对坐标映射)
  │   ├─ FlameSequentialCalculator (沿主轴排列)
  │   ├─ FlameFlowCalculator (类似FlexWrap)
  │   └─ FlameGridCalculator (固定列网格)
  └─ _buildContainer() → 创建PositionComponent树
       ├─ 递归渲染子节点 (应用计算出的position)
       └─ 渲染附加节点 (_DefaultNodeComponent)
```

---

## 7. UI 框架层的组件(AppFrame Layer)

### 7.1 主页结构 (HomePage)

```dart
FlutterRenderer(layoutService.rootHook)
  └─ 找到'root' HookPoint的RootLayoutHook
       └─ _RootLayoutWidget (Scaffold)
            ├─ appBar: CoreToolbar()
            │    └─ 读取'main.toolbar'的HookWrappers → 渲染为按钮
            ├─ body: Row
            │    ├─ SidebarLayoutHook._SidebarLayoutWidget
            │    │    ├─ ActivityBar (48px, 竖排图标)
            │    │    └─ Content (240px, 选中Tab的内容)
            │    └─ Expanded → Graph View (由graph插件提供)
            └─ bottomNavigationBar: StatusBar
```

### 7.2 UI 状态管理 (UIBloc)

```dart
UIState (不可变, Equatable)
  ├─ nodeViewMode: NodeViewMode      // 节点显示模式
  ├─ showConnections: bool            // 是否显示连接
  ├─ backgroundStyle: BackgroundStyle // 背景样式
  ├─ isSidebarOpen: bool              // 侧边栏是否打开
  ├─ selectedTab: String              // 选中的侧边栏Tab
  ├─ sidebarWidth: double             // 侧边栏宽度 (150~500)
  └─ isToolbarExpanded: bool          // 工具栏是否展开
```

⚠️ **双层状态管理的张力**: `UIBloc` 管理 UI 的开关状态(如 sidebar 开关)，但 `SidebarLayoutHook` 内部用 `StatefulWidget` 的本地状态管理 `_selectedTabIndex` 和 `_isSidebarExpanded`，两者尚未完全统一。

### 7.3 工具栏 (Toolbar)

**主工具栏** = `CoreToolbar` / `MainToolbarLayoutHook`:
- 读取 `'main.toolbar'` Hook Point 的所有 Hook
- 每个 Hook 渲染为 `_ToolbarActionButton`（含 hover 高亮）
- 按钮顺序反转渲染（最后注册的在最左）

### 7.4 侧边栏 (Sidebar)

**SidebarLayoutHook** 渲染侧边栏:
- **Activity Bar** (48px): 竖排图标按钮列表，从 `'sidebar.tab'` Hook Point 获取 Tab
- **Content Panel** (240px): 选中 Tab 的内容区域
- 切换逻辑: 点击已选中的 Tab 会折叠/展开，点击其他 Tab 选中并展开
- 底部有 Settings 按钮（目前占位）

### 7.5 键盘快捷键系统

通过 `ShortcutManager` 管理，在 `ShortcutsDialog` 中显示：

| 快捷键 | 功能 |
|--------|------|
| Ctrl + N | 创建新节点 |
| Ctrl + S | 保存 |
| Ctrl + Z | 撤销 |
| Ctrl + Shift + Z | 重做 |
| Delete | 删除选中节点 |
| Ctrl + F | 搜索 |
| Ctrl + E | 导出 |
| Ctrl + 1~4 | 切换到不同布局算法 |

---

## 8. 具体插件的 UI 注入

### 8.1 插件 → Hook 映射

| 插件 | 注入的Hook | Hook Point | 渲染位置 |
|------|-----------|------------|----------|
| GraphPlugin | `GraphNodesToolbarHook` | `graph.toolbar` | 图视图 |
| GraphPlugin | `RefreshGraphToolbarHook` | `graph.toolbar` | 图视图 |
| GraphPlugin | `ToggleConnectionsToolbarHook` | `graph.toolbar` | 图视图 |
| SettingsPlugin | `SettingsToolbarHook` | `main.toolbar` | 主工具栏 |
| FolderPlugin | `FolderSidebarTabHook` | `sidebar.tab` | 侧边栏Tab |
| SearchPlugin | `SearchSidebarHook` | `sidebar.tab` | 侧边栏Tab |
| EditorPlugin | `NodeEditorPanelHook` | `sidebar.tab` | 侧边栏Tab |

### 8.2 Hook 上下文类型

每种 Hook 接收私有上下文：

| Context 类 | Hook Point | 携带数据 |
|------------|-----------|----------|
| `MainToolbarHookContext` | `main.toolbar` | showTitle, showSearch |
| `NodeContextMenuHookContext` | `context_menu.node` | node, isSelected |
| `GraphContextMenuHookContext` | `context_menu.graph` | mousePosition, selectedNodeCount |
| `SidebarHookContext` | `sidebar.tab` | isExpanded, width |
| `StatusBarHookContext` | `status.bar` | nodeCount, connectionCount, currentMode |
| `RootHookContext` | `root` | children, attachedNodes |

实现方式：每个 Context 类内部通过 `Map<String, dynamic>` 存储数据，typed getter 作为语法糖。

---

## 9. 核心设计模式总结

### 9.1 模式一览

| 模式 | 应用位置 | 说明 |
|------|---------|------|
| **Hook + 注册表** | `HookRoleRegistry` + `HookRoleBase` | 插件通过注册Hook向指定扩展点注入UI |
| **命令查询职责分离(CQRS)** | `CommandBus` / `QueryBus` | 写操作走Command+事件, 读操作走Query+缓存 |
| **不可变状态 + copyWith** | `UIState`, `NodeAttachment` | 所有状态通过不可变对象 + copyWith 更新 |
| **BLoC 模式** | `UIBloc` | UI状态管理与业务逻辑分离 |
| **渲染器模式** | `RendererBase<T>` | 同一棵树可产出Flutter Widget或Flame Component |
| **策略模式** | `FlameLayoutCalculator` | 多种布局算法可替换 |
| **观察者模式** | `ChangeNotifier` + `Consumer` | Hook注册/反注册时自动触发UI重建 |
| **依赖注入** | `ServiceRegistry` | 统一DI容器, 支持Provider集成 |

### 9.2 核心工作流: 插件注册一个新的侧边栏Tab

```
1. 插件实现 SidebarTabHookRole
   ├─ hookPointId = 'sidebar.tab'
   ├─ tabId, tabLabel, tabIcon
   └─ buildContent(SidebarHookContext) → Widget

2. 插件在 registerHooks() 中返回 HookFactory
   └─ PluginManager._registerHooks()
        └─ hookRegistry.registerHook(hook, parentPlugin)
             ├─ 创建HookWrapper (含生命周期管理器)
             ├─ 按优先级排序插入列表
             ├─ 在HookAPIRegistry中注册API
             └─ notifyListeners() → UI重建

3. HomePage的Consumer<HookRoleRegistry> 收到变化
   └─ FlutterRenderer 重新渲染
        └─ SidebarLayoutHook 读取 'sidebar.tab' 的HookWrappers
             └─ 在ActivityBar中渲染新Tab的图标
                  └─ 点击时展开Content Panel显示 buildContent() 的输出
```

---

## 10. 当前设计的局限与张力点

1. **双层状态管理未统一**: `UIBloc` 处理 UI 开关状态，但 `SidebarLayoutHook` 使用本地 `StatefulWidget` 状态（`_selectedTabIndex`, `_isSidebarExpanded`），两者数据源不一致

2. **全局单例残留**: `hook_role_registry.dart` 中的全局 `final hookRegistry = HookRoleRegistry()` 单例，注释说明应迁移到 `ServiceRegistry` DI 但尚未完成

3. **新旧工具栏并存**: `CoreToolbar`（直接在 Scaffold 中使用）和 `MainToolbarLayoutHook`（通过 Hook 系统渲染）功能相似，互为替代

4. **HomePage 直接依赖具体服务**: 虽然通过 Provider 获取，但 `HomePage` 直接调用 `layoutService.rootHook`，抽象层级不够

5. **布局持久化尚未完善**: `SharedPreferences` 存储布局状态，但仅在 `initialize()` 时恢复，运行时变化未自动持久化
