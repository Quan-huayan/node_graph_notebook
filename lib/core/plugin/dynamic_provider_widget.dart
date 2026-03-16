import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'service_registry.dart';

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
/// 使用示例：
/// ```dart
/// DynamicProviderWidget(
///   serviceRegistry: _serviceRegistry,
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
  /// [coreProviders] 核心 Provider 列表（不变的）
  /// [child] 子 Widget
  const DynamicProviderWidget({
    super.key,
    required this.serviceRegistry,
    required this.coreProviders,
    required this.child,
  });

  /// 服务注册表
  final ServiceRegistry serviceRegistry;

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
    // 初始化 Provider 列表
    _currentProviders = _buildProviders();
    _lastRegistryHash = _calculateRegistryHash();

    // 监听服务注册表的变化
    widget.serviceRegistry.addListener(_onServicesChanged);
  }

  @override
  void didUpdateWidget(DynamicProviderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果 serviceRegistry 实例变了，重新监听
    if (widget.serviceRegistry != oldWidget.serviceRegistry) {
      oldWidget.serviceRegistry.removeListener(_onServicesChanged);
      widget.serviceRegistry.addListener(_onServicesChanged);
      // 重新构建 Provider 列表
      _updateProviders();
    }
  }

  @override
  void dispose() {
    // 移除监听器
    widget.serviceRegistry.removeListener(_onServicesChanged);
    super.dispose();
  }

  /// 服务变化回调
  ///
  /// 当插件加载/卸载时，ServiceRegistry 会调用 notifyListeners()
  /// 这里监听到变化后，触发 Provider 树重建
  void _onServicesChanged() {
    // 计算新的哈希值
    final newHash = _calculateRegistryHash();

    // 只有哈希值变化时才重建（避免不必要的重建）
    if (newHash != _lastRegistryHash) {
      _updateProviders();
      _lastRegistryHash = newHash;
    }
  }

  /// 更新 Provider 列表并触发重建
  void _updateProviders() {
    setState(() {
      _currentProviders = _buildProviders();
    });

    debugPrint(
      '[DynamicProviderWidget] Provider tree rebuilt (${_currentProviders.length} providers)',
    );
  }

  /// 构建完整的 Provider 列表（核心 + 动态）
  List<SingleChildWidget> _buildProviders() => [
      ...widget.coreProviders,
      // 从 ServiceRegistry 生成插件提供的 Provider
      ...widget.serviceRegistry.generateProviders(),
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
///   coreProviders: [...],
///   child: MaterialApp(...),
/// )
/// ```
class HybridDynamicProviderWidget extends StatefulWidget {
  /// 创建一个新的混合动态 Provider Widget 实例
  ///
  /// [serviceRegistry] 服务注册表
  /// [coreProviders] 核心 Provider 列表（不变的）
  /// [child] 子 Widget
  const HybridDynamicProviderWidget({
    super.key,
    required this.serviceRegistry,
    required this.coreProviders,
    required this.child,
  });

  /// 服务注册表
  final ServiceRegistry serviceRegistry;

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
  void initState() {
    super.initState();
    widget.serviceRegistry.addListener(_onServicesChanged);
  }

  @override
  void didUpdateWidget(HybridDynamicProviderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.serviceRegistry != oldWidget.serviceRegistry) {
      oldWidget.serviceRegistry.removeListener(_onServicesChanged);
      widget.serviceRegistry.addListener(_onServicesChanged);
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.serviceRegistry.removeListener(_onServicesChanged);
    super.dispose();
  }

  void _onServicesChanged() {
    setState(() {
      // 触发重建（只重建动态部分）
    });
  }

  @override
  Widget build(BuildContext context) 
  // 先构建核心 Provider（不重建）
  => MultiProvider(
      providers: widget.coreProviders,
      child: _DynamicProvidersLayer(
        serviceRegistry: widget.serviceRegistry,
        child: widget.child,
      ),
    );
}

/// 动态 Provider 层（只重建这部分）
class _DynamicProvidersLayer extends StatelessWidget {
  const _DynamicProvidersLayer({
    required this.serviceRegistry,
    required this.child,
  });

  final ServiceRegistry serviceRegistry;
  final Widget child;

  @override
  Widget build(BuildContext context) 
  // 只构建动态 Provider（这部分会重建）
  => MultiProvider(
      providers: serviceRegistry.generateProviders(),
      child: child,
    );
}
