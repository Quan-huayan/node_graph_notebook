import 'package:flutter/material.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/converter/bloc/converter_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/converter/service/import_export_service.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/graph_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/graph_event.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/node_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/node_event.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/service/graph_service.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/service/node_service.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/search/bloc/search_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/search/service/search_preset_service.dart';
import 'package:node_graph_notebook/ui/bloc/ui_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'plugins/builtin_plugins/converter/service/converter_service.dart';
import 'plugins/builtin_plugins/converter/service/converter_service_impl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/repositories/repositories.dart';
import 'core/services/services.dart';
import 'core/services/theme/app_theme.dart';
import 'core/events/app_events.dart';
import 'core/commands/command_bus.dart';
import 'plugins/builtin_plugins/graph/command/node_commands.dart';
import 'plugins/builtin_plugins/graph/command/graph_commands.dart';
import 'plugins/builtin_plugins/layout/command/layout_commands.dart';
import 'plugins/builtin_plugins/ai/command/ai_commands.dart';
import 'plugins/builtin_plugins/graph/handler/create_node_handler.dart';
import 'plugins/builtin_plugins/graph/handler/update_node_handler.dart';
import 'plugins/builtin_plugins/graph/handler/delete_node_handler.dart';
import 'plugins/builtin_plugins/graph/handler/connect_nodes_handler.dart';
import 'plugins/builtin_plugins/graph/handler/disconnect_nodes_handler.dart';
import 'plugins/builtin_plugins/graph/handler/move_node_handler.dart';
import 'plugins/builtin_plugins/graph/handler/resize_node_handler.dart';
import 'plugins/builtin_plugins/layout/handler/apply_layout_handler.dart';
import 'plugins/builtin_plugins/ai/handler/analyze_node_handler.dart';
import 'plugins/builtin_plugins/graph/handler/load_graph_handler.dart';
import 'plugins/builtin_plugins/graph/handler/create_graph_handler.dart';
import 'plugins/builtin_plugins/graph/handler/update_graph_handler.dart';
import 'plugins/builtin_plugins/graph/handler/rename_graph_handler.dart';
import 'plugins/builtin_plugins/graph/handler/add_node_to_graph_handler.dart';
import 'plugins/builtin_plugins/graph/handler/remove_node_from_graph_handler.dart';
import 'plugins/builtin_plugins/graph/handler/update_node_position_handler.dart';
import 'plugins/builtin_middlewares/logging_middleware.dart';
import 'plugins/builtin_middlewares/validation_middleware.dart';
import 'plugins/builtin_middlewares/transaction_middleware.dart';
import 'plugins/builtin_middlewares/undo_middleware.dart';
import 'plugins/builtin_plugins/layout/service/layout_service.dart';
import 'plugins/builtin_plugins/ai/service/ai_service.dart';
import 'core/plugin/plugin_manager.dart';
import 'core/plugin/builtin_plugin_loader.dart';
import 'core/plugin/ui_hooks/hook_registry.dart';
import 'ui/pages/home_page.dart';

class NodeGraphNotebookApp extends StatefulWidget {
  const NodeGraphNotebookApp({
    super.key,
    required this.settingsService,
    required this.themeService,
  });

  final SettingsService settingsService;
  final ThemeService themeService;

  @override
  State<NodeGraphNotebookApp> createState() => _NodeGraphNotebookAppState();
}

