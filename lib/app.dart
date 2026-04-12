import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/commands/command_bus.dart';
import 'core/cqrs/handlers/advanced_search_handler.dart';
import 'core/cqrs/handlers/graph_query_handler.dart';
import 'core/cqrs/handlers/list_nodes_handler.dart';
import 'core/cqrs/handlers/load_node_handler.dart';
import 'core/cqrs/handlers/search_index_handler.dart';
import 'core/cqrs/handlers/search_nodes_handler.dart';
import 'core/cqrs/materialized_views/search_index_view.dart';
import 'core/cqrs/queries/advanced_search_query.dart';
import 'core/cqrs/queries/graph_query.dart';
import 'core/cqrs/queries/list_nodes_query.dart';
import 'core/cqrs/queries/load_node_query.dart';
import 'core/cqrs/queries/search_index_query.dart';
import 'core/cqrs/queries/search_nodes_query.dart';
import 'core/cqrs/query/query_bus.dart';
import 'core/cqrs/read_models/node_read_model.dart';
import 'core/execution/execution_engine.dart';
import 'core/execution/task_registry.dart';
import 'core/graph/adjacency_list.dart';
import 'core/middleware/logging_middleware.dart';
import 'core/middleware/transaction_middleware.dart';
import 'core/middleware/undo_middleware.dart';
import 'core/middleware/validation_middleware.dart';
import 'core/models/node.dart';
import 'core/plugin/builtin_plugin_loader.dart';
import 'core/plugin/dynamic_provider_widget.dart';
import 'core/plugin/plugin.dart';
import 'core/plugin/ui_hooks/hook_context.dart';
import 'core/plugin/ui_hooks/hook_point_registry.dart';
import 'core/plugin/ui_hooks/hook_registry.dart';
import 'core/repositories/repositories.dart';
import 'core/services/services.dart';
import 'core/ui_layout/ui_layout_service.dart';
import 'core/utils/logger.dart';
import 'ui/bloc/ui_bloc.dart';
import 'ui/pages/home_page.dart';

const _log = AppLogger('App');

/// 应用程序的主类
///
/// 负责初始化应用程序的核心组件，包括仓库、服务、命令总线和插件系统
class NodeGraphNotebookApp extends StatefulWidget {
  /// 创建一个新的应用程序实例
  ///
  /// [settingsService] - 设置服务
  /// [themeService] - 主题服务
  const NodeGraphNotebookApp({
    super.key,
    required this.settingsService,
    required this.themeService,
  });

  /// 设置服务
  final SettingsService settingsService;

  /// 主题服务
  final ThemeService themeService;

  @override
  State<NodeGraphNotebookApp> createState() => _NodeGraphNotebookAppState();
}

class _NodeGraphNotebookAppState extends State<NodeGraphNotebookApp> {
  late NodeRepository _nodeRepository;
  late GraphRepository _graphRepository;
  late CommandBus _commandBus;
  late QueryBus _queryBus;
  late TaskRegistry _taskRegistry;
  late SettingsRegistry _settingsRegistry;
  late ThemeRegistry _themeRegistry;
  late ExecutionEngine _executionEngine;
  late StoragePathService _storagePathService;
  late SharedPreferencesAsync _sharedPreferencesAsync;
  late ServiceRegistry _serviceRegistry;
  late UILayoutService _layoutService;
  bool _isInitialized = false;
  Object? _initError;

  @override
  void initState() {
    super.initState();
    _initializeCore();
  }

