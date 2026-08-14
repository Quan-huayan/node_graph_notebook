/// HostRuntime —— 组合根（架构 §4 启动序列）。
///
/// 装配顺序（对照 CLAUDE.md 旧 DI 顺序，差异 NEW/REMOVED）：
/// 3. FSTGraph / FileLayer / FSUIStateStore（NEW，替代旧仓库）
/// 4. CommandBus（插件扩展点路由）+ 写后通知
/// 5. ConceptRegistry（扩展点派生）+ AcyclicChecker
/// 6. HookIndex / WindowManager / UIManager（NEW，替代旧 HookRegistry）
/// 7. ServiceCollection（plugon，owned 视图）
/// 8. PluginManager.loadPlugin（占位 → owned(id) → registerExtensions →
///    onLoad → enable，拓扑序）
/// 9. 宿主插件装配（调用方传入）
/// 10. 前端图建立：根 Node → materializeRoot → 递归（物化按需）
///
/// 失败行为（架构 §4）：任一步失败 → 数据恢复流程（调用方处理），
/// 不崩溃启动。
library;

import 'dart:io';

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:plugon/plugon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../command/create_toolbar_button.dart';
import '../i18n/i18n_service.dart';
import '../interaction/drag_controller.dart';
import '../render/flutter_render_context.dart';
import '../spatial/quad_tree_viewport_query.dart';
import '../store/fs_graph.dart';
import '../store/fs_ui_state_store.dart';
import '../ui/hook_view.dart';
import '../ui/shell_signals.dart';
import '../ui/theme_controller.dart';
import '../ui/toolbar_concept.dart';
import '../ui/toolbar_container_concept.dart';

/// 宿主组合根：装配存储 / 机制 / plugon 编排 / 前端图。
class HostRuntime {
  /// 数据根目录初始化（SharedPreferences/路径服务为 app 层职责）。
  ///
  /// [viewportQuery] 空间索引（P2-4：缺省 = QuadTreeViewportQuery——
  /// 生产视口窗口化接线，架构 §5.1；测试可传 FixedViewportQuery 或
  /// 显式空实现）；
  /// [renderRoot] 渲染目标（缺省 FlutterRenderContext）；
  /// [prefs] 设置持久化（P1-1：app 层注入——theme/i18n 读回上次值并
  /// 自动保存；null = 纯内存，测试/无持久化场景）。
  HostRuntime({
    required Directory dataRoot,
    ViewportQuery? viewportQuery,
    RenderContext? renderRoot,
    SharedPreferences? prefs,
  }) : graph = FSTGraph(dataRoot: dataRoot),
       uiStateStore = FSUIStateStore(dataRoot: dataRoot),
       hookIndex = HookIndex(),
       window = WindowManagerImpl(),
       _dataRoot = dataRoot,
       prefs = prefs,
       _renderRoot = renderRoot ?? FlutterRenderContext() {
    // 视口查询在构造体装配（依赖已初始化的 uiStateStore 字段）。
    _viewportQuery = viewportQuery ?? QuadTreeViewportQuery(uiStateStore: uiStateStore);
    // 扩展点 / 派生查询器 / 路由总线共享同一注册表（initializer 内
    // 无法引用实例字段，故在构造体装配）。
    extensions = ExtensionRegistry();
    commandBus = PluginCommandBus(extensions: extensions);
    // 撤销（P1-2，03 §四 契约落地）：UndoManager 经 executeRaw 执行
    // 对偶命令（不重复记录）；总线 dispatch 成功后自动 record。
    undoManager = UndoManager(dispatchRaw: commandBus.executeRaw);
    commandBus.undoManager = undoManager;
    concepts = PluginConceptRegistry(extensions: extensions);
    // 核心服务注册（插件 onLoad 经 plugon DI 解析）。
    // CommandBus 注册（M7：Lua 插件宿主写 API 需 dispatch——闭包延迟
    // 求值，dispatch 时 commandBus 已初始化）。
    // ToolbarActionRegistry（M7：工具栏按钮动作注册——插件 UI 归插件，
    // app 只播种按钮节点）。
    services
      // M7.2（阶段 C）：组合根本身注册为服务——插件打开设置容器等
      // 需构造 HookView（host 是渲染宿主通道），经 DI 解析不依赖类型。
      ..addSingleton<HostRuntime>((sp) => this)
      ..addSingleton<Graph>((sp) => graph)
      ..addSingleton<UIStateStore>((sp) => uiStateStore)
      ..addSingleton<CommandBus>((sp) => commandBus)
      ..addSingleton<ToolbarActionRegistry>((sp) => toolbarActions)
      // P1-4：壳层信号服务（侧边栏 tab 切换等跨插件协调）。
      ..addSingleton<ShellSignals>((sp) => shellSignals)
      // M7.2（E3 主题接线）：壳层主题控制器注册为服务——设置插件
      // 经 DI 编辑，NotebookApp 消费（拍板 #39"组合根注入"）。
      ..addSingleton<ThemeController>((sp) => themeController)
      // M7.2（i18n 上移壳层）：国际化服务注册——全局文案统一解析
      // （插件互不依赖的根因修正：语言包在插件里不可达）。
      ..addSingleton<I18nService>((sp) => i18nService)
      // M7.3（Flowing UI 拖入语义）：宿主缺省注册（返回 null = 默认
      // folder/建按钮语义）；插件 last-wins 覆盖（node_ai → AI 面板）。
      ..addSingleton<SidebarDropSemantics>(
        (sp) =>
            ({required draggedNodeId, required targetContainerId}) => null,
      )
      ..addSingleton<ToolbarDropSemantics>(
        (sp) =>
            ({required draggedNodeId}) => null,
      );
    // P1-1：设置持久化绑定（构造体执行——字段已初始化）。
    themeController.attach(prefs);
    i18nService.attach(prefs);
  }

