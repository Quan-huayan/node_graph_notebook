# UI 组件可见性问题修复计划

## 问题描述

打开软件后只能看到：
- 侧边栏竖线（分隔线）
- 添加节点按钮（右下角浮动按钮）
- 浮动工具栏

其他组件和节点均不可见。

## 问题诊断

### 1. 问题现象分析

**可见的组件**：
- ✅ 侧边栏分隔线（`GestureDetector`，宽度 1px 的竖线）
- ✅ 添加节点按钮（`_CreateNodeButton`，固定在右下角）
- ✅ 浮动工具栏（`DraggableToolbar`，悬浮在画布上）

**不可见的组件**：
- ❌ 侧边栏内容区域（节点列表、文件夹树等）
- ❌ 主画布中的节点渲染
- ❌ 顶部工具栏内容
- ❌ 节点之间的连接线

### 2. 代码分析发现

#### 发现 1：侧边栏显示条件

在 `home_page.dart:45` 中，侧边栏显示需要满足：
```dart
if (uiState.isSidebarOpen && graphState.hasGraph)
```

其中 `hasGraph` 的定义在 `graph_state.dart:78`：
```dart
bool get hasGraph => graph.id.isNotEmpty;
```

**问题**：如果 `graph.id` 为空，侧边栏不会显示。

#### 发现 2：侧边栏渲染逻辑

在 `sidebar.dart:130` 中：
```dart
final sidebarHook = layoutService.getHook('sidebar');
```

侧边栏尝试获取 `'sidebar'` Hook，然后通过插件注册的 Hook 来渲染内容。

#### 发现 3：UILayoutService 的 Hook 结构

在 `ui_layout_service.dart:164-200` 中创建了 Hook 树：
```dart
// Sidebar container Hook
final sidebarHook = UIHookNode(id: 'sidebar', ...);
  ├─ sidebar.top (标签页栏)
  └─ sidebar.bottom (内容区域)
```

**问题**：`'sidebar'` Hook 存在，但需要插件注册 `sidebar.bottom` 的内容。

#### 发现 4：插件 Hook 注册

`FolderPlugin` 在 `folder_plugin.dart:68-71` 中注册了 Hooks：
```dart
List<HookFactory> registerHooks() => [
  FolderSidebarTabHook.new,
  SidebarNodeListHook.new,
];
```

`SidebarNodeListHook` 负责在 `sidebar.bottom` 显示节点列表。

### 3. 可能的根本原因

#### 原因 A：插件加载失败（最可能 ⭐⭐⭐⭐⭐）

虽然 `FolderPlugin` 在内置插件列表中，但可能：
- 插件加载过程中抛出异常
- 插件的 `onLoad()` 或 `onEnable()` 失败
- Hook 注册失败

**症状匹配度**：⭐⭐⭐⭐⭐
- 侧边栏、工具栏、节点都依赖插件 Hook
- 基础框架（分隔线、按钮）不依赖插件，所以可见
- 所有插件提供的功能都不可用

#### 原因 B：Hook 渲染器问题（⭐⭐⭐⭐）

`FlutterRenderer` 或 `FlameRenderer` 可能：
- 渲染逻辑有 bug
- 无法正确渲染 Hook 内容
- 尺寸计算错误导致组件不可见

**症状匹配度**：⭐⭐⭐⭐
- 会影响所有 Hook 渲染
- 基础组件（按钮、分隔线）是普通 Flutter 组件，不受影响

#### 原因 C：BLoC 状态异常（⭐⭐⭐）

如果 `GraphBloc` 或 `NodeBloc` 状态异常：
- `graphState.hasGraph` 为 false
- `nodeState.nodes` 为空
- 侧边栏条件不满足

**症状匹配度**：⭐⭐⭐
- 会影响侧边栏显示
- 但不会解释为什么工具栏内容也不可见

#### 原因 D：Hook 树初始化失败（⭐⭐⭐）

如果 `UILayoutService` 的 Hook 树未正确初始化：
- `getHook('sidebar')` 返回 null
- 侧边栏使用回退实现
- 回退实现可能有 bug

**症状匹配度**：⭐⭐⭐
- 侧边栏内容不可见
- 但其他 Hook（如工具栏）应该仍然工作

### 3. 诊断步骤

#### 步骤 1：检查应用日志

启动应用，查看日志输出：
```bash
flutter run -d windows
```

**关键错误**：
- `RepositoryException` - 目录权限问题
- `Plugin load failed` - 插件加载失败
- `Hook not found` - Hook 注册失败
- `BLoC error` - 状态管理错误

#### 步骤 2：检查数据目录权限

```bash
# 检查 data/nodes 和 data/graphs 目录
ls -la data/nodes
ls -la data/graphs

# 手动测试写入权限
echo "test" > data/nodes/.write_test
```

#### 步骤 3：检查 Hook 注册

在 `app.dart` 中添加调试日志：
```dart
_log.info('Registered hooks: ${hookRegistry.getAllHooks().length}');
_log.info('Hook points: ${hookRegistry.getAllHookPoints().length}');
```

#### 步骤 4：检查 BLoC 状态

