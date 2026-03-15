import '../middleware_plugin.dart';
import '../../plugin_metadata.dart';
import '../../plugin_context.dart';
import '../../../commands/command.dart';
import '../../../commands/command_context.dart';

/// 性能监控中间件
class PerformanceMiddleware extends CommandMiddlewarePlugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'performance_middleware',
        name: 'Performance Middleware',
        version: '1.0.0',
        description: 'Monitors command execution performance',
      );

  @override
  int get priority => 70;

  final List<PerformanceMetric> _metrics = [];
  final int _maxMetrics = 1000;

  @override
  Future<void> onInit(MiddlewarePluginContext context) async {
    // 初始化性能监控
  }

  @override
  Future<void> onDispose() async {
    // 清理性能指标
    _metrics.clear();
  }

  @override
  Future<void> onLoad(PluginContext context) async {
    // 加载时的逻辑
  }

  @override
  Future<void> onEnable() async {
    // 启用时的逻辑
  }

  @override
  Future<void> onDisable() async {
    // 禁用时的逻辑
  }

  @override
  Future<void> onUnload() async {
    // 卸载时的逻辑
    await onDispose();
  }

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  /// 插件状态
  PluginState _state = PluginState.unloaded;

  @override
  bool canHandle(Command command) {
    // 处理所有命令
    return true;
  }

  @override
  Future<CommandResult?> handle(
    Command command,
    CommandContext context,
    NextMiddleware next,
  ) async {
    final startTime = DateTime.now();
    
    try {
      // 执行命令
      final result = await next(command, context);
      
      // 记录性能指标
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      _recordMetric(
        command.runtimeType.toString(),
        duration.inMilliseconds,
        true,
      );
      
      return result;
    } catch (e) {
      // 记录错误情况下的性能指标
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      _recordMetric(
        command.runtimeType.toString(),
        duration.inMilliseconds,
        false,
      );
      
      rethrow;
    }
  }

  void _recordMetric(String commandType, int durationMs, bool success) {
    _metrics.add(PerformanceMetric(
      commandType: commandType,
      durationMs: durationMs,
      success: success,
      timestamp: DateTime.now(),
    ));
    
    // 限制指标数量
    if (_metrics.length > _maxMetrics) {
      _metrics.removeAt(0);
    }
  }

  /// 获取性能指标
  List<PerformanceMetric> getMetrics() {
    return List.from(_metrics);
  }

  /// 获取平均执行时间
  double getAverageDuration(String? commandType) {
    if (_metrics.isEmpty) return 0;
    
    final filteredMetrics = commandType != null
        ? _metrics.where((m) => m.commandType == commandType).toList()
        : _metrics;
    
    if (filteredMetrics.isEmpty) return 0;
    
    final totalDuration = filteredMetrics.fold(0, (sum, m) => sum + m.durationMs);
    return totalDuration / filteredMetrics.length;
  }

  /// 获取成功率
  double getSuccessRate(String? commandType) {
    if (_metrics.isEmpty) return 0;
    
    final filteredMetrics = commandType != null
        ? _metrics.where((m) => m.commandType == commandType).toList()
        : _metrics;
    
    if (filteredMetrics.isEmpty) return 0;
    
    final successCount = filteredMetrics.where((m) => m.success).length;
    return successCount / filteredMetrics.length;
  }

  /// 清除性能指标
  void clearMetrics() {
    _metrics.clear();
  }
}

/// 性能指标
class PerformanceMetric {
  PerformanceMetric({
    required this.commandType,
    required this.durationMs,
    required this.success,
    required this.timestamp,
  });

  final String commandType;
  final int durationMs;
  final bool success;
  final DateTime timestamp;
}
