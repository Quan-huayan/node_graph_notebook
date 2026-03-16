import 'dart:ui';
import 'package:equatable/equatable.dart';
import '../../../../core/models/models.dart';

/// 图事件基类
abstract class GraphEvent extends Equatable {
  /// 创建图事件
  const GraphEvent();

  @override
  List<Object?> get props => [];
}

// 初始化事件

/// 图初始化事件
class GraphInitializeEvent extends GraphEvent {
  /// 创建图初始化事件
  const GraphInitializeEvent();
}

/// 图加载事件
class GraphLoadEvent extends GraphEvent {
  /// 创建图加载事件
  const GraphLoadEvent(this.graphId);

  /// 图 ID
  final String graphId;

  @override
  List<Object?> get props => [graphId];
}

// 图操作事件

/// 创建图事件
class GraphCreateEvent extends GraphEvent {
  /// 创建图事件
  const GraphCreateEvent(this.name);

  /// 图名称
  final String name;

  @override
  List<Object?> get props => [name];
}

/// 切换图事件
class GraphSwitchEvent extends GraphEvent {
  /// 创建切换图事件
  const GraphSwitchEvent(this.graphId);

  /// 图 ID
  final String graphId;

  @override
  List<Object?> get props => [graphId];
}

/// 重命名图事件
class GraphRenameEvent extends GraphEvent {
  /// 创建重命名图事件
  const GraphRenameEvent(this.name);

  /// 新的图名称
  final String name;

  @override
  List<Object?> get props => [name];
}

/// 更新图配置事件
class GraphUpdateConfigEvent extends GraphEvent {
  /// 创建更新图配置事件
  const GraphUpdateConfigEvent(this.config);

  /// 图视图配置
  final GraphViewConfig config;

  @override
  List<Object?> get props => [config];
}

// 节点视图操作事件

/// 添加节点事件
class NodeAddEvent extends GraphEvent {
  /// 创建添加节点事件
  const NodeAddEvent(this.nodeId, {this.position});

  /// 节点 ID
  final String nodeId;
  /// 节点位置
  final Offset? position;

  @override
  List<Object?> get props => [nodeId, position];
}

/// 移动节点事件（单个）
class NodeMoveEvent extends GraphEvent {
  /// 创建移动节点事件
  const NodeMoveEvent(this.nodeId, this.newPosition);

  /// 节点 ID
  final String nodeId;
  /// 新位置
  final Offset newPosition;

  @override
  List<Object?> get props => [nodeId, newPosition];
}

/// 移动节点事件（批量）
class NodeMultiMoveEvent extends GraphEvent {
  /// 创建批量移动节点事件
  const NodeMultiMoveEvent(this.movements);

  /// 节点移动映射，键为节点 ID，值为新位置
  final Map<String, Offset> movements;

  @override
  List<Object?> get props => [movements];
}

/// 移出节点事件
class NodeMoveOutEvent extends GraphEvent {
  /// 创建移出节点事件
  const NodeMoveOutEvent(this.nodeId);

  /// 节点 ID
  final String nodeId;

  @override
  List<Object?> get props => [nodeId];
}

// 选择事件

/// 选择节点事件
class NodeSelectEvent extends GraphEvent {
  /// 创建选择节点事件
  const NodeSelectEvent(this.nodeId, {this.addToSelection = false});

  /// 节点 ID
  final String nodeId;
  /// 是否添加到现有选择
  final bool addToSelection;

  @override
  List<Object?> get props => [nodeId, addToSelection];
}

/// 选择多个节点事件
class NodeMultiSelectEvent extends GraphEvent {
  /// 创建选择多个节点事件
  const NodeMultiSelectEvent(this.nodeIds);

  /// 节点 ID 集合
  final Set<String> nodeIds;

  @override
  List<Object?> get props => [nodeIds];
}

/// 清除选择事件
class SelectionClearEvent extends GraphEvent {
  /// 创建清除选择事件
  const SelectionClearEvent();
}

// 视图操作事件

/// 缩放事件
class ViewZoomEvent extends GraphEvent {
  /// 创建缩放事件
  const ViewZoomEvent(this.zoomLevel, {this.position});

  /// 缩放级别
  final double zoomLevel;
  /// 可选的相机位置（以鼠标为中心缩放时需要）
  final Offset? position;

  @override
  List<Object?> get props => [zoomLevel, position];
}

/// 移动相机位置事件
class ViewMoveEvent extends GraphEvent {
  /// 创建移动相机位置事件
  const ViewMoveEvent(this.position);

  /// 新的相机位置
  final Offset position;

  @override
  List<Object?> get props => [position];
}

/// 切换连接线显示事件
class ViewToggleConnectionsEvent extends GraphEvent {
  /// 创建切换连接线显示事件
  const ViewToggleConnectionsEvent();
}

/// 切换网格显示事件
class ViewToggleGridEvent extends GraphEvent {
  /// 创建切换网格显示事件
  const ViewToggleGridEvent();
}

/// 聚焦节点事件
class FocusNodeEvent extends GraphEvent {
  /// 创建聚焦节点事件
  const FocusNodeEvent(this.nodeId);

  /// 节点 ID
  final String nodeId;

  @override
  List<Object?> get props => [nodeId];
}

// 布局事件

/// 应用布局事件
class LayoutApplyEvent extends GraphEvent {
  /// 创建应用布局事件
  const LayoutApplyEvent(this.algorithm);

  /// 布局算法
  final LayoutAlgorithm algorithm;

  @override
  List<Object?> get props => [algorithm];
}

// 批量操作事件

/// 批量事件
class BatchEvent extends GraphEvent {
  /// 创建批量事件
  const BatchEvent(this.events);

  /// 事件列表
  final List<GraphEvent> events;

  @override
  List<Object?> get props => [events];
}

// 撤销/重做事件

/// 撤销事件
class UndoEvent extends GraphEvent {
  /// 创建撤销事件
  const UndoEvent();
}

/// 重做事件
class RedoEvent extends GraphEvent {
  /// 创建重做事件
  const RedoEvent();
}

// 插件事件

/// 执行插件事件
class PluginExecuteEvent extends GraphEvent {
  /// 创建执行插件事件
  const PluginExecuteEvent(this.pluginId, {this.data});

  /// 插件 ID
  final String pluginId;
  /// 插件数据
  final Map<String, dynamic>? data;

  @override
  List<Object?> get props => [pluginId, data];
}

// 错误处理事件

/// 清除错误事件
class ErrorClearEvent extends GraphEvent {
  /// 创建清除错误事件
  const ErrorClearEvent();
}

/// 重试事件
class RetryEvent extends GraphEvent {
  /// 创建重试事件
  const RetryEvent();
}