在 `GraphView` 中添加调试输出：
```dart
print('Graph state: hasGraph=${state.hasGraph}, nodes=${state.nodes.length}');
print('Node state: nodes=${nodeState.nodes.length}');
```

### 4. 影响链分析

```
Repository 初始化失败
  ↓
CommandBus/QueryBus 无法创建
  ↓
插件系统无法加载
  ↓
Hook 系统无内容
  ↓
UI 组件无法渲染
  ↓
用户只看到基础框架
```

## 修复计划

### 阶段一：诊断问题根源（0.5-1 小时）

#### 1.1 运行应用并收集日志（非沙盒环境）
- [ ] **重要**：在非沙盒环境中运行应用
- [ ] 启动应用：`flutter run -d windows`
- [ ] 记录所有错误和警告信息
- [ ] 重点关注以下日志：
  - `Plugin load failed` - 插件加载失败
  - `Hook not found` - Hook 未找到
  - `Failed to build` - 构建失败
  - `BLoC error` - 状态管理错误

#### 1.2 检查插件加载状态
- [ ] 查看 `BuiltinPluginLoader` 的加载摘要
- [ ] 确认 `FolderPlugin` 是否加载成功
- [ ] 检查 Hook 注册数量：`Total hooks registered`

#### 1.3 检查 Hook 渲染
- [ ] 在 `sidebar.dart` 中添加调试日志
- [ ] 检查 `layoutService.getHook('sidebar')` 是否返回非 null
- [ ] 检查 Hook 渲染器的输出

#### 1.4 确定具体问题
- [ ] 如果插件加载失败 → 执行阶段二.A
- [ ] 如果 Hook 渲染失败 → 执行阶段二.B
- [ ] 如果 BLoC 状态异常 → 执行阶段二.C

### 阶段二.A：修复插件加载问题（如果插件加载失败）

#### 步骤 A1：检查插件依赖
- [ ] 查看 `FolderPlugin` 的依赖项
- [ ] 确认所有依赖都已注册
- [ ] 检查是否有循环依赖

#### 步骤 A2：修复插件加载异常
- [ ] 在 `PluginManager.loadPlugin()` 中添加详细错误日志
- [ ] 捕获并记录插件加载过程中的所有异常
- [ ] 修复导致加载失败的具体问题

```dart
// 在 PluginManager 中添加错误处理
try {
  await plugin.onLoad(context);
  _log.info('Plugin loaded: ${plugin.metadata.id}');
} catch (e, st) {
  _log.error('Failed to load plugin ${plugin.metadata.id}: $e');
  _log.info('Stack trace: $st');
  rethrow;
}
```

#### 步骤 A3：验证 Hook 注册
- [ ] 确认插件的 `registerHooks()` 被调用
- [ ] 检查 Hook 是否成功注册到 `hookRegistry`
- [ ] 验证 `sidebar.bottom`、`main.toolbar` 等 Hook 点有内容

### 阶段二.B：修复 Hook 渲染问题（如果 Hook 渲染失败）

#### 步骤 B1：检查 FlutterRenderer
- [ ] 查看 `FlutterRenderer.render()` 方法
- [ ] 确认渲染逻辑正确
- [ ] 检查是否有尺寸计算错误

#### 步骤 B2：检查 Hook 内容
- [ ] 确认 `SidebarNodeListHook.buildContent()` 返回有效 Widget
- [ ] 检查 Hook 的 `isVisible()` 方法
- [ ] 验证 Hook 上下文数据正确传递

#### 步骤 B3：修复渲染 bug
- [ ] 根据具体 bug 修复渲染逻辑
- [ ] 确保 Hook 组件有正确的尺寸约束
- [ ] 添加错误边界处理

### 阶段二.C：修复 BLoC 状态问题（如果 BLoC 状态异常）

#### 步骤 C1：检查 GraphBloc 初始化
- [ ] 查看 `GraphBloc.onInit()` 方法
- [ ] 确认是否正确加载或创建图
- [ ] 检查 `GraphInitializeEvent` 处理逻辑

```dart
// 确保 GraphBloc 初始化时创建或加载图
Future<void> _onInitialize() async {
  final graph = await _graphRepository.getCurrent();
  if (graph == null) {
    // 创建新图
    emit(state.copyWith(graph: Graph(...)));
  } else {
    // 加载现有图
    emit(state.copyWith(graph: graph));
  }
}
```

#### 步骤 C2：检查 NodeBloc 初始化
- [ ] 查看 `NodeBloc.onInit()` 方法
- [ ] 确认是否正确加载节点
- [ ] 检查 `NodeLoadAllEvent` 处理逻辑

#### 步骤 C3：添加调试日志
- [ ] 在 BLoC 的 `emit()` 前后添加日志
- [ ] 记录状态变化的详细信息
- [ ] 使用 `flutter_bloc` 的 `BlocObserver` 跟踪状态流

```dart
// 在 app.dart 中添加 BlocObserver
Bloc.observer = SimpleBlocObserver();
```

### 阶段三：测试与验证（1 小时）

