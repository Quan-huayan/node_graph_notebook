import 'dart:ui';

import 'package:equatable/equatable.dart';

import '../../../../core/models/models.dart';
import '../../../core/cqrs/commands/events/app_events.dart';

/// 节点事件基类
///
/// 不再继承 GraphEvent，实现事件体系的解耦。
/// NodeEvent 专注于节点数据的 CRUD 操作。
/// 节点视图层的选择、移动等交互事件由 GraphBloc 处理。
abstract class NodeEvent extends Equatable {
  /// 创建节点事件
  const NodeEvent();

  @override
  List<Object?> get props => [];
}

// 加载事件

/// 加载节点列表事件
class NodeLoadEvent extends NodeEvent {
  /// 创建加载节点列表事件
  const NodeLoadEvent();
}

/// 搜索节点事件
class NodeSearchEvent extends NodeEvent {
  /// 创建搜索节点事件
  const NodeSearchEvent(this.query);

  /// 搜索查询
  final String query;

  @override
  List<Object?> get props => [query];
}

// 节点操作事件

/// 创建节点事件
class NodeCreateEvent extends NodeEvent {
  /// 创建节点事件
  const NodeCreateEvent({
    required this.title,
    this.content,
    this.metadata,
    this.position,
    this.color,
  });

  /// 节点标题
  final String title;
  /// 节点内容
  final String? content;
  /// 节点元数据
  final Map<String, dynamic>? metadata;
  /// 节点位置
  final Offset? position;
  /// 节点颜色
  final String? color;

  @override
  List<Object?> get props => [title, content, metadata, position, color];
}

/// 创建内容节点事件
class NodeCreateContentEvent extends NodeEvent {
  /// 创建内容节点事件
  const NodeCreateContentEvent({
    required this.title,
    required this.content,
    this.metadata,
  });

  /// 节点标题
  final String title;
  /// 节点内容
  final String content;
  /// 节点元数据
  final Map<String, dynamic>? metadata;

  @override
  List<Object?> get props => [title, content, metadata];
}

/// 更新节点事件
class NodeUpdateEvent extends NodeEvent {
  /// 更新节点事件
  const NodeUpdateEvent(
    this.nodeId, {
    this.title,
    this.content,
    this.position,
    this.viewMode,
    this.color,
    this.metadata,
  });

  /// 节点ID
  final String nodeId;
  /// 节点标题
  final String? title;
  /// 节点内容
  final String? content;
  /// 节点位置
  final Offset? position;
  /// 节点视图模式
  final NodeViewMode? viewMode;
  /// 节点颜色
  final String? color;
  /// 节点元数据
  final Map<String, dynamic>? metadata;

  @override
  List<Object?> get props => [
    nodeId,
    title,
    content,
    position,
    viewMode,
    color,
    metadata,
  ];
}

/// 替换节点事件
class NodeReplaceEvent extends NodeEvent {
  /// 替换节点事件
  const NodeReplaceEvent(this.node);

  /// 要替换的节点
  final Node node;

  @override
  List<Object?> get props => [node];
}

/// 删除节点事件
class NodeDeleteEvent extends NodeEvent {
  /// 删除节点事件
  const NodeDeleteEvent(this.nodeId);

  /// 要删除的节点ID
  final String nodeId;

  @override
  List<Object?> get props => [nodeId];
}

// 节点连接事件

/// 连接节点事件
class NodeConnectEvent extends NodeEvent {
  /// 连接节点事件
  const NodeConnectEvent({
    required this.fromNodeId,
    required this.toNodeId,
    this.properties,
  });

  /// 源节点ID
  final String fromNodeId;
  /// 目标节点ID
  final String toNodeId;
  /// 连接属性
  final Map<String, dynamic>? properties;

  @override
  List<Object?> get props => [fromNodeId, toNodeId, properties];
}

/// 断开节点连接事件
class NodeDisconnectEvent extends NodeEvent {
  /// 断开节点连接事件
  const NodeDisconnectEvent({required this.fromNodeId, required this.toNodeId});

  /// 源节点ID
  final String fromNodeId;
  /// 目标节点ID
  final String toNodeId;

  @override
  List<Object?> get props => [fromNodeId, toNodeId];
}

/// 切换节点选择状态事件
class NodeToggleSelectionEvent extends NodeEvent {
  /// 切换节点选择状态事件
  const NodeToggleSelectionEvent(this.nodeId);

  /// 要切换选择状态的节点ID
  final String nodeId;

  @override
  List<Object?> get props => [nodeId];
}

// 错误处理事件

/// 清除错误事件
class NodeClearErrorEvent extends NodeEvent {
  /// 清除错误事件
  const NodeClearErrorEvent();
}

/// 节点数据变化内部事件
///
/// 用于处理从EventBus接收到的节点数据变化事件
/// 仅在BLoC内部使用，用于同步状态
class NodeDataChangedInternalEvent extends NodeEvent {
  /// 节点数据变化内部事件
  const NodeDataChangedInternalEvent({
    required this.changedNodes,
    required this.action,
  });

  /// 变化的节点列表
  final List<Node> changedNodes;
  /// 数据变化操作
  final DataChangeAction action;

  @override
  List<Object?> get props => [changedNodes, action];
}
