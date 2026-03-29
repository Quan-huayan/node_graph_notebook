import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../utils/logger.dart';
import 'plugin_manager.dart';
import 'service_registry.dart';

/// 动态 Provider Widget 日志记录器
const _log = AppLogger('DynamicProviderWidget');

/// 动态 Provider Widget
///
/// 解决 Provider 树静态性与插件动态加载的矛盾：
/// - 插件可以在运行时加载/卸载
/// - Provider 树在插件变化时自动重建
/// - UI 正确反映插件状态
///
/// 工作原理：
/// 1. 监听 ServiceRegistry 的变化
/// 2. 服务注册/注销时触发 Provider 树重建
/// 3. 合并核心 providers 和动态 providers
/// 4. 保持 Provider 树的完整性
///
/// Provider 顺序（重要）：
/// 1. coreProviders（核心依赖）
/// 2. serviceProviders（插件服务）
/// 3. blocProviders（插件 BLoC，依赖服务）
///
/// 使用示例：
/// ```dart
/// DynamicProviderWidget(
///   serviceRegistry: _serviceRegistry,
///   pluginManager: pluginManager,
///   coreProviders: [
///     Provider<NodeRepository>.value(value: _nodeRepository),
///     Provider<CommandBus>.value(value: _commandBus),
///     // ... 其他核心 providers
///   ],
///   child: MaterialApp(...),
/// )
/// ```
class DynamicProviderWidget extends StatefulWidget {
  /// 创建一个新的动态 Provider Widget 实例
  ///
  /// [serviceRegistry] 服务注册表
  /// [pluginManager] 插件管理器（用于生成 BLoC providers）
  /// [coreProviders] 核心 Provider 列表（不变的）
  /// [child] 子 Widget
  const DynamicProviderWidget({
    super.key,
    required this.serviceRegistry,
    required this.pluginManager,
    required this.coreProviders,
    required this.child,
  });

  /// 服务注册表
  final ServiceRegistry serviceRegistry;

  /// 插件管理器
  final PluginManager pluginManager;

  /// 核心 Provider 列表（不变的）
  ///
  /// 这些 Provider 不会因为插件加载/卸载而改变
  final List<SingleChildWidget> coreProviders;

  /// 子 Widget
  final Widget child;

  @override
  State<DynamicProviderWidget> createState() => _DynamicProviderWidgetState();
}

class _DynamicProviderWidgetState extends State<DynamicProviderWidget> {
  /// 当前所有 Provider 列表（核心 + 动态）
  late List<SingleChildWidget> _currentProviders;

  /// 最后一次服务注册表的状态哈希
  ///
  /// 用于检测服务是否真的发生了变化（避免不必要的重建）
  int _lastRegistryHash = 0;

  @override
  void initState() {
    super.initState();

    _log.info('初始化 DynamicProviderWidget');

    
    // 初始化 Provider 列表
    _currentProviders = _buildProviders();
    _lastRegistryHash = _calculateRegistryHash();
    
    _log.info('[DynamicProviderWidget] ✓ 初始 Provider 列表构建完成');
    _log.info('  核心 Providers:');
    for (var i = 0; i < widget.coreProviders.length; i++) {
      _log.info('    [$i] ${widget.coreProviders[i].runtimeType}');
    }
    
    // 从 _currentProviders 中提取服务 Providers 和 BLoC Providers 用于日志打印
    final coreCount = widget.coreProviders.length;
    final serviceProviders = _currentProviders.skip(coreCount).take(
      widget.serviceRegistry.registeredTypes.length
    ).toList();
    final blocProviders = _currentProviders.skip(coreCount + serviceProviders.length).toList();
    
    _log.info('  服务 Providers:');
    for (var i = 0; i < serviceProviders.length; i++) {
      _log.info('    [$i] ${serviceProviders[i].runtimeType}');
    }
    _log.info('  BLoC Providers:');
    for (var i = 0; i < blocProviders.length; i++) {
      _log.info('    [$i] ${blocProviders[i].runtimeType}');
    }



    // 监听服务注册表的变化
    widget.serviceRegistry.addListener(_onServicesChanged);
    _log.info('[DynamicProviderWidget] ✓ 已监听 ServiceRegistry 变化');

  }

