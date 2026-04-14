import 'package:equatable/equatable.dart';

import '../../../models/models.dart';

/// 应用事件基类
///
/// 所有通过事件总线传递的事件都必须继承此类。
/// 使用 Equatable 实现值相等性比较，便于测试和状态比较。
abstract class AppEvent extends Equatable {
  /// 创建一个应用事件
  const AppEvent();

  @override
  List<Object?> get props => [];
}

/// 节点数据变化事件
///
/// 当节点的数据发生变化时（创建、更新、删除），NodeBloc 会发布此事件。
/// GraphBloc 订阅此事件以更新视图层的节点数据。
class NodeDataChangedEvent extends AppEvent {
  /// 创建一个节点数据变化事件
  ///
  /// [changedNodes] - 发生变化的节点列表
  /// [action] - 变化类型，默认为更新
  const NodeDataChangedEvent({
    required this.changedNodes,
    this.action = DataChangeAction.update,
  });

  /// 发生变化的节点列表
  final List<Node> changedNodes;

  /// 变化类型
  final DataChangeAction action;

  @override
  List<Object?> get props => [changedNodes, action];
}

/// 数据变化类型
///
/// 定义节点数据可能的变化类型，便于订阅者根据类型执行不同的处理逻辑。
enum DataChangeAction {
  /// 创建新节点
  create,

  /// 更新现有节点
  update,

  /// 删除节点
  delete,
}

/// 图节点关系变化事件
///
/// 当节点与图的关系发生变化时（添加到图、从图移除），GraphBloc 会发布此事件。
/// 其他 BLoC 或组件可以订阅此事件以响应图结构变化。
class GraphNodeRelationChangedEvent extends AppEvent {
  /// 创建一个图节点关系变化事件
  ///
  /// [graphId] - 发生变化的图 ID
  /// [nodeIds] - 涉及的节点 ID 列表
  /// [action] - 变化类型
  const GraphNodeRelationChangedEvent({
    required this.graphId,
    required this.nodeIds,
    required this.action,
  });

  /// 发生变化的图 ID
  final String graphId;

  /// 涉及的节点 ID 列表
  final List<String> nodeIds;

  /// 变化类型
  final RelationChangeAction action;

  @override
  List<Object?> get props => [graphId, nodeIds, action];
}

/// 图节点关系变化类型
enum RelationChangeAction {
  /// 节点被添加到图
  addedToGraph,

  /// 节点从图中移除
  removedFromGraph,
}

/// 插件加载事件
///
/// 当插件成功加载时发布
class PluginLoadedEvent extends AppEvent {
  /// 创建一个插件加载事件
  const PluginLoadedEvent({required this.pluginId});

  /// 插件 ID
  final String pluginId;

  @override
  List<Object?> get props => [pluginId];
}

/// 插件启用事件
///
/// 当插件成功启用时发布
class PluginEnabledEvent extends AppEvent {
  /// 创建一个插件启用事件
  const PluginEnabledEvent({required this.pluginId});

  /// 插件 ID
  final String pluginId;

  @override
  List<Object?> get props => [pluginId];
}
