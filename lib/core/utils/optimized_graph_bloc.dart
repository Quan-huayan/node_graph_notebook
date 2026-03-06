import 'package:flutter/material.dart';
import 'package:node_graph_notebook/bloc/blocs.dart';
import 'performance_manager.dart';

/// 优化的 GraphBloc 扩展
/// 提供性能优化功能
class OptimizedGraphBloc {
  OptimizedGraphBloc({
    required this.bloc,
    bool enableBatchPersistence = true,
    bool enableDebouncing = true,
    bool enablePerformanceMonitoring = false,
  }) {
    if (enableBatchPersistence) {
      _batchManager = BatchPersistenceManager(bloc: bloc);
    }

    if (enableDebouncing) {
      _debounceManager = DebounceManager();
    }

    if (enablePerformanceMonitoring) {
      _enableMonitoring();
    }
  }

  final GraphBloc bloc;
  BatchPersistenceManager? _batchManager;
  DebounceManager? _debounceManager;

  /// 移动节点（带防抖）
  void moveNodeDebounced(String nodeId, Offset newPosition) {
    _debounceManager?.debounce(
      'move_$nodeId',
      () => bloc.add(NodeMoveEvent(nodeId, newPosition)),
    );
  }

  /// 批量移动节点
  void moveNodesBatch(Map<String, Offset> movements) {
    bloc.add(NodeMultiMoveEvent(movements));
  }

  /// 添加到批量持久化队列
  void addForBatchPersistence(GraphEvent event) {
    _batchManager?.addEvent(event);
  }

  /// 立即刷新批量队列
  void flushBatch() {
    _batchManager?.flush();
  }

  /// 取消所有防抖
  void cancelAllDebounces() {
    _debounceManager?.cancelAll();
  }

  /// 性能监控
  void _enableMonitoring() {
    bloc.stream.listen((_) {
      // 监听状态变化
      PerformanceMonitor.end('state_update');
      PerformanceMonitor.start('state_update');
    });
  }

  /// 获取性能报告
  static String getPerformanceReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== Performance Report ===');

    final avgStateUpdate = PerformanceMonitor.getAverageDuration('state_update');
    if (avgStateUpdate != null) {
      buffer.writeln('State Update: ${avgStateUpdate.inMilliseconds}ms average');
    }

    PerformanceMonitor.logPerformance();
    return buffer.toString();
  }

  /// 清理资源
  void dispose() {
    _batchManager?.cancel();
    _debounceManager?.cancelAll();
    PerformanceMonitor.clear();
  }
}

/// 状态缓存管理器
/// 缓存常用的计算结果
class StateCache {
  static const _maxCacheSize = 100;
  static final Map<String, _CacheEntry> _cache = {};

  /// 获取缓存的节点位置
  static Offset? getNodePosition(String graphId, String nodeId) {
    final key = 'pos_${graphId}_$nodeId';
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      return entry.value as Offset?;
    }
    _cache.remove(key);
    return null;
  }

  /// 缓存节点位置
  static void cacheNodePosition(String graphId, String nodeId, Offset position) {
    final key = 'pos_${graphId}_$nodeId';
    _cache[key] = _CacheEntry(position, const Duration(seconds: 30));
    _cleanupCache();
  }

  /// 获取缓存的连接列表
  static List<dynamic>? getConnections(String graphId) {
    final key = 'conn_$graphId';
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      return entry.value as List<dynamic>?;
    }
    _cache.remove(key);
    return null;
  }

  /// 缓存连接列表
  static void cacheConnections(String graphId, List<dynamic> connections) {
    final key = 'conn_$graphId';
    _cache[key] = _CacheEntry(connections, const Duration(seconds: 30));
    _cleanupCache();
  }

  /// 清理过期缓存
  static void _cleanupCache() {
    if (_cache.length > _maxCacheSize) {
      _cache.removeWhere((key, entry) => entry.isExpired);
    }
  }

  /// 清除所有缓存
  static void clear() {
    _cache.clear();
  }
}

/// 缓存条目
class _CacheEntry {
  _CacheEntry(this.value, this.ttl) : _createdAt = DateTime.now();

  final dynamic value;
  final Duration ttl;
  final DateTime _createdAt;

  bool get isExpired => DateTime.now().difference(_createdAt) > ttl;
}