#### 3.1 启动测试
- [ ] 重新启动应用（非沙盒环境）
- [ ] 验证所有 UI 组件可见
- [ ] 检查控制台无错误日志

#### 3.2 功能测试
- [ ] 测试节点创建、编辑、删除
- [ ] 测试图操作（添加节点、连接节点）
- [ ] 测试侧边栏节点列表
- [ ] 测试工具栏功能按钮

#### 3.3 边界测试
- [ ] 测试空图状态
- [ ] 测试大量节点渲染
- [ ] 测试窗口大小调整

## 技术细节

### 关键文件

#### Repository 层（权限问题相关）
- `lib/core/repositories/node_repository.dart` - NodeRepository 实现（130-136 行权限检查）
- `lib/core/repositories/graph_repository.dart` - GraphRepository 实现（89-96 行权限检查）
- `lib/core/services/infrastructure/storage_path_service.dart` - 存储路径服务

#### UI 渲染层
- `lib/ui/bars/sidebar.dart` - 侧边栏组件
- `lib/ui/bars/core_toolbar.dart` - 顶部工具栏组件
- `lib/ui/pages/home_page.dart` - 主页面布局
- `lib/plugins/graph/ui/graph_view.dart` - 图视图组件
- `lib/plugins/graph/flame/graph_world.dart` - Flame 渲染世界

#### Hook 系统
- `lib/core/ui_layout/ui_layout_service.dart` - UI 布局服务
- `lib/core/plugin/ui_hooks/hook_registry.dart` - Hook 注册表
- `lib/core/plugin/ui_hooks/hook_base.dart` - Hook 基类
- `lib/core/plugin/builtin_plugin_loader.dart` - 插件加载器

#### BLoC 层
- `lib/plugins/graph/bloc/graph_bloc.dart` - 图状态管理
- `lib/plugins/graph/bloc/node_bloc.dart` - 节点状态管理
- `lib/ui/bloc/ui_bloc.dart` - UI 状态管理

### 关键代码位置

#### 权限检查（node_repository.dart:130-136）
```dart
// 验证目录可写
try {
  final testFile = File(path.join(_nodesDir, '.write_test'));
  await testFile.writeAsString('test');
  await testFile.delete();
} catch (e) {
  throw RepositoryException('Nodes directory is not writable: $e');
}
```

#### 应用初始化（app.dart:119-128）
```dart
if (_nodeRepository is FileSystemNodeRepository) {
  _log.info('Initializing NodeRepository...');
  await (_nodeRepository as FileSystemNodeRepository).init();
  _log.info('[App] ✓ NodeRepository initialized');
}
```

#### 侧边栏构建（sidebar.dart:126-143）
```dart
Widget _buildSidebar(BuildContext context) {
  try {
    final layoutService = context.read<UILayoutService>();
    final renderer = FlutterRenderer();
    final sidebarHook = layoutService.getHook('sidebar');

    if (sidebarHook != null) {
      return renderer.render(sidebarHook, {'buildContext': context});
    }

    // 如果 Hook 不存在，使用默认实现
    _log.warning('Sidebar hook not found, using default implementation');
    return _buildDefaultSidebar(context);
  } catch (e) {
    _log.error('Failed to build sidebar: $e');
    return _buildDefaultSidebar(context);
  }
}
```

### 预期修复结果

#### 修复后应该看到
1. **完整的侧边栏**
   - 标题栏（搜索/节点列表切换）
   - 标签页栏（Nodes/Folders 等）
   - 节点列表内容或文件夹树

2. **正常的主画布**
   - 节点渲染在画布上
   - 节点之间的连接线
   - 支持拖拽、缩放操作

3. **完整的工具栏**
   - 顶部工具栏功能按钮
   - 浮动工具栏（如果在图中）

### 风险与注意事项

#### 风险
1. **权限修复可能不完全**：某些系统环境下权限问题可能无法彻底解决
2. **路径变更影响**：更改存储路径可能影响现有数据
3. **安全性考虑**：绕过权限检查可能带来安全风险
4. **数据丢失**：如果删除或移动数据目录，可能导致数据丢失

#### 注意事项
1. **数据备份**：在修改存储路径前备份 `data` 目录
2. **用户通知**：权限问题修复过程中给用户清晰的提示
3. **降级方案**：提供只读模式作为降级方案
4. **测试覆盖**：修复后在不同环境下充分测试
5. **日志记录**：添加详细的调试日志便于问题诊断

## 时间估算

- 阶段一（诊断）：0.5-1 小时
- 阶段二.A（权限修复）：0.5-1 小时
- 阶段二.B（Hook 修复）：1-2 小时
- 阶段二.C（BLoC 修复）：1-2 小时
- 阶段三（测试）：1 小时

**总计**：3-6 小时（取决于具体问题）

## 后续优化建议

1. **存储抽象层**：将存储抽象为接口，支持多种存储后端（文件、数据库、云存储）
2. **权限诊断工具**：内置权限诊断和修复工具
3. **优雅降级**：文件系统不可用时自动切换到内存存储模式
4. **跨平台兼容**：确保在不同操作系统上的路径和权限处理正确
5. **错误恢复向导**：提供图形化的错误诊断和修复界面
