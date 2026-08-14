import 'package:core/core.dart';

import '../ui/hooks/hook_contexts.dart';
import '../ui/hooks/root_layout_hook.dart';
import '../ui/hooks/sidebar_layout_hook.dart';

const _log = AppLogger('AppFrameInitializer');

/// AppFrame 初始化器
///
/// 负责 AppFrame 框架的初始化，包括：
/// - 注册标准 Hook Points
/// - 启用核心布局 Hooks (RootLayoutHook, SidebarLayoutHook)
class AppFrameInitializer {
  /// 创建 AppFrame 初始化器
  ///
  /// [hookRegistry] Hook 注册表
  AppFrameInitializer({
    required HookRoleRegistry hookRegistry,
  }) : _hookRegistry = hookRegistry;

  final HookRoleRegistry _hookRegistry;

  /// 初始化 AppFrame
  ///
  /// 执行以下步骤：
  /// 1. 注册标准 Hook Points
  /// 2. 启用核心布局 Hooks
  Future<void> initialize() async {
    _log.info('Initializing AppFrame...');

    _registerStandardHookPoints();

    await _enableCoreLayoutHooks();

    _log.info('[AppFrame] ✓ AppFrame initialized');
  }

  void _registerStandardHookPoints() {
    _log.info('Registering standard hook points...');

    final hookPoints = [
      const HookPointDefinition(
        id: 'root',
        name: 'Root',
        description: 'Root layout hook point for main window',
        category: 'layout',
        contextType: RootHookContext,
      ),
      const HookPointDefinition(
        id: 'sidebar',
        name: 'Sidebar',
        description: 'Sidebar layout hook point',
        category: 'layout',
        contextType: SidebarLayoutHookContext,
      ),
      const HookPointDefinition(
        id: 'sidebar.tab',
        name: 'Sidebar Tab',
        description: 'Sidebar tab hook point for tab plugins',
        category: 'sidebar',
        contextType: SidebarHookContext,
      ),
      const HookPointDefinition(
        id: 'main.toolbar',
        name: 'Main Toolbar',
        description: 'Main toolbar at the top of the application',
        category: 'toolbar',
        contextType: MainToolbarHookContext,
      ),
      const HookPointDefinition(
        id: 'graph.toolbar',
        name: 'Graph Toolbar',
        description: 'Draggable toolbar in the graph view',
        category: 'toolbar',
        contextType: MainToolbarHookContext,
      ),
      const HookPointDefinition(
        id: 'context_menu.node',
        name: 'Node Context Menu',
        description: 'Context menu when right-clicking on a node',
        category: 'context_menu',
        contextType: NodeContextMenuHookContext,
      ),
      const HookPointDefinition(
        id: 'context_menu.graph',
        name: 'Graph Context Menu',
        description: 'Top section of the sidebar',
        category: 'sidebar',
        contextType: SidebarHookContext,
      ),
      const HookPointDefinition(
        id: 'sidebar.bottom',
        name: 'Sidebar Bottom',
        description: 'Bottom section of the sidebar',
        category: 'sidebar',
        contextType: SidebarHookContext,
      ),
      const HookPointDefinition(
        id: 'status.bar',
        name: 'Status Bar',
        description: 'Status bar at the bottom of the application',
        category: 'status_bar',
        contextType: StatusBarHookContext,
      ),
      const HookPointDefinition(
        id: 'help',
        name: 'Help',
        description: 'Help and documentation',
        category: 'help',
        contextType: HelpHookContext,
      ),
    ];

    hookPoints.forEach(_hookRegistry.registerHookPoint);

    _log.info(
        '[AppFrame] ✓ Registered ${_hookRegistry.getAllHookPoints().length} standard hook points');
  }

  Future<void> _enableCoreLayoutHooks() async {
    _log.info('Registering RootLayoutHook...');
    final rootHook = RootLayoutHook();
    _hookRegistry.registerHook(rootHook);

    _log.info('Enabling RootLayoutHook...');
    final rootWrappers =
        _hookRegistry.getHookWrappers('root', includeDisabled: true);
    final rootWrapper = rootWrappers.firstWhere(
      (w) => w.hook.metadata.id == 'root.layout',
      orElse: () => throw StateError('RootLayoutHook not found'),
    );
    final rootContext = RootHookContext(
      data: {},
      hookAPIRegistry: _hookRegistry.apiRegistry,
    );
    await rootWrapper.lifecycle.transitionTo(
      HookState.initialized,
      () => rootWrapper.hook.onInit(rootContext),
    );
    await rootWrapper.lifecycle.transitionTo(
      HookState.enabled,
      rootWrapper.hook.onEnable,
    );
    _log.info('[AppFrame] ✓ RootLayoutHook enabled');

    _log.info('Registering SidebarLayoutHook...');
    final sidebarHook = SidebarLayoutHook();
    _hookRegistry.registerHook(sidebarHook);

    _log.info('Enabling SidebarLayoutHook...');
    final sidebarWrappers =
        _hookRegistry.getHookWrappers('sidebar', includeDisabled: true);
    final sidebarWrapper = sidebarWrappers.firstWhere(
      (w) => w.hook.metadata.id == 'sidebar.layout',
      orElse: () => throw StateError('SidebarLayoutHook not found'),
    );
    final sidebarContext = SidebarLayoutHookContext(
      data: {},
      hookAPIRegistry: _hookRegistry.apiRegistry,
    );
    await sidebarWrapper.lifecycle.transitionTo(
      HookState.initialized,
      () => sidebarWrapper.hook.onInit(sidebarContext),
    );
    await sidebarWrapper.lifecycle.transitionTo(
      HookState.enabled,
      sidebarWrapper.hook.onEnable,
    );
    _log.info('[AppFrame] ✓ SidebarLayoutHook enabled');
  }
}