  Future<void> _initializeCore() async {
    try {
      _log..info('Initializing core components...')
      
      // 1. 初始化 SharedPreferences
      ..info('Step 1: Initializing SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      _log.info('[App] ✓ SharedPreferences initialized');

      // 2. 初始化 SharedPreferencesAsync
      _sharedPreferencesAsync = SharedPreferencesAsync();

      // 3. 创建存储路径服务
      _log.info('Step 2: Creating StoragePathService...');
      _storagePathService = StoragePathService(prefs);

      // 4. 获取存储路径
      _log.info('Step 3: Getting storage paths...');
      final nodesPath = await _storagePathService.getNodesPath();
      final graphsPath = await _storagePathService.getGraphsPath();
      _log..info('[App] ✓ Nodes path: $nodesPath')
      ..info('[App] ✓ Graphs path: $graphsPath')

      // 5. 初始化 Repositories
      ..info('Step 4: Initializing repositories...');
      _nodeRepository = FileSystemNodeRepository(nodesDir: nodesPath);
      _graphRepository = FileSystemGraphRepository(graphsDir: graphsPath);

      // FileSystemNodeRepository 和 FileSystemGraphRepository 的 init() 方法
      if (_nodeRepository is FileSystemNodeRepository) {
        _log.info('Initializing NodeRepository...');
        await (_nodeRepository as FileSystemNodeRepository).init();
        _log.info('[App] ✓ NodeRepository initialized');
      }
      if (_graphRepository is FileSystemGraphRepository) {
        _log.info('Initializing GraphRepository...');
        await (_graphRepository as FileSystemGraphRepository).init();
        _log.info('[App] ✓ GraphRepository initialized');
      }

      // 6. 初始化 CommandBus 和 EventBus
      _log.info('Step 5: Creating CommandBus and EventBus...');
      _commandBus = _createCommandBus();
      _log..info('[App] ✓ CommandBus and EventBus created')

      // 7. 创建三个注册表
      ..info('Step 6: Creating registries...');
      _taskRegistry = TaskRegistry();
      _settingsRegistry = SettingsRegistry(prefs);
      _themeRegistry = ThemeRegistry();
      _log..info('[App] ✓ Registries created')

      // 8. 初始化 ExecutionEngine（使用 TaskRegistry）
      ..info('Step 7: Initializing ExecutionEngine...');
      _executionEngine = ExecutionEngine();
      await _executionEngine.initialize(
        taskRegistry: _taskRegistry,
      );
      _log.info('[App] ✓ ExecutionEngine initialized');

      // 9. 注册核心设置到 SettingsRegistry
      _log.info('Step 8: Registering core settings...');
      _registerCoreSettings();
      _log.info('[App] ✓ Core settings registered');

      // 10. 初始化 UILayoutService（在创建 ServiceRegistry 之前）
      _log.info('Step 9: Initializing UILayoutService...');
      _layoutService = UILayoutService(commandBus: _commandBus);
      await _layoutService.initialize();
      _log.info('[App] ✓ UILayoutService initialized');

      // 11. 创建动态服务注册表（在 QueryBus 之前创建）
      _log.info('Step 10: Creating ServiceRegistry...');
      _serviceRegistry = ServiceRegistry(
        coreDependencies: {
          NodeRepository: _nodeRepository,
          GraphRepository: _graphRepository,
          CommandBus: _commandBus,
          SettingsService: widget.settingsService,
          ThemeService: widget.themeService,
          SharedPreferencesAsync: _sharedPreferencesAsync,
          StoragePathService: _storagePathService,
          UILayoutService: _layoutService,
        },
      );
      _log.info('[App] ✓ ServiceRegistry created');

      // 11.5. 初始化 AdjacencyList（在 QueryBus 之前）
      _log.info('Step 10.5: Initializing AdjacencyList...');
      final adjacencyList = AdjacencyList();
      await adjacencyList.init();
      // 从现有节点构建邻接表
      final allNodes = await _nodeRepository.queryAll();
      adjacencyList.buildFromNodes(allNodes);
      _log.info('[App] ✓ AdjacencyList initialized with ${allNodes.length} nodes');

      // 12. 创建 QueryBus（依赖 ServiceRegistry）
      _log.info('Step 11: Creating QueryBus...');
      _queryBus = _createQueryBus(adjacencyList);

      // 将 QueryBus 注册到 ServiceRegistry，使其可供其他组件使用
      _serviceRegistry.registerCoreDependency<QueryBus>(QueryBus, _queryBus);
      _log.info('[App] ✓ QueryBus created and registered');

      _log.info('[App] ✓ Core initialization completed successfully');

      setState(() {
        _isInitialized = true;
        _initError = null;
      });
    } catch (e, st) {
      _log.warning('App ✗ Initialization failed: $e');
      _log.info('Stack trace: $st');
      setState(() {
        _isInitialized = false;
        _initError = e;
      });
    }
  }

  /// 注册核心设置（不依赖插件的基础设置）
  void _registerCoreSettings() {
    // 主题模式设置
    _settingsRegistry..register(SettingDefinition<String>(
      key: 'core.themeMode',
      defaultValue: 'system',
      displayName: 'Theme Mode',
      description: 'Application theme mode (light, dark, system)',
      category: 'Core',
      validator: (value) => ['light', 'dark', 'system'].contains(value) ? value : 'system',
    ))

    // 默认视图模式
    ..register(const SettingDefinition<String?>(
      key: 'core.defaultViewMode',
      defaultValue: null,
      displayName: 'Default View Mode',
      description: 'Default node view mode',
      category: 'Core',
    ));
  }

  /// 创建 CommandBus 并注册所有命令处理器
  CommandBus _createCommandBus() {
    // 创建中间件
    final undoMiddleware = UndoMiddleware(maxStackSize: 50);

    final commandBus = CommandBus()
      ..addMiddleware(
        LoggingMiddleware(
          logLevel: LogLevel.info,
          includeTimestamp: true,
          includeDuration: true,
        ),
      )
      ..addMiddleware(TransactionMiddleware())
      ..addMiddleware(ValidationMiddleware())
      ..addMiddleware(undoMiddleware);

    // 注册命令处理器将在 build 方法中的 MultiProvider create 回调中进行
    // 因为那里可以访问到 Repository 和 Service 实例

    return commandBus;
  }

  /// 创建 QueryBus 并注册查询处理器
  ///
  /// 性能优化说明：
  /// QueryBus 提供 CQRS 读操作层，支持：
  /// - 查询缓存（1000条目，LRU策略）
  /// - 查询中间件（日志、监控等）
  /// - 类型安全的查询/结果
  ///
  /// 架构说明：
  /// QueryHandler 在此方法中注册，此时 ServiceRegistry 已可用
  /// 所有 QueryHandler 从 ServiceRegistry 获取依赖的 Repository 和 Service
  QueryBus _createQueryBus(AdjacencyList adjacencyList) {
    final queryBus = QueryBus(
      serviceRegistry: _serviceRegistry,
      maxCacheSize: 1000,
      defaultCacheTtl: const Duration(minutes: 5),
    );

    // 从 ServiceRegistry 获取依赖
    final nodeRepository = _serviceRegistry.getServiceDirect<NodeRepository>();

    // 创建搜索索引物化视图
    final searchIndexView = SearchIndexMaterializedView();

    // 注册节点查询处理器
    queryBus..registerHandler<Node?, LoadNodeQuery>(
      LoadNodeQuery,
      () => LoadNodeQueryHandler(nodeRepository),
    )

    ..registerHandler<List<Node>, LoadNodesQuery>(
      LoadNodesQuery,
      () => LoadNodesQueryHandler(nodeRepository),
    )

    ..registerHandler<List<Node>, LoadAllNodesQuery>(
      LoadAllNodesQuery,
      () => LoadAllNodesQueryHandler(nodeRepository),
    )

    ..registerHandler<List<NodeReadModel>, ListNodesQuery>(
      ListNodesQuery,
      () => ListNodesQueryHandler(nodeRepository),
    )

    ..registerHandler<List<NodeReadModel>, GetNodeReadModelsQuery>(
      GetNodeReadModelsQuery,
      () => GetNodeReadModelsQueryHandler(nodeRepository),
    )

    ..registerHandler<List<Node>, SearchNodesQuery>(
      SearchNodesQuery,
      () => SearchNodesQueryHandler(nodeRepository),
    )

    ..registerHandler<List<Node>, FilterNodesQuery>(
      FilterNodesQuery,
      () => FilterNodesQueryHandler(nodeRepository),
    )

    ..registerHandler<List<Node>, AdvancedSearchQuery>(
      AdvancedSearchQuery,
      () => AdvancedSearchQueryHandler(nodeRepository),
    )

    ..registerHandler<List<Node>, GetRecentNodesQuery>(
      GetRecentNodesQuery,
      () => GetRecentNodesQueryHandler(nodeRepository),
    )

    // 注册图查询处理器
    ..registerHandler<List<Node>, GetNeighborNodesQuery>(
      GetNeighborNodesQuery,
      () => GetNeighborNodesQueryHandler(nodeRepository, adjacencyList),
    )

    ..registerHandler<List<Node>, GetOutgoingReferencesQuery>(
      GetOutgoingReferencesQuery,
      () => GetOutgoingReferencesQueryHandler(nodeRepository),
    )

    ..registerHandler<List<Node>, GetIncomingReferencesQuery>(
      GetIncomingReferencesQuery,
      () => GetIncomingReferencesQueryHandler(nodeRepository, adjacencyList),
    )

    ..registerHandler<List<Node>?, GetNodePathQuery>(
      GetNodePathQuery,
      () => GetNodePathQueryHandler(nodeRepository),
    )

    ..registerHandler<NodeDegree, GetNodeDegreeQuery>(
      GetNodeDegreeQuery,
      () => GetNodeDegreeQueryHandler(nodeRepository, adjacencyList),
    )

    // 注册搜索索引查询处理器
    ..registerHandler<List<NodeReadModel>, FastSearchQuery>(
      FastSearchQuery,
      () => FastSearchQueryHandler(searchIndexView, nodeRepository),
    )

    ..registerHandler<List<String>, GetPopularTokensQuery>(
      GetPopularTokensQuery,
      () => GetPopularTokensQueryHandler(searchIndexView),
    );

    _log.info('[App] ✓ Query handlers registered');

    return queryBus;
  }

  /// 初始化标准 Hook 点
  ///
  /// 在插件加载前注册所有标准 Hook 点，确保 Hook 系统可以正常工作
  ///
  /// 架构说明：
  /// - 将原有的 HookPointId 枚举转换为动态 Hook 点注册
  /// - 保持与现有 Hook 代码的向后兼容
  /// - 使用点分隔的层级结构命名（如 'main.toolbar'）
  /// - 提供完整的元数据和上下文类型信息
  /// - 插件可以动态注册自己的 Hook 点
  void _initializeStandardHookPoints() {
    _log.info('Initializing standard hook points...');

    // 主工具栏 Hook 点
    hookRegistry..registerHookPoint(const HookPointDefinition(
      id: 'main.toolbar',
      name: 'Main Toolbar',
      description: 'Main toolbar at the top of the application',
      category: 'toolbar',
      contextType: MainToolbarHookContext,
    ))

    // 图工具栏 Hook 点（用于可拖动工具栏）
    ..registerHookPoint(const HookPointDefinition(
      id: 'graph.toolbar',
      name: 'Graph Toolbar',
      description: 'Draggable toolbar in the graph view',
      category: 'toolbar',
      contextType: MainToolbarHookContext,
    ))

    // 节点上下文菜单 Hook 点
    ..registerHookPoint(const HookPointDefinition(
      id: 'context_menu.node',
      name: 'Node Context Menu',
      description: 'Context menu when right-clicking on a node',
      category: 'context_menu',
      contextType: NodeContextMenuHookContext,
    ))

    // 图上下文菜单 Hook 点
    ..registerHookPoint(const HookPointDefinition(
      id: 'context_menu.graph',
      name: 'Graph Context Menu',
      description: 'Top section of the sidebar',
      category: 'sidebar',
      contextType: SidebarHookContext,
    ))

    // 侧边栏底部 Hook 点
    ..registerHookPoint(const HookPointDefinition(
      id: 'sidebar.bottom',
      name: 'Sidebar Bottom',
      description: 'Bottom section of the sidebar',
      category: 'sidebar',
      contextType: SidebarHookContext,
    ))

    // 状态栏 Hook 点
    ..registerHookPoint(const HookPointDefinition(
      id: 'status.bar',
      name: 'Status Bar',
      description: 'Status bar at the bottom of the application',
      category: 'status_bar',
      contextType: StatusBarHookContext,
    ))

    // 节点编辑器 Hook 点
    ..registerHookPoint(const HookPointDefinition(
      id: 'editor.node',
      name: 'Node Editor',
      description: 'Node content editor',
      category: 'editor',
      contextType: NodeEditorHookContext,
    ))

    // 导入导出 Hook 点
    ..registerHookPoint(const HookPointDefinition(
      id: 'import_export',
      name: 'Import/Export',
      description: 'Import/export functionality',
      category: 'import_export',
      contextType: ImportExportHookContext,
    ))

    // 设置 Hook 点
    ..registerHookPoint(const HookPointDefinition(
      id: 'settings',
      name: 'Settings',
      description: 'Application settings',
      category: 'settings',
      contextType: SettingsHookContext,
    ))

    // 帮助 Hook 点
    ..registerHookPoint(const HookPointDefinition(
      id: 'help',
      name: 'Help',
      description: 'Help and documentation',
      category: 'help',
      contextType: HelpHookContext,
    ));

    _log.info('[App] ✓ Registered ${hookRegistry.getAllHookPoints().length} standard hook points');
  }

  /// 加载所有内置插件
  ///
  /// 这个方法会在 FutureBuilder 中被调用，确保插件加载完成后再显示应用界面
  Future<void> _loadPlugins(PluginManager pluginManager) async {
    try {
      _log.info('Initializing plugin system...');

      // 在加载插件前初始化标准 Hook 点，确保插件可以正确注册到这些 Hook 点
      _initializeStandardHookPoints();

      _log.info('Loading builtin plugins...');
      final loader = BuiltinPluginLoader(
        pluginManager: pluginManager,
        hookRegistry: hookRegistry,
      );
      final count = await loader.loadAllBuiltinPlugins();
      _log.info('[App] ✓ Loaded $count builtin plugins');
    } catch (e, st) {
      _log.warning('App ✗ Error loading builtin plugins: $e');
      _log.info('Stack trace: $st');
      rethrow; // 让 FutureBuilder 捕获错误
    }
  }

  @override
  Widget build(BuildContext context) {
    // 显示错误恢复界面
    if (_initError != null) {
      return _buildErrorUI();
    }

    // 显示初始化中界面
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Initializing...',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 插件管理器（需要在 MultiProvider 外部初始化，以确保插件加载完成）
    final pluginManager = PluginManager(
      commandBus: _commandBus,
      nodeRepository: _nodeRepository,
      graphRepository: _graphRepository,
      serviceRegistry: _serviceRegistry,
      executionEngine: _executionEngine,
      taskRegistry: _taskRegistry,
      settingsRegistry: _settingsRegistry,
      themeRegistry: _themeRegistry,
      sharedPreferencesAsync: _sharedPreferencesAsync,
      storagePathService: _storagePathService,
      hookRegistry: hookRegistry,
    );

    // 使用 FutureBuilder 等待插件加载完成
    return FutureBuilder<void>(
      future: _loadPlugins(pluginManager),
      builder: (context, snapshot) {
        // 显示插件加载中界面
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading plugins...',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 插件加载完成，显示应用界面
        // 使用 HybridDynamicProviderWidget 支持动态插件加载
        //
        // 架构说明：
        // - 核心 Providers：在 LayoutBuilder 外层，不因插件加载而重建
        // - 动态 Providers：在 LayoutBuilder 内层，延迟到约束确定后构建
        // - 布局约束：通过 LayoutBuilder 确保 Provider 重建时约束已确定
        //
        // Provider 顺序：
        // 1. coreProviders: 核心依赖（Settings, Repository, CommandBus 等）- 不重建
        // 2. serviceProviders: 插件服务（由 ServiceRegistry 生成）- 可重建
        // 3. blocProviders: 插件 BLoC（由 PluginManager 生成，依赖服务）- 可重建
        return HybridDynamicProviderWidget(
          serviceRegistry: _serviceRegistry,
          pluginManager: pluginManager,
          coreProviders: [
            // === 核心系统 Provider ===
            // 0. 设置服务（必须在插件 Service 之前，因为 AIService 依赖 SettingsService）
            ChangeNotifierProvider<SettingsService>.value(
              value: widget.settingsService,
            ),
            // 0.1 主题服务
            ChangeNotifierProvider<ThemeService>.value(
              value: widget.themeService,
            ),
            Provider<SharedPreferencesAsync>(
              create: (_) => SharedPreferencesAsync(),
            ),

            // 0.2 存储路径服务
            ChangeNotifierProvider<StoragePathService>.value(
              value: _storagePathService,
            ),

            // 0.3 注册表（插件和 UI 都需要）
            Provider<TaskRegistry>.value(value: _taskRegistry),
            ChangeNotifierProvider<SettingsRegistry>.value(
              value: _settingsRegistry,
            ),
            ChangeNotifierProvider<ThemeRegistry>.value(
              value: _themeRegistry,
            ),

            // 0.4 执行引擎
            Provider<ExecutionEngine>.value(value: _executionEngine),

            // 1. Repository 层（核心基础设施）
            Provider<NodeRepository>.value(value: _nodeRepository),
            Provider<GraphRepository>.value(value: _graphRepository),

            // 2. 命令总线（Command Bus - 业务逻辑统一入口）
            Provider<CommandBus>.value(value: _commandBus),

            // 3. 查询总线（Query Bus - CQRS 读操作层）
            Provider<QueryBus>.value(value: _queryBus),

            // 4. UI 布局服务（UILayoutService - 用于 Hook 树和节点附着）
            Provider<UILayoutService>.value(value: _layoutService),

            // === 国际化 Provider ===
            // 注意：I18n 服务现在由 I18nPlugin 提供
            // I18nPlugin 的 I18nServiceBinding 会自动将 I18n 服务注册到 ServiceRegistry
            // DynamicProviderWidget 会自动将其添加到 Provider 树中

            // === BLoC 层 ===
            // UI Bloc（核心 UI 状态管理）
            BlocProvider<UIBloc>(create: (_) => UIBloc()),

            // === 插件系统 ===
            // Hook Registry（全局单例）
            Provider<HookRegistry>(
              create: (_) => hookRegistry,
              dispose: (_, registry) => registry.clear(),
            ),

            // Plugin Manager（已经在 FutureBuilder 中初始化）
            Provider<PluginManager>.value(value: pluginManager),

            // 注意：插件 BLoC 由 HybridDynamicProviderWidget 自动添加
            // 顺序：Service Providers -> BLoC Providers
            // 这确保 BLoC 可以访问到它们依赖的 Service
          ],
          child: Consumer2<SettingsService, ThemeService>(
            builder: (context, settings, themeService, child) {
              final appTheme = themeService.getThemeForMode(
                settings.themeMode,
                MediaQuery.of(context).platformBrightness,
              );

              return MaterialApp(
                title: 'Node Graph Notebook',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.getMaterialTheme(appTheme, Brightness.light),
                darkTheme: AppTheme.getMaterialTheme(appTheme, Brightness.dark),
                themeMode: settings.themeMode,
                home: const HomePage(),
              );
            },
          ),
        );
      },
    );
  }

  /// 构建错误界面
  Widget _buildErrorUI() => MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Initialization Failed',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'An error occurred while initializing the app.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeCore,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
}

