import 'package:appframe/appframe.dart';
import 'package:appframe/appframe_plugin.dart';
import 'package:core/core.dart';
import 'package:core/core_plugin.dart';
import 'package:flutter/material.dart';
import 'package:node_editor/editor.dart';
import 'package:node_folder/folder.dart';
import 'package:node_graph/graph.dart';
import 'package:node_search/search_plugin.dart';
import 'package:node_settings/settings_plugin.dart';
import 'package:provider/provider.dart';
import 'package:repository_fs/repository_fs.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _AppState { loading, error, ready }

class NodeGraphNotebookApp extends StatefulWidget {
  const NodeGraphNotebookApp({super.key});

  @override
  State<NodeGraphNotebookApp> createState() => _NodeGraphNotebookAppState();
}

class _NodeGraphNotebookAppState extends State<NodeGraphNotebookApp> {
  _AppState _state = _AppState.loading;
  Object? _error;
  bool _initializing = false;

  late final ServiceRegistry _serviceRegistry;
  late final HookRoleRegistry _hookRegistry;
  late final PluginManager _pluginManager;

  @override
  void initState() {
    super.initState();
    _serviceRegistry = ServiceRegistry();
    _hookRegistry = HookRoleRegistry();
    _pluginManager = PluginManager(
      serviceRegistry: _serviceRegistry,
      hookRegistry: _hookRegistry,
    );
    _initialize();
  }

  // ── 初始化：严格按依赖顺序 ──
  //
  // SharedPreferences
  //   → CorePlugin       (CommandBus, QueryBus, UILayoutService, I18n, ...)
  //     → AppFramePlugin  (StoragePathService, ThemeService, ThemeRegistry)
  //       → Repositories  (FileSystemNodeRepository, FileSystemGraphRepository)
  //         → GraphPlugin (NodeService, GraphService, NodeBloc, GraphBloc)
  //           → FolderPlugin, SearchPlugin, EditorPlugin
  //             → AppFrameInitializer (Hook 点 + 布局 Hooks)
  //               → PluginManager auto-registers Hooks via registerHooks()
  //                 → ChangeNotifierProvider

  Future<void> _initialize() async {
    if (_initializing) return;
    _initializing = true;
    setState(() => _state = _AppState.loading);

    try {
      // 1 ── 基础设施 ──
      final prefs = await SharedPreferences.getInstance();
      _serviceRegistry.register<SharedPreferences>(instance: prefs, owner: 'app');
      _serviceRegistry.register<SharedPreferencesAsync>(instance: SharedPreferencesAsync(), owner: 'app');

      // 2 ── core 插件 ──
      await _pluginManager.loadPlugin(CorePlugin(hookRoleRegistry: _hookRegistry));

      // 3 ── appframe 插件（提供 StoragePathService） ──
      await _pluginManager.loadPlugin(AppFramePlugin());

      // 4 ── 仓库（依赖 StoragePathService） ──
      final storagePath = _serviceRegistry.get<StoragePathService>();
      final nodeRepo = FileSystemNodeRepository(nodesDir: await storagePath.getNodesPath());
      await nodeRepo.init();
      _serviceRegistry.register<NodeRepository>(instance: nodeRepo, owner: 'app');

      final graphRepo = FileSystemGraphRepository(graphsDir: await storagePath.getGraphsPath());
      await graphRepo.init();
      _serviceRegistry.register<GraphRepository>(instance: graphRepo, owner: 'app');

      // 5 ── 业务插件（按依赖顺序） ──
      // PluginManager auto-registers services, blocs, and hooks via registerHooks()
      await _pluginManager.loadPlugin(SettingsPlugin());
      await _pluginManager.loadPlugin(GraphPlugin());
      await _pluginManager.loadPlugin(FolderPlugin());
      await _pluginManager.loadPlugin(SearchPlugin());
      await _pluginManager.loadPlugin(EditorPlugin());

      // 6 ── AppFrame 初始化（Hook 点 + 布局 Hooks） ──
      await AppFrameInitializer(hookRegistry: _hookRegistry).initialize();

      setState(() => _state = _AppState.ready);
    } catch (e, st) {
      debugPrint('Init failed: $e\n$st');
      setState(() { _state = _AppState.error; _error = e; });
    }
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) => switch (_state) {
    _AppState.loading => _buildLoading(),
    _AppState.error   => _buildError(),
    _AppState.ready   => _buildApp(),
  };

  Widget _buildApp() {
    return PluginProviderTree(
      serviceRegistry: _serviceRegistry,
      blocProviders: _pluginManager.generateBlocProviders(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) => MaterialApp(
          title: 'Node Graph Notebook',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getMaterialTheme(themeService.themeData, Brightness.light),
          darkTheme: AppTheme.getMaterialTheme(themeService.themeData, Brightness.dark),
          themeMode: themeService.themeMode,
          home: const HomePage(),
        ),
      ),
    );
  }

  Widget _buildLoading() => const MaterialApp(home: Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Loading...')]))));

  Widget _buildError() => MaterialApp(home: Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 64, color: Colors.red),
    const SizedBox(height: 16),
    Text('Initialization Failed', style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 8),
    Text('$_error', style: Theme.of(context).textTheme.bodyMedium),
    const SizedBox(height: 16),
    ElevatedButton(onPressed: _initialize, child: const Text('Retry')),
  ]))));
}