  /// 工具栏动作注册表（插件注册按钮动作，AppShell 按钮点击查此）。
  final ToolbarActionRegistry toolbarActions = ToolbarActionRegistry();

  /// 壳层信号（P1-4：快捷键等跨插件会话态通道）。
  final ShellSignals shellSignals = ShellSignals();

  /// 主题控制器（壳层状态：MaterialApp 消费，设置插件编辑）。
  final ThemeController themeController = ThemeController();

  /// 国际化服务（壳层状态：全局文案；语言设置条目编辑）。
  final I18nService i18nService = I18nService();

  /// 数据根目录（M7：Lua 插件脚本目录 data/lua_scripts 定位）。
  Directory get dataRoot => _dataRoot;

  final Directory _dataRoot;

  /// 设置持久化（P1-1：app 层注入；null = 测试/无持久化场景。
  /// P1-6：首启引导标记 onboarding.shown 经此读写）。
  final SharedPreferences? prefs;

  /// 结构存储（sidecar + 内容镜像）。
  final FSTGraph graph;

  /// 外观存储（KV）。
  final FSUIStateStore uiStateStore;

  /// 命令路由（扩展点 + 宿主级注册）。
  late final PluginCommandBus commandBus;

  /// 撤销管理器（Ctrl+Z/Ctrl+Y 入口；inverse 栈跨插件共享）。
  late final UndoManager undoManager;

  /// 扩展注册表（plugon）。
  late final ExtensionRegistry extensions;

  /// 归属判定（扩展点实时派生，禁用即兜底）。
  late final PluginConceptRegistry concepts;

  /// nodeId → hookId 索引。
  final HookIndex hookIndex;

  /// 窗口登记。
  final WindowManagerImpl window;

  /// UI 管理器（物化/失效/降级）。
  late final WindowedUIManager uiManager;

  /// DI 容器（plugon owned 视图）。
  final ServiceCollection services = ServiceCollection();

  /// 插件生命周期编排（plugon）。
  late final PluginManager pluginManager;

  /// 已加载的内置插件（宿主传入，start 时记录；AppBar 展示用）。
  late final List<Plugin> loadedPlugins;

  /// 已启动。
  bool started = false;

  late final ViewportQuery _viewportQuery;
  final RenderContext _renderRoot;

