import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/commands/command_bus.dart';
import 'core/events/app_events.dart';
import 'core/execution/execution_engine.dart';
import 'core/execution/task_registry.dart';
import 'core/plugin/builtin_plugin_loader.dart';
import 'core/plugin/plugin.dart';
import 'core/plugin/plugin_manager.dart';
import 'core/plugin/ui_hooks/hook_registry.dart';
import 'core/repositories/repositories.dart';
import 'core/services/i18n.dart';
import 'core/services/services.dart';
import 'plugins/builtin_middlewares/logging_middleware.dart';
import 'plugins/builtin_middlewares/transaction_middleware.dart';
import 'plugins/builtin_middlewares/undo_middleware.dart';
import 'plugins/builtin_middlewares/validation_middleware.dart';
import 'ui/bloc/ui_bloc.dart';
import 'ui/pages/home_page.dart';

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
  late AppEventBus _eventBus;
  late TaskRegistry _taskRegistry;
  late SettingsRegistry _settingsRegistry;
  late ThemeRegistry _themeRegistry;
  late ExecutionEngine _executionEngine;
  late StoragePathService _storagePathService;
  late ServiceRegistry _serviceRegistry;
  bool _isInitialized = false;
  Object? _initError;

  @override
  void initState() {
    super.initState();
    _initializeCore();
  }

  Future<void> _initializeCore() async {
    try {
      // 1. 初始化 SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // 2. 创建存储路径服务
      _storagePathService = StoragePathService(prefs);

      // 3. 获取存储路径
      final nodesPath = await _storagePathService.getNodesPath();
      final graphsPath = await _storagePathService.getGraphsPath();

      // 4. 初始化 Repositories
      _nodeRepository = FileSystemNodeRepository(nodesDir: nodesPath);
      _graphRepository = FileSystemGraphRepository(graphsDir: graphsPath);

      // FileSystemNodeRepository 和 FileSystemGraphRepository 的 init() 方法
      if (_nodeRepository is FileSystemNodeRepository) {
        await (_nodeRepository as FileSystemNodeRepository).init();
      }
      if (_graphRepository is FileSystemGraphRepository) {
        await (_graphRepository as FileSystemGraphRepository).init();
      }

      // 5. 初始化 CommandBus 和 EventBus
      _commandBus = _createCommandBus();
      _eventBus = AppEventBus();

      // 6. 创建三个注册表
      _taskRegistry = TaskRegistry();
      _settingsRegistry = SettingsRegistry(prefs);
      _themeRegistry = ThemeRegistry();

      // 7. 初始化 ExecutionEngine（使用 TaskRegistry）
      _executionEngine = ExecutionEngine();
      await _executionEngine.initialize(
        taskRegistry: _taskRegistry,
      );

      // 8. 注册核心设置到 SettingsRegistry
      _registerCoreSettings();

      // 9. 创建动态服务注册表（新增）
      _serviceRegistry = ServiceRegistry(
        coreDependencies: {
          NodeRepository: _nodeRepository,
          GraphRepository: _graphRepository,
          CommandBus: _commandBus,
          AppEventBus: _eventBus,
          SettingsService: widget.settingsService,
          ThemeService: widget.themeService,
        },
      );

      setState(() {
        _isInitialized = true;
        _initError = null;
      });
    } catch (e) {
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

  /// 加载所有内置插件
  ///
  /// 这个方法会在 FutureBuilder 中被调用，确保插件加载完成后再显示应用界面
  Future<void> _loadPlugins(PluginManager pluginManager) async {
    try {
      final loader = BuiltinPluginLoader(
        pluginManager: pluginManager,
        hookRegistry: hookRegistry,
      );
      final count = await loader.loadAllBuiltinPlugins();
      debugPrint('[App] ✓ Loaded $count builtin plugins');
    } catch (e) {
      debugPrint('[App] ✗ Error loading builtin plugins: $e');
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
      eventBus: _eventBus,
      nodeRepository: _nodeRepository,
      graphRepository: _graphRepository,
      serviceRegistry: _serviceRegistry,
      executionEngine: _executionEngine,
      taskRegistry: _taskRegistry,
      settingsRegistry: _settingsRegistry,
      themeRegistry: _themeRegistry,
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
        // 使用 DynamicProviderWidget 支持动态插件加载
        return DynamicProviderWidget(
          serviceRegistry: _serviceRegistry,
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

            // 2. 事件总线（在 BLoC 之前注入，供 BLoC 使用）
            Provider<AppEventBus>.value(value: _eventBus),

            // 3. 命令总线（Command Bus - 业务逻辑统一入口）
            Provider<CommandBus>.value(value: _commandBus),

            // === 国际化 Provider ===
            // 4. I18n 服务（支持多语言）
            ChangeNotifierProvider<I18n>(
              create: (_) => I18n(),
            ),

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

            // === 插件 BLoC 层 ===
            // 插件提供的 Bloc（由 PluginManager 自动生成）
            // 注意：这些 BLoC 不会动态变化，所以放在 coreProviders 中
            ...pluginManager.generateBlocProviders(),
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
