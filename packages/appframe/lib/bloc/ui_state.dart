import 'package:core_data/core_data.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// UI 状态 - 整个 UI 管理的不可变快照
@immutable
class UIState extends Equatable {
  /// 创建一个 UIState 实例
  const UIState({
    required this.nodeViewMode,
    required this.showConnections,
    required this.backgroundStyle,
    required this.isSidebarOpen,
    required this.selectedTab,
    required this.sidebarWidth,
    required this.isToolbarExpanded,
  });

  /// 创建一个默认的 UIState 实例
  factory UIState.initial() => const UIState(
    nodeViewMode: NodeViewMode.titleWithPreview,
    showConnections: true,
    backgroundStyle: BackgroundStyle.grid,
    isSidebarOpen: true,
    selectedTab: 'nodes',
    sidebarWidth: 300,
    isToolbarExpanded: true,
  );

  /// 节点视图模式
  final NodeViewMode nodeViewMode;

  /// 是否显示连接线
  final bool showConnections;

  /// 背景样式
  final BackgroundStyle backgroundStyle;

  /// 侧边栏是否打开
  final bool isSidebarOpen;

  /// 当前选中的标签页
  final String selectedTab;

  /// 侧边栏宽度
  final double sidebarWidth;

  /// 工具栏是否展开
  final bool isToolbarExpanded;

  /// 获取默认视图模式
  NodeViewMode get defaultViewMode => nodeViewMode;

  /// 复制并修改 UIState 实例
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
