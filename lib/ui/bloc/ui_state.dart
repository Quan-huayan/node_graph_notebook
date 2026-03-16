import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../core/models/enums.dart';

/// UI 状态 - 整个 UI 管理的不可变快照
@immutable
class UIState extends Equatable {
  /// 创建一个新的 UI 状态
  ///
  /// [nodeViewMode] - 节点显示模式
  /// [showConnections] - 是否显示连接线
  /// [backgroundStyle] - 背景样式
  /// [isSidebarOpen] - 侧边栏是否打开
  /// [selectedTab] - 选中的标签页
  /// [sidebarWidth] - 侧边栏宽度
  /// [isToolbarExpanded] - 工具栏是否展开
  const UIState({
    required this.nodeViewMode,
    required this.showConnections,
    required this.backgroundStyle,
    required this.isSidebarOpen,
    required this.selectedTab,
    required this.sidebarWidth,
    required this.isToolbarExpanded,
  });

  /// 初始状态
  factory UIState.initial() => const UIState(
      nodeViewMode: NodeViewMode.titleWithPreview,
      showConnections: true,
      backgroundStyle: BackgroundStyle.grid,
      isSidebarOpen: true,
      selectedTab: 'nodes',
      sidebarWidth: 300,
      isToolbarExpanded: true,
    );

  // 核心数据
  /// 节点显示模式
  final NodeViewMode nodeViewMode;

  /// 是否显示连接线
  final bool showConnections;

  /// 背景样式
  final BackgroundStyle backgroundStyle;

  /// 侧边栏是否打开
  final bool isSidebarOpen;

  /// 选中的标签页
  final String selectedTab;

  /// 侧边栏宽度
  final double sidebarWidth;

  /// 工具栏是否展开
  final bool isToolbarExpanded;

  /// 便捷方法：获取默认视图模式
  NodeViewMode get defaultViewMode => nodeViewMode;

  /// 复制并更新部分字段
  ///
  /// 返回一个新的 UI 状态，其中包含指定的字段更新
  UIState copyWith({
    NodeViewMode? nodeViewMode,
    bool? showConnections,
    BackgroundStyle? backgroundStyle,
    bool? isSidebarOpen,
    String? selectedTab,
    double? sidebarWidth,
    bool? isToolbarExpanded,
  }) => UIState(
      nodeViewMode: nodeViewMode ?? this.nodeViewMode,
      showConnections: showConnections ?? this.showConnections,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      isSidebarOpen: isSidebarOpen ?? this.isSidebarOpen,
      selectedTab: selectedTab ?? this.selectedTab,
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      isToolbarExpanded: isToolbarExpanded ?? this.isToolbarExpanded,
    );

  @override
  List<Object?> get props => [
        nodeViewMode,
        showConnections,
        backgroundStyle,
        isSidebarOpen,
        selectedTab,
        sidebarWidth,
        isToolbarExpanded,
      ];
}
