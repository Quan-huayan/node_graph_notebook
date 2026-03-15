import 'dart:ui';
import 'package:equatable/equatable.dart';
import '../../../../core/models/models.dart';
import '../../../../core/events/app_events.dart';

/// 节点事件基类
///
/// 不再继承 GraphEvent，实现事件体系的解耦。
/// NodeEvent 专注于节点数据的 CRUD 操作。
/// 节点视图层的选择、移动等交互事件由 GraphBloc 处理。
abstract class NodeEvent extends Equatable {
  const NodeEvent();

  @override
  List<Object?> get props => [];
}

// 加载事件

/// 加载节点列表事件
class NodeLoadEvent extends NodeEvent {
  const NodeLoadEvent();
}

/// 搜索节点事件
class NodeSearchEvent extends NodeEvent {
  const NodeSearchEvent(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

// 节点操作事件

/// 创建节点事件
class NodeCreateEvent extends NodeEvent {
  const NodeCreateEvent({
    required this.title,
    this.content,
    this.metadata,
    this.position,
    this.color,
  });

  final String title;
  final String? content;
  final Map<String, dynamic>? metadata;
  final Offset? position;
  final String? color;

  @override
  List<Object?> get props => [title, content, metadata, position, color];
}

/// 创建内容节点事件
class NodeCreateContentEvent extends NodeEvent {
  const NodeCreateContentEvent({
    required this.title,
    required this.content,
    this.metadata,
  });

  final String title;
  final String content;
  final Map<String, dynamic>? metadata;

  @override
  List<Object?> get props => [title, content, metadata];
}

/// 更新节点事件
class NodeUpdateEvent extends NodeEvent {
  const NodeUpdateEvent(
    this.nodeId,
    {
      this.title,
      this.content,
      this.position,
      this.viewMode,
      this.color,
      this.metadata,
    }
  );

  final String nodeId;
  final String? title;
  final String? content;
  final Offset? position;
  final NodeViewMode? viewMode;
  final String? color;
  final Map<String, dynamic>? metadata;

  @override
  List<Object?> get props => [nodeId, title, content, position, viewMode, color, metadata];
}

/// 替换节点事件
class NodeReplaceEvent extends NodeEvent {
  const NodeReplaceEvent(this.node);

  final Node node;

  @override
  List<Object?> get props => [node];
}

/// 删除节点事件
class NodeDeleteEvent extends NodeEvent {
  const NodeDeleteEvent(this.nodeId);

  final String nodeId;

  @override
  List<Object?> get props => [nodeId];
}

// 节点连接事件

/// 连接节点事件
class NodeConnectEvent extends NodeEvent {
  const NodeConnectEvent({
    required this.fromNodeId,
    required this.toNodeId,
    this.properties,
  });

  final String fromNodeId;
  final String toNodeId;
  final Map<String, dynamic>? properties;

  @override
  List<Object?> get props => [fromNodeId, toNodeId, properties];
}

/// 断开节点连接事件
class NodeDisconnectEvent extends NodeEvent {
  const NodeDisconnectEvent({
    required this.fromNodeId,
    required this.toNodeId,
  });

  final String fromNodeId;
  final String toNodeId;

  @override
  List<Object?> get props => [fromNodeId, toNodeId];
}

/// 切换节点选择状态事件
class NodeToggleSelectionEvent extends NodeEvent {
  const NodeToggleSelectionEvent(this.nodeId);

  final String nodeId;

  @override
  List<Object?> get props => [nodeId];
}


// 错误处理事件

/// 清除错误事件
class NodeClearErrorEvent extends NodeEvent {
  const NodeClearErrorEvent();
}

/// 节点数据变化内部事件
///
/// 用于处理从EventBus接收到的节点数据变化事件
/// 仅在BLoC内部使用，用于同步状态
class NodeDataChangedInternalEvent extends NodeEvent {
  const NodeDataChangedInternalEvent({
    required this.changedNodes,
    required this.action,
  });

  final List<Node> changedNodes;
  final DataChangeAction action;

  @override
  List<Object?> get props => [changedNodes, action];
}