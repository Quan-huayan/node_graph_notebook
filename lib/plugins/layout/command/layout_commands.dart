import 'dart:ui';

import '../../../../core/commands/models/command.dart';
import '../../../../core/commands/models/command_context.dart';
import '../../../../core/repositories/node_repository.dart';

/// 应用布局命令
///
/// 对当前图应用指定的布局算法
class ApplyLayoutCommand extends Command<Map<String, Offset>> {
  /// 构造函数
  ///
  /// [layoutType] - 布局类型
  /// [graphId] - 图 ID，可选，默认使用当前图
  ApplyLayoutCommand({required this.layoutType, this.graphId});

  /// 布局类型
  ///
  /// 支持的值：
  /// - 'force_directed': 力导向布局
  /// - 'tree' / 'hierarchical': 树形/层级布局
  /// - 'circular': 环形布局
  /// - 'grid': 网格布局
  final String layoutType;

  /// 图 ID（可选，默认使用当前图）
  final String? graphId;

  @override
  String get name => 'ApplyLayout';

  @override
  String get description => '应用布局: $layoutType';

  @override
  Future<CommandResult<Map<String, Offset>>> execute(
    CommandContext context,
  ) async {
    // 由 ApplyLayoutHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // TODO: 实现撤销功能（需要保存原始位置）
    throw UnimplementedError('撤销布局功能暂未实现');
  }
}

/// 批量移动节点命令
///
/// 用于布局算法批量更新节点位置
class BatchMoveNodesCommand extends Command<void> {
  /// 构造函数
  ///
  /// [positions] - 节点位置映射，Key: 节点 ID, Value: 新位置
  BatchMoveNodesCommand({required this.positions});

  /// 节点位置映射
  ///
  /// Key: 节点 ID
  /// Value: 新位置
  final Map<String, Offset> positions;

  /// 原始位置（用于撤销）
  ///
  /// 公共字段，允许 Handler 在执行时设置旧值以支持撤销操作
  late Map<String, Offset> oldPositions;

  @override
  String get name => 'BatchMoveNodes';

  @override
  String get description => '批量移动 ${positions.length} 个节点';

  @override
  Future<CommandResult<void>> execute(CommandContext context) async {
    // 由 BatchMoveNodesHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 恢复原始位置
    final repository = context.read<NodeRepository>();

    for (final entry in oldPositions.entries) {
      final node = await repository.load(entry.key);
      if (node != null) {
        await repository.save(node.copyWith(position: entry.value));
      }
    }
  }
}
