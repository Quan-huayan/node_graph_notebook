import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'converter/converter_service.dart';
import 'converter/converter_service_impl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/repositories/repositories.dart';
import 'core/services/services.dart';
import 'core/services/theme/app_theme.dart';
import 'ai/ai_service.dart';
import 'bloc/blocs.dart';
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
        Provider<ImportExportService>(
          create: (ctx) => ImportExportServiceImpl(
            ctx.read<ConverterService>(),
            ctx.read<NodeService>(),
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

        // 2.1 Undo Manager
        ChangeNotifierProvider<UndoManager>(
          create: (_) => UndoManager(),
        ),

        // 2.2 BLoC 层
        BlocProvider<GraphBloc>(
          create: (ctx) => GraphBloc(
            graphService: ctx.read<GraphService>(),
            undoManager: ctx.read<UndoManager>(),
          )..add(const GraphInitializeEvent()),
        ),
        BlocProvider<NodeBloc>(
          create: (ctx) => NodeBloc(
            nodeService: ctx.read<NodeService>(),
          )..add(const NodeLoadEvent()),
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