  @override
  void didUpdateWidget(DynamicProviderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果 serviceRegistry 实例变了，重新监听
    if (widget.serviceRegistry != oldWidget.serviceRegistry) {

      _log.info('ServiceRegistry 实例已变化');
      _log.info('移除旧监听器，添加新监听器');
      
      oldWidget.serviceRegistry.removeListener(_onServicesChanged);
      widget.serviceRegistry.addListener(_onServicesChanged);
      
      // 重新构建 Provider 列表
      _updateProviders();
      
      _log.info('[DynamicProviderWidget] ✓ 监听器更新完成');

    }
  }

  @override
  void dispose() {

    _log.info('销毁 DynamicProviderWidget');
    
    // 移除监听器
    widget.serviceRegistry.removeListener(_onServicesChanged);
    _log.info('[DynamicProviderWidget] ✓ 已移除 ServiceRegistry 监听器');
    
    _log.info('[DynamicProviderWidget] ✓ 销毁完成');

    
    super.dispose();
  }

  /// 服务变化回调
  ///
  /// 当插件加载/卸载时，ServiceRegistry 会调用 notifyListeners()
  /// 这里监听到变化后，触发 Provider 树重建
  void _onServicesChanged() {

    _log.info('检测到 ServiceRegistry 变化');
    
    // 计算新的哈希值
    final newHash = _calculateRegistryHash();



    // 只有哈希值变化时才重建（避免不必要的重建）
    if (newHash != _lastRegistryHash) {
      _log.info('[DynamicProviderWidget] ✓ 哈希值已变化，触发 Provider 树重建');
      _updateProviders();
      _lastRegistryHash = newHash;
    } else {
      _log.info('ℹ 哈希值未变化，跳过重建');
    }
    

  }

  /// 更新 Provider 列表并触发重建
  void _updateProviders() {

    _log.info('开始更新 Provider 列表');

    
    setState(() {
      _currentProviders = _buildProviders();
    });


    _log.info('  核心 Providers:');
    for (var i = 0; i < widget.coreProviders.length; i++) {
      _log.info('    [$i] ${widget.coreProviders[i].runtimeType}');
    }
    
    // 从 _currentProviders 中提取服务 Providers 和 BLoC Providers 用于日志打印
    final coreCount = widget.coreProviders.length;
    final serviceProviders = _currentProviders.skip(coreCount).take(
      widget.serviceRegistry.registeredTypes.length
    ).toList();
    final blocProviders = _currentProviders.skip(coreCount + serviceProviders.length).toList();
    
    _log.info('  服务 Providers:');
    for (var i = 0; i < serviceProviders.length; i++) {
      _log.info('    [$i] ${serviceProviders[i].runtimeType}');
    }
    _log.info('  BLoC Providers:');
    for (var i = 0; i < blocProviders.length; i++) {
      _log.info('    [$i] ${blocProviders[i].runtimeType}');
    }

    _log.info('Provider tree rebuilt (${_currentProviders.length} providers)');
    
    _log.info('[DynamicProviderWidget] ✓ Provider 列表更新完成');

  }

  /// 构建完整的 Provider 列表（核心 + 服务 + BLoC）
  ///
  /// 顺序很重要：
  /// 1. coreProviders - 核心依赖（Repository, CommandBus 等）
  /// 2. serviceProviders - 插件服务（NodeService, SearchPresetService 等）
  /// 3. blocProviders - 插件 BLoC（SearchBloc, NodeBloc 等，依赖服务）
  List<SingleChildWidget> _buildProviders() => [
      ...widget.coreProviders,
      // 从 ServiceRegistry 生成插件提供的 Service Provider
      ...widget.serviceRegistry.generateProviders(),
      // 从 PluginManager 生成插件提供的 BLoC Provider
      // 注意：BLoC 在 Service 之后，因为 BLoC 依赖 Service
      ...widget.pluginManager.generateBlocProviders(),
    ];

