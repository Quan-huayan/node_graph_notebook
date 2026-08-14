/// 布局命令（M7.3）：ApplyLayoutCommand —— 长任务 Handler 承载
/// 布局计算，结果**走 UIStateStore 位置键直写**（判据②，ChangeKind.ui
/// 不发失效事件；画布靠 uiStateStore 观察者通道刷新，02 §2.3）。
library;

import 'dart:ui';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

import '../connection_concept.dart';
import 'layout_algorithms.dart';
import 'layout_engine.dart';

/// 应用布局命令。
class ApplyLayoutCommand extends Command<ApplyLayoutCommand> {
  /// 携带算法与目标（null = 全部画布成员）。
  const ApplyLayoutCommand({required this.algorithm, this.targets});

  /// 布局算法。
  final LayoutAlgorithm algorithm;

  /// 目标节点（null = 全部有位置键的成员）。
  final Set<String>? targets;

  @override
  String get name => 'graph.layout';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{
    'algorithm': algorithm.name,
    'targets': targets?.toList(),
  };
}

/// 布局写结果（ui：不发失效事件，画布观察者通道刷新）。
class ApplyLayoutResult implements WriteResult {
  /// 无结构变更。
  const ApplyLayoutResult();

  @override
  final Set<String> affectedNodeIds = const <String>{};

  @override
  ChangeKind get changeKind => ChangeKind.ui;

  @override
  Command? get inverse => null;
}

/// 布局 Handler：计算 → 逐键直写（判据② 外观存储）。
class ApplyLayoutHandler
    extends CommandHandler<ApplyLayoutCommand, ApplyLayoutResult> {
  /// 注入结构存储与外观存储（延迟解析——插件注册期无 provider）。
  ApplyLayoutHandler({
    required Graph Function() graphProvider,
    required UIStateStore Function() uiStateProvider,
  }) : _graphProvider = graphProvider,
       _uiStateProvider = uiStateProvider;

  final Graph Function() _graphProvider;
  final UIStateStore Function() _uiStateProvider;

  @override
  Type get commandType => ApplyLayoutCommand;

  @override
  Future<ApplyLayoutResult> handle(ApplyLayoutCommand command) async {
    final graph = _graphProvider();
    final uiState = _uiStateProvider();
    // 1. 目标成员 = 位置键 ∩ 节点存在（或显式 targets）。
    final memberIds = <String>[];
    uiState.getByPrefix(canvasPositionPrefix).forEach((key, _) {
      final id = key.substring(canvasPositionPrefix.length);
      if (graph.get(id) != null) {
        memberIds.add(id);
      }
    });
    if (command.targets != null) {
      memberIds.retainWhere(command.targets!.contains);
    }
    if (memberIds.isEmpty) {
      return const ApplyLayoutResult();
    }
    final nodes = <Node>[];
    for (final id in memberIds) {
      nodes.add(graph.get(id)!);
    }
    // 2. 当前位置 + 邻接表（connect 实例 from/to + contain 实例 parent/child）。
    final currentPositions = <String, Offset>{};
    for (final id in memberIds) {
      final position = parseCanvasPosition(uiState.get(canvasPositionKey(id)));
      if (position != null) {
        currentPositions[id] = position;
      }
    }
    final adjacency = _buildAdjacency(graph, memberIds.toSet());
    // 3. 计算 + 直写（判据②：布局 = 外观，无结构写入）。
    final layout = LayoutAlgorithms.compute(
      command.algorithm,
      nodes,
      currentPositions,
      adjacency,
    );
    layout.forEach((id, position) {
      uiState.set(canvasPositionKey(id), <String, dynamic>{
        'x': position.dx,
        'y': position.dy,
      });
    });
    return const ApplyLayoutResult();
  }

  /// 邻接表：connect 实例（无向，from/to 互加）+ contain 实例
  /// （references {parent, child}，方向 parent→child）。
  static AdjacencyMap _buildAdjacency(Graph graph, Set<String> memberIds) {
    final adjacency = <String, List<String>>{};
    void addEdge(String a, String b) {
      if (!memberIds.contains(a) || !memberIds.contains(b)) {
        return;
      }
      adjacency.putIfAbsent(a, () => <String>[]).add(b);
      adjacency.putIfAbsent(b, () => <String>[]).add(a);
    }

    for (final node in graph.getAll()) {
      if (const ConnectionConcept().validate(node)) {
        final from = node.references['from'];
        final to = node.references['to'];
        if (from != null && to != null) {
          addEdge(from, to);
        }
      } else {
        final parent = node.references['parent'];
        final child = node.references['child'];
        if (parent != null && child != null) {
          addEdge(parent, child);
        }
      }
    }
    return adjacency;
  }
}