  /// 启动（架构 §4 序列 8-10）：加载插件 → 前端图从根建立。
  ///
  /// [plugins] 内置插件集（BuiltinPluginLoader 职责，宿主传入）；
  /// [rootNodeId] 前端图根 Node。
  Future<void> start({
    required List<Plugin> plugins,
    required String rootNodeId,
    String rootKind = 'root',
  }) async {
    pluginManager = PluginManager(services: services, extensions: extensions);
    // 宿主声明扩展点（plugon 拼写错误保护：先注册才能贡献）。
    extensions
      ..registerExtensionPoint(conceptPoint)
      ..registerExtensionPoint(commandHandlerPoint);
    // 宿主级贡献：ToolbarConcept（UI 节点机制——工具栏按钮 = 节点，
    // 00"All is Node"落地）+ ToolbarContainerConcept（M7.2：工具栏
    // 容器 = 容器 Node 的 Hook，00 删除清单）。owner = null = 宿主贡献
    // （plugon 约定：宿主贡献恒活跃，不随插件卸载）。
    extensions.addContribution(
      conceptPoint,
      const ToolbarConcept(),
      ownerPluginId: null,
    );
    extensions.addContribution(
      conceptPoint,
      const ToolbarContainerConcept(),
      ownerPluginId: null,
    );
    // 宿主级通用写命令（M4 机制：环校验 + 落盘 + 写后通知）。
    commandBus.register(MoveReferencesHandler(graph: graph));
    // M7.3：拖拽建工具栏按钮（判据①，All is Node——按钮 = 节点）。
    commandBus.register(CreateToolbarButtonHandler(graphProvider: () => graph));
    // M7.3：'node.open' 目标动作（拖拽建按钮的点击语义——打开目标
    // 节点对话框，渲染节点 Hook：AI → 对话视图、笔记 → 编辑器）。
    toolbarActions.registerTargeted('node.open', (ctx, nodeId) {
      if (graph.get(nodeId) == null) {
        return;
      }
      showDialog<void>(
        context: ctx,
        builder: (context) => Dialog(
          child: SizedBox(
            width: 640,
            height: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: i18nService.t('dialog.close'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: HookView(
                    host: this,
                    nodeId: nodeId,
                    kind: 'open',
                    recycleOnDispose: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
    loadedPlugins = List<Plugin>.unmodifiable(plugins);
    // M7 修正（插件 UI 归插件）：已装插件列表注册为服务
    // （market 插件对话框数据源——不依赖组合根 host）。
    services.addSingleton<List<Plugin>>((sp) => loadedPlugins);
    // 8. 插件加载（拓扑序启用由 PluginManager 保证）。
    for (final plugin in plugins) {
      await pluginManager.loadPlugin(plugin);
    }
    // 6. UI 管理器（依赖 concepts/hookIndex/window 已就位）。
    uiManager = WindowedUIManager(
      graph: graph,
      concepts: concepts,
      index: hookIndex,
      window: window,
      materializer: MaterializerImpl(
        graph: graph,
        concepts: concepts,
        window: window,
        index: hookIndex,
        renderRoot: _renderRoot,
      ),
      query: _viewportQuery,
    );
    // 写后通知 → UI 管理器失效路由（单播桥，03 §四）。
    commandBus.attach(uiManager.onWriteResult);
    // 10. 前端图建立：根 Node 物化（物化按需，窗口化）。
    uiManager.materializeRoot(rootNodeId, kind: rootKind);
    started = true;
  }

  /// 停用插件 → 降级渲染联动（§5.4：扩展停用 → findFor 兜底）。
  Future<void> disablePlugin(String pluginId) async {
    await pluginManager.disablePlugin(pluginId);
    uiManager.onConceptsChanged();
  }

  /// 卸载插件 → 清理 + 降级渲染联动（§5.4：removeOwner → 兜底）。
  Future<void> unloadPlugin(String pluginId) async {
    await pluginManager.unloadPlugin(pluginId);
    uiManager.onConceptsChanged();
  }

  /// 插件服务解析入口（M7 修正，plugon 契约对齐）：每次调用返回
  /// **当前最新** provider（`pluginManager.services` getter 惰性构建）。
  ///
  /// plugon 的 loadPlugin 每次会 dispose 旧 provider（晚注册描述符纳入
  /// 新 provider 的契约）——插件 onLoad 保存的 provider 快照在多插件
  /// 场景失效（M6 单插件测试未暴露，M7 引入 AiPlugin 后暴露）。
  /// 插件的延迟解析闭包必须经此入口（运行时求值），而非 onLoad 快照。
  ServiceProvider get serviceProvider => pluginManager.services;

  /// 全部卸载（应用退出）。
  Future<void> dispose() => pluginManager.dispose();
}
