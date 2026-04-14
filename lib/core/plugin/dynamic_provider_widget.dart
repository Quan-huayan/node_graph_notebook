import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../utils/logger.dart';
import 'plugin_manager.dart';
import 'service_registry.dart';

/// 动态 Provider Widget 日志记录器
const _log = AppLogger('DynamicProviderWidget');

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
class DynamicProviderWidget extends StatefulWidget {
  /// 创建一个新的混合动态 Provider Widget 实例
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
  final List<SingleChildWidget> coreProviders;

  /// 子 Widget
  final Widget child;

  @override
  State<DynamicProviderWidget> createState() =>
      _DynamicProviderWidgetState();
}

class _DynamicProviderWidgetState
    extends State<DynamicProviderWidget> {
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
