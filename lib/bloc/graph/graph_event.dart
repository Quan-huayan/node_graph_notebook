import 'dart:ui';
import 'package:equatable/equatable.dart';
import '../../core/models/models.dart';

/// 图事件基类
abstract class GraphEvent extends Equatable {
  const GraphEvent();

  @override
  List<Object?> get props => [];
}

// 初始化事件

/// 图初始化事件
class GraphInitializeEvent extends GraphEvent {
  const GraphInitializeEvent();
}

/// 图加载事件
class GraphLoadEvent extends GraphEvent {
  const GraphLoadEvent(this.graphId);

  final String graphId;

  @override
  List<Object?> get props => [graphId];
}

// 图操作事件

/// 创建图事件
class GraphCreateEvent extends GraphEvent {
  const GraphCreateEvent(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

/// 切换图事件
class GraphSwitchEvent extends GraphEvent {
  const GraphSwitchEvent(this.graphId);

  final String graphId;

  @override
  List<Object?> get props => [graphId];
}

/// 重命名图事件
class GraphRenameEvent extends GraphEvent {
  const GraphRenameEvent(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

/// 更新图配置事件
class GraphUpdateConfigEvent extends GraphEvent {
  const GraphUpdateConfigEvent(this.config);

  final GraphViewConfig config;

  @override
  List<Object?> get props => [config];
}

// 节点视图操作事件

/// 添加节点事件
class NodeAddEvent extends GraphEvent {
  const NodeAddEvent(this.nodeId, {this.position});

  final String nodeId;
  final Offset? position;

  @override
  List<Object?> get props => [nodeId, position];
}

/// 移动节点事件（单个）
class NodeMoveEvent extends GraphEvent {
  const NodeMoveEvent(this.nodeId, this.newPosition);

  final String nodeId;
  final Offset newPosition;

  @override
  List<Object?> get props => [nodeId, newPosition];
}

/// 移动节点事件（批量）
class NodeMultiMoveEvent extends GraphEvent {
  const NodeMultiMoveEvent(this.movements);

  final Map<String, Offset> movements;

  @override
  List<Object?> get props => [movements];
}

/// 移出节点事件
class NodeMoveOutEvent extends GraphEvent {
  const NodeMoveOutEvent(this.nodeId);

  final String nodeId;

  @override
  List<Object?> get props => [nodeId];
}


// 选择事件

/// 选择节点事件
class NodeSelectEvent extends GraphEvent {
  const NodeSelectEvent(this.nodeId, {this.addToSelection = false});

  final String nodeId;
  final bool addToSelection;

  @override
  List<Object?> get props => [nodeId, addToSelection];
}

/// 选择多个节点事件
class NodeMultiSelectEvent extends GraphEvent {
  const NodeMultiSelectEvent(this.nodeIds);

  final Set<String> nodeIds;

  @override
  List<Object?> get props => [nodeIds];
}

/// 清除选择事件
class SelectionClearEvent extends GraphEvent {
  const SelectionClearEvent();
}

// 视图操作事件

/// 缩放事件
class ViewZoomEvent extends GraphEvent {
  const ViewZoomEvent(this.zoomLevel);

  final double zoomLevel;

  @override
  List<Object?> get props => [zoomLevel];
}

/// 移动相机位置事件
class ViewMoveEvent extends GraphEvent {
  const ViewMoveEvent(this.position);

  final Offset position;

  @override
  List<Object?> get props => [position];
}

/// 切换连接线显示事件
class ViewToggleConnectionsEvent extends GraphEvent {
  const ViewToggleConnectionsEvent();
}

/// 切换网格显示事件
class ViewToggleGridEvent extends GraphEvent {
  const ViewToggleGridEvent();
}

/// 聚焦节点事件
class FocusNodeEvent extends GraphEvent {
  const FocusNodeEvent(this.nodeId);

  final String nodeId;

  @override
  List<Object?> get props => [nodeId];
}

// 布局事件

/// 应用布局事件
class LayoutApplyEvent extends GraphEvent {
  const LayoutApplyEvent(this.algorithm);

  final LayoutAlgorithm algorithm;

  @override
  List<Object?> get props => [algorithm];
}

// 批量操作事件

/// 批量事件
class BatchEvent extends GraphEvent {
  const BatchEvent(this.events);

  final List<GraphEvent> events;

  @override
  List<Object?> get props => [events];
}

// 撤销/重做事件

/// 撤销事件
class UndoEvent extends GraphEvent {
  const UndoEvent();
}

/// 重做事件
class RedoEvent extends GraphEvent {
  const RedoEvent();
}

// 插件事件

/// 执行插件事件
class PluginExecuteEvent extends GraphEvent {
  const PluginExecuteEvent(this.pluginId, {this.data});

  final String pluginId;
  final Map<String, dynamic>? data;

  @override
  List<Object?> get props => [pluginId, data];
}

// 错误处理事件

/// 清除错误事件
class ErrorClearEvent extends GraphEvent {
  const ErrorClearEvent();
}

/// 重试事件
class RetryEvent extends GraphEvent {
  const RetryEvent();
}