class _NodeGraphNotebookAppState extends State<NodeGraphNotebookApp> {
  late NodeRepository _nodeRepository;
  late GraphRepository _graphRepository;
  bool _isInitialized = false;
  Object? _initError;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
  }

  Future<void> _initializeRepositories() async {
    try {
      final nodesPath = await widget.settingsService.getNodesPath();
      final graphsPath = await widget.settingsService.getGraphsPath();

      _nodeRepository = FileSystemNodeRepository(nodesDir: nodesPath);
      _graphRepository = FileSystemGraphRepository(graphsDir: graphsPath);

      // FileSystemNodeRepository 和 FileSystemGraphRepository 的 init() 方法
      if (_nodeRepository is FileSystemNodeRepository) {
        await (_nodeRepository as FileSystemNodeRepository).init();
      }
      if (_graphRepository is FileSystemGraphRepository) {
        await (_graphRepository as FileSystemGraphRepository).init();
      }

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

    return MultiProvider(
      providers: [
        // 0. 设置服务
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

        // 1. Repository 层
        Provider<NodeRepository>.value(value: _nodeRepository),
        Provider<GraphRepository>.value(value: _graphRepository),

        // 2. Service 层
        Provider<NodeService>(
          create: (ctx) => NodeServiceImpl(ctx.read<NodeRepository>()),
        ),
        Provider<GraphService>(
          create: (ctx) => GraphServiceImpl(
            ctx.read<GraphRepository>(),
            ctx.read<NodeRepository>(),
          ),
        ),
        Provider<SearchPresetService>(
          create: (ctx) => SearchPresetServiceImpl(
            ctx.read<SharedPreferencesAsync>()
          ),
        ),
        Provider<ConverterService>(
          create: (ctx) => ConverterServiceImpl(
            ctx.read<NodeRepository>(),
          ),
        ),
        Provider<ImportExportService>(
          create: (ctx) => ImportExportServiceImpl(
            ctx.read<ConverterService>(),
            ctx.read<NodeService>(),
            ctx.read<GraphService>(),
          ),
        ),
        Provider<ConverterService>(
          create: (ctx) => ConverterServiceImpl(
            ctx.read<NodeRepository>(),
          ),
        ),
        ChangeNotifierProvider<AIServiceImpl>(
          create: (ctx) {
            final ai = AIServiceImpl();
            final settings = ctx.read<SettingsService>();
            void update() {
              if (settings.isAIConfigured) {
                final provider = settings.aiProvider == 'anthropic'
                    ? AnthropicProvider(
                        apiKey: settings.aiApiKey!,
                        model: settings.aiModel,
                        baseUrl: settings.aiBaseUrl,
                      )
                    : OpenAIProvider(
                        apiKey: settings.aiApiKey!,
                        model: settings.aiModel,
                        baseUrl: settings.aiBaseUrl,
                      );
                ai.setProvider(provider);
              }
            }
            // initial config and listen for changes
            update();
            settings.addListener(update);
            return ai;
          },
        ),



        // 2.1.5 Layout Service
        Provider<LayoutService>(
          create: (_) => LayoutServiceImpl(),
        ),

        // 2.2 事件总线（在 BLoC 之前注入，供 BLoC 使用）
        Provider<AppEventBus>(
          create: (_) => AppEventBus(),
          dispose: (_, bus) => bus.dispose(),
        ),

        // 2.2.5 撤销中间件（在 CommandBus 之前注入）
        Provider<UndoMiddleware>(
          create: (_) => UndoMiddleware(maxStackSize: 50),
          dispose: (_, middleware) => middleware.clear(),
        ),

        // 2.3 命令总线（Command Bus - 业务逻辑统一入口）
        Provider<CommandBus>(
          create: (ctx) {
            final undoMiddleware = ctx.read<UndoMiddleware>();

            final commandBus = CommandBus()
              // 添加中间件（注意顺序：UndoMiddleware 应该在最后，确保命令成功后才追踪）
              ..addMiddleware(LoggingMiddleware(
                logLevel: LogLevel.info,
                includeTimestamp: true,
                includeDuration: true,
              ))
              ..addMiddleware(TransactionMiddleware())
              ..addMiddleware(ValidationMiddleware())
              ..addMiddleware(undoMiddleware);

            // 注册节点命令处理器
            final nodeService = ctx.read<NodeService>();
            final nodeRepository = ctx.read<NodeRepository>();

            commandBus.registerHandler<CreateNodeCommand>(
              CreateNodeHandler(nodeService),
              CreateNodeCommand,
            );
            commandBus.registerHandler<UpdateNodeCommand>(
              UpdateNodeHandler(nodeService),
              UpdateNodeCommand,
            );
            commandBus.registerHandler<DeleteNodeCommand>(
              DeleteNodeHandler(nodeService),
              DeleteNodeCommand,
            );
            commandBus.registerHandler<ConnectNodesCommand>(
              ConnectNodesHandler(nodeRepository),
              ConnectNodesCommand,
            );
            commandBus.registerHandler<DisconnectNodesCommand>(
              DisconnectNodesHandler(nodeRepository),
              DisconnectNodesCommand,
            );
            commandBus.registerHandler<MoveNodeCommand>(
              MoveNodeHandler(nodeRepository),
              MoveNodeCommand,
            );
            commandBus.registerHandler<ResizeNodeCommand>(
              ResizeNodeHandler(nodeRepository),
              ResizeNodeCommand,
            );

            // 注册图命令处理器
            final graphService = ctx.read<GraphService>();
            final graphRepository = ctx.read<GraphRepository>();

            commandBus.registerHandler<LoadGraphCommand>(
              LoadGraphHandler(graphService),
              LoadGraphCommand,
            );
            commandBus.registerHandler<CreateGraphCommand>(
              CreateGraphHandler(graphService),
              CreateGraphCommand,
            );
            commandBus.registerHandler<UpdateGraphCommand>(
              UpdateGraphHandler(graphService),
              UpdateGraphCommand,
            );
            commandBus.registerHandler<RenameGraphCommand>(
              RenameGraphHandler(graphService),
              RenameGraphCommand,
            );
            commandBus.registerHandler<AddNodeToGraphCommand>(
              AddNodeToGraphHandler(graphService),
              AddNodeToGraphCommand,
            );
            commandBus.registerHandler<RemoveNodeFromGraphCommand>(
              RemoveNodeFromGraphHandler(graphService),
              RemoveNodeFromGraphCommand,
            );
            commandBus.registerHandler<UpdateNodePositionCommand>(
              UpdateNodePositionHandler(graphRepository),
              UpdateNodePositionCommand,
            );

            // 注册布局命令处理器
            final layoutService = ctx.read<LayoutService>();
            commandBus.registerHandler<ApplyLayoutCommand>(
              ApplyLayoutHandler(graphService, layoutService, commandBus),
              ApplyLayoutCommand,
            );
            commandBus.registerHandler<BatchMoveNodesCommand>(
              BatchMoveNodesHandler(nodeRepository),
              BatchMoveNodesCommand,
            );

            // 注册 AI 命令处理器
            final aiService = ctx.read<AIServiceImpl>();
            commandBus.registerHandler<AnalyzeNodeCommand>(
              AnalyzeNodeHandler(aiService),
              AnalyzeNodeCommand,
            );
            commandBus.registerHandler<SuggestConnectionsCommand>(
              SuggestConnectionsHandler(aiService),
              SuggestConnectionsCommand,
            );
            commandBus.registerHandler<GenerateGraphSummaryCommand>(
              GenerateGraphSummaryHandler(aiService, nodeRepository),
              GenerateGraphSummaryCommand,
            );
            commandBus.registerHandler<GenerateNodeCommand>(
              GenerateNodeHandler(aiService, nodeService),
              GenerateNodeCommand,
            );

            return commandBus;
          },
          dispose: (_, bus) => bus.dispose(),
        ),

        // 2.4 BLoC 层
        // 注意：NodeBloc 和 GraphBloc 通过事件总线解耦，不再有直接依赖
        // NodeBloc 现在通过 CommandBus 执行写操作，通过 Repository 执行读操作
        BlocProvider<NodeBloc>(
          create: (ctx) => NodeBloc(
            commandBus: ctx.read<CommandBus>(),
            nodeRepository: ctx.read<NodeRepository>(),
            eventBus: ctx.read<AppEventBus>(),
          )..add(const NodeLoadEvent()),
        ),
        BlocProvider<GraphBloc>(
          create: (ctx) => GraphBloc(
            commandBus: ctx.read<CommandBus>(),
            graphRepository: ctx.read<GraphRepository>(),
            nodeRepository: ctx.read<NodeRepository>(),
            eventBus: ctx.read<AppEventBus>(),
          )..add(const GraphInitializeEvent()),
        ),
        BlocProvider<UIBloc>(
          create: (_) => UIBloc(),
        ),
        BlocProvider<SearchBloc>(
          create: (ctx) => SearchBloc(
            nodeService: ctx.read<NodeService>(),
            presetService: ctx.read<SearchPresetService>(),
          ),
        ),
        BlocProvider<ConverterBloc>(
          create: (ctx) => ConverterBloc(
            importExportService: ctx.read<ImportExportService>(),
          ),
        ),

        // 2.5 插件系统
        // Hook Registry（全局单例）
        Provider<HookRegistry>(
          create: (_) => hookRegistry,
          dispose: (_, registry) => registry.clear(),
        ),

        // Plugin Manager
        Provider<PluginManager>(
          create: (ctx) {
            final manager = PluginManager(
              commandBus: ctx.read<CommandBus>(),
              eventBus: ctx.read<AppEventBus>(),
              nodeRepository: ctx.read<NodeRepository>(),
              graphRepository: ctx.read<GraphRepository>(),
            );

            // 异步加载内置插件（不阻塞启动）
            Future.microtask(() async {
              try {
                final loader = BuiltinPluginLoader(
                  pluginManager: manager,
                  hookRegistry: hookRegistry,
                );
                final count = await loader.loadAllBuiltinPlugins();
                debugPrint('[App] Loaded $count builtin plugins');
              } catch (e) {
                debugPrint('[App] Error loading builtin plugins: $e');
              }
            });

            return manager;
          },
          dispose: (_, manager) {
            // 清理插件管理器
            Future.microtask(() async {
              try {
                final loader = BuiltinPluginLoader(pluginManager: manager);
                await loader.unloadAllBuiltinPlugins();
              } catch (e) {
                debugPrint('[App] Error unloading plugins: $e');
              }
            });
          },
        ),
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
  }

  /// 构建错误恢复界面
  Widget _buildErrorUI() {
    final recoveryService = DataRecoveryService(
      nodeRepository: FileSystemNodeRepository(),
      graphRepository: FileSystemGraphRepository(),
      settingsService: widget.settingsService,
    );

    final isRecoverable = recoveryService.isRecoverableError(_initError!);
    final errorMessage = recoveryService.getRecoveryMessage(_initError!);

    return MaterialApp(
      home: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.red.shade50,
                Colors.red.shade100,
              ],
            ),
          ),
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '初始化失败',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_initError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '错误详情: ${_initError.toString()}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 32),
                      if (isRecoverable) ...[
                        ElevatedButton.icon(
                          onPressed: () => _attemptRecovery(recoveryService),
                          icon: const Icon(Icons.build),
                          label: const Text('修复数据'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => _resetToDefaults(),
                        icon: const Icon(Icons.restore),
                        label: const Text('重置为默认设置'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => _chooseNewStorageLocation(),
                        icon: const Icon(Icons.folder_open),
                        label: const Text('选择新的存储位置'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 尝试修复数据
  Future<void> _attemptRecovery(DataRecoveryService recoveryService) async {
    setState(() {
      _initError = null;
    });

    try {
      final result = await recoveryService.repairData();

      if (result.success) {
        // 修复成功，重新初始化
        await _initializeRepositories();
      } else {
        // 修复失败，显示错误
        setState(() {
          _initError = Exception(result.message ?? '修复失败');
        });
      }
    } catch (e) {
      setState(() {
        _initError = e;
      });
    }
  }

  /// 重置为默认设置
  Future<void> _resetToDefaults() async {
    await widget.settingsService.resetToDefaults();
    // 重新初始化
    await _initializeRepositories();
  }

  /// 选择新的存储位置
  Future<void> _chooseNewStorageLocation() async {
    final newPath = await widget.settingsService.selectStoragePath();
    if (newPath != null) {
      // 重新初始化
      await _initializeRepositories();
    }
  }
}
