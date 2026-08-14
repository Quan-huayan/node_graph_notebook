import 'package:core/cqrs/commands/events/app_events.dart';
import 'package:core_data/core_data.dart';

/// 节点数据同步助手
///
/// 提供节点数据同步相关的纯业务逻辑函数
/// 
/// 架构说明：
/// - 此类包含纯业务逻辑，不包含状态管理
/// - 用于从 BLoC 中提取业务逻辑
class NodeDataSyncHelper {
  /// 根据数据变化事件计算更新后的节点和连接列表
  ///
  /// [currentNodes] - 当前节点列表
  /// [graphNodeIds] - 当前图中的节点 ID 集合
  /// [event] - 数据变化事件
  ///
  /// 返回包含更新后节点和连接的 Map
  static Map<String, List<dynamic>> calculateUpdatedData({
    required List<Node> currentNodes,
    required Set<String> graphNodeIds,
    required NodeDataChangedEvent event,
  }) {
    List<Node> updatedNodes;
    List<Connection> updatedConnections;

    switch (event.action) {
      case DataChangeAction.delete:
        // 从图中移除已删除的节点
        final deletedNodeIds = event.changedNodes.map((n) => n.id).toSet();
        updatedNodes = currentNodes.where((n) => !deletedNodeIds.contains(n.id)).toList();
        updatedConnections = Connection.calculateConnections(updatedNodes);
        break;

      case DataChangeAction.update:
      case DataChangeAction.create:
        // 更新当前图中的节点数据
        final affectedNodes = event.changedNodes
            .where((n) => graphNodeIds.contains(n.id))
            .toList();

        if (affectedNodes.isEmpty) {
          // 如果没有受影响的节点，返回原数据
          return {
            'nodes': currentNodes,
            'connections': Connection.calculateConnections(currentNodes),
          };
        }

        // 替换逻辑：移除旧版本，添加新版本
        final affectedNodeIds = affectedNodes.map((n) => n.id).toSet();
        updatedNodes = [
          ...currentNodes.where((n) => !affectedNodeIds.contains(n.id)),
          ...affectedNodes,
        ];
        updatedConnections = Connection.calculateConnections(updatedNodes);
        break;
    }

    return {
      'nodes': updatedNodes,
      'connections': updatedConnections,
    };
  }
}
