import 'dart:async';
import 'package:flutter/material.dart';
import '../../ui/blocs/graph_bloc.dart';
import '../../ui/blocs/graph_event.dart';
import '../models/models.dart';

/// 批量持久化管理器
/// 将频繁的文件 I/O 操作批量处理，减少磁盘写入
class BatchPersistenceManager {
  BatchPersistenceManager({
    required this.bloc,
    this.maxBatchSize = 10,
    this.maxDelay = const Duration(milliseconds: 500),
  }) {
    _timer = Timer.periodic(maxDelay, _onTimer);
  }

  final GraphBloc bloc;
  final int maxBatchSize;
  final Duration maxDelay;

  final List<GraphEvent> _pendingEvents = [];
  Timer? _timer;

  /// 添加待持久化的事件
  void addEvent(GraphEvent event) {
    _pendingEvents.add(event);

    // 如果达到批量大小，立即刷新
    if (_pendingEvents.length >= maxBatchSize) {
      flush();
    }
  }

  /// 刷新待处理事件
  void flush() {
    if (_pendingEvents.isEmpty) return;

    final events = List<GraphEvent>.from(_pendingEvents);
    _pendingEvents.clear();

    // 分发批量事件
    bloc.add(BatchEvent(events));

    debugPrint('BatchPersistence: Flushed ${events.length} events');
  }

  /// 定时器回调
  void _onTimer(Timer timer) {
    if (_pendingEvents.isNotEmpty) {
      flush();
    }
  }

  /// 取消所有待处理事件
  void cancel() {
    _pendingEvents.clear();
    _timer?.cancel();
  }
}

/// 防抖管理器
/// 防止频繁触发相同操作
class DebounceManager {
  DebounceManager({this.defaultDelay = const Duration(milliseconds: 300)});

  final Duration defaultDelay;
  final Map<String, Timer> _timers = {};

  /// 防抖执行
  void debounce(
    String key,
    VoidCallback callback, {
    Duration? delay,
  }) {
    _timers[key]?.cancel();

    _timers[key] = Timer(
      delay ?? defaultDelay,
      () {
        callback();
        _timers.remove(key);
      },
    );
  }

  /// 取消特定防抖
  void cancel(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
  }

  /// 取消所有防抖
  void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

/// 增量更新管理器
/// 计算状态差异，只更新变化的部分
class IncrementalUpdateManager {
  /// 计算节点差异
  static NodeDiff calculateNodeDiff(List<Node> oldNodes, List<Node> newNodes) {
    final oldIds = oldNodes.map((n) => n.id).toSet();
    final newIds = newNodes.map((n) => n.id).toSet();

    final added = newNodes.where((n) => !oldIds.contains(n.id)).toList();
    final removed = oldNodes.where((n) => !newIds.contains(n.id)).toList();
    final updated = <Node>[];

    // 检查更新的节点
    for (final newNode in newNodes) {
      if (oldIds.contains(newNode.id)) {
        final oldNode = oldNodes.firstWhere((n) => n.id == newNode.id);
        if (_hasNodeChanged(oldNode, newNode)) {
          updated.add(newNode);
        }
      }
    }

    return NodeDiff(
      added: added,
      removed: removed,
      updated: updated,
    );
  }

  /// 计算位置差异
  static PositionDiff calculatePositionDiff(
    Map<String, Offset> oldPositions,
    Map<String, Offset> newPositions,
  ) {
    final changed = <String, Offset>{};
    final removed = <String>[];

    // 检查变化和删除
    for (final entry in oldPositions.entries) {
      final newPosition = newPositions[entry.key];
      if (newPosition == null) {
        removed.add(entry.key);
      } else if (newPosition != entry.value) {
        changed[entry.key] = newPosition;
      }
    }

    // 检查新增
    final added = <String, Offset>{};
    for (final entry in newPositions.entries) {
      if (!oldPositions.containsKey(entry.key)) {
        added[entry.key] = entry.value;
      }
    }

    return PositionDiff(
      changed: changed,
      added: added,
      removed: removed,
    );
  }

  /// 检查节点是否变化
  static bool _hasNodeChanged(Node oldNode, Node newNode) {
    return oldNode.title != newNode.title ||
        oldNode.content != newNode.content ||
        oldNode.position != newNode.position ||
        oldNode.viewMode != newNode.viewMode;
  }
}

/// 节点差异
class NodeDiff {
  const NodeDiff({
    required this.added,
    required this.removed,
    required this.updated,
  });

  final List<Node> added;
  final List<Node> removed;
  final List<Node> updated;

  bool get hasChanges => added.isNotEmpty || removed.isNotEmpty || updated.isNotEmpty;
}

/// 位置差异
class PositionDiff {
  const PositionDiff({
    required this.changed,
    required this.added,
    required this.removed,
  });

  final Map<String, Offset> changed;
  final Map<String, Offset> added;
  final List<String> removed;

  bool get hasChanges => changed.isNotEmpty || added.isNotEmpty || removed.isNotEmpty;
}

/// 性能监控器
class PerformanceMonitor {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, List<Duration>> _durations = {};

  /// 开始计时
  static void start(String operation) {
    _startTimes[operation] = DateTime.now();
  }

  /// 结束计时
  static Duration? end(String operation) {
    final startTime = _startTimes[operation];
    if (startTime == null) return null;

    final duration = DateTime.now().difference(startTime);
    _startTimes.remove(operation);

    _durations.putIfAbsent(operation, () => []).add(duration);

    return duration;
  }

  /// 获取平均持续时间
  static Duration? getAverageDuration(String operation) {
    final durations = _durations[operation];
    if (durations == null || durations.isEmpty) return null;

    final totalMs = durations.fold<int>(
      0,
      (sum, d) => sum + d.inMilliseconds,
    );

    return Duration(milliseconds: totalMs ~/ durations.length);
  }

  /// 记录性能指标
  static void logPerformance() {
    for (final entry in _durations.entries) {
      final avg = getAverageDuration(entry.key);
      if (avg != null) {
        debugPrint('Performance: ${entry.key} average ${avg.inMilliseconds}ms (${entry.value.length} samples)');
      }
    }
  }

  /// 清除所有记录
  static void clear() {
    _startTimes.clear();
    _durations.clear();
  }
}