  /// 计算服务注册表的状态哈希
  ///
  /// 用于检测服务是否真的发生了变化
  int _calculateRegistryHash() {
    final registeredTypes = widget.serviceRegistry.registeredTypes;
    return Object.hashAll(registeredTypes);
  }

  @override
  Widget build(BuildContext context) 
  // 使用 MultiProvider 包装所有 Provider
  => MultiProvider(
      providers: _currentProviders,
      child: widget.child,
    );
    
}

/// InheritedWidget 版本的动态 Provider
///
/// 如果 MultiProvider 的重建成本太高，可以使用这个版本
/// 它只重建动态部分，核心 Provider 保持不变
///
/// 使用示例：
/// ```dart
/// HybridDynamicProviderWidget(
///   serviceRegistry: _serviceRegistry,
///   pluginManager: pluginManager,
///   coreProviders: [...],
///   child: MaterialApp(...),
/// )
/// ```
class HybridDynamicProviderWidget extends StatefulWidget {
  /// 创建一个新的混合动态 Provider Widget 实例
  ///
  /// [serviceRegistry] 服务注册表
  /// [pluginManager] 插件管理器（用于生成 BLoC providers）
  /// [coreProviders] 核心 Provider 列表（不变的）
  /// [child] 子 Widget
  const HybridDynamicProviderWidget({
    super.key,
    required this.serviceRegistry,
    required this.pluginManager,
    required this.coreProviders,
    required this.child,
  });

  /// 服务注册表
  final ServiceRegistry serviceRegistry;

  /// 插件管理器
  final PluginManager pluginManager;

  /// 核心 Provider 列表（不变的）
  final List<SingleChildWidget> coreProviders;

  /// 子 Widget
  final Widget child;

  @override
  State<HybridDynamicProviderWidget> createState() =>
      _HybridDynamicProviderWidgetState();
}

class _HybridDynamicProviderWidgetState
    extends State<HybridDynamicProviderWidget> {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => MultiProvider(
          providers: widget.coreProviders,
          child: _DynamicProvidersLayer(
            serviceRegistry: widget.serviceRegistry,
            pluginManager: widget.pluginManager,
            child: widget.child,
          ),
        ),
    );
}

/// 动态 Provider 层（只重建这部分）
///
/// Provider 顺序：
/// 1. serviceProviders - 插件服务
/// 2. blocProviders - 插件 BLoC（依赖服务）
class _DynamicProvidersLayer extends StatefulWidget {
  const _DynamicProvidersLayer({
    required this.serviceRegistry,
    required this.pluginManager,
    required this.child,
  });

  final ServiceRegistry serviceRegistry;
  final PluginManager pluginManager;
  final Widget child;

  @override
  State<_DynamicProvidersLayer> createState() => _DynamicProvidersLayerState();
}

class _DynamicProvidersLayerState extends State<_DynamicProvidersLayer> {
  bool _needsRebuild = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_needsRebuild) {
      _needsRebuild = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _onServicesChanged() {
    _needsRebuild = true;
    // 立即触发更新，确保首次构建时也能响应
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _needsRebuild) {
        setState(() {
          _needsRebuild = false;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    widget.serviceRegistry.addListener(_onServicesChanged);
  }

  @override
  void dispose() {
    widget.serviceRegistry.removeListener(_onServicesChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    _log.info('构建动态 Provider 层');
    final serviceProviders = widget.serviceRegistry.generateProviders();
    _log.info('服务 Providers: ${serviceProviders.length}');
    final blocProviders = widget.pluginManager.generateBlocProviders();
    _log.info('BLoC Providers: ${blocProviders.length}');
    _log.info('总 Providers: ${serviceProviders.length + blocProviders.length}');


    return LayoutBuilder(
      builder: (context, constraints) => MultiProvider(
          providers: [
            ...serviceProviders,
            ...blocProviders,
          ],
          child: widget.child,
        ),
    );
  }
}
