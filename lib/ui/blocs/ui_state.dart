import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../core/models/enums.dart';

/// UI 状态 - 整个 UI 管理的不可变快照
@immutable
class UIState extends Equatable {
  const UIState({
    required this.nodeViewMode,
    required this.showConnections,
    required this.backgroundStyle,
    required this.isSidebarOpen,
    required this.selectedTab,
  });

  /// 初始状态
  factory UIState.initial() {
    return const UIState(
      nodeViewMode: NodeViewMode.titleWithPreview,
      showConnections: true,
      backgroundStyle: BackgroundStyle.grid,
      isSidebarOpen: true,
      selectedTab: 'nodes',
    );
  }

  // 核心数据
  final NodeViewMode nodeViewMode;
  final bool showConnections;
  final BackgroundStyle backgroundStyle;
  final bool isSidebarOpen;
  final String selectedTab;

  /// 便捷方法
  NodeViewMode get defaultViewMode => nodeViewMode;

  /// 复制并更新部分字段
  UIState copyWith({
    NodeViewMode? nodeViewMode,
    bool? showConnections,
    BackgroundStyle? backgroundStyle,
    bool? isSidebarOpen,
    String? selectedTab,
  }) {
    return UIState(
      nodeViewMode: nodeViewMode ?? this.nodeViewMode,
      showConnections: showConnections ?? this.showConnections,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      isSidebarOpen: isSidebarOpen ?? this.isSidebarOpen,
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }

  @override
  List<Object?> get props => [
        nodeViewMode,
        showConnections,
        backgroundStyle,
        isSidebarOpen,
        selectedTab,
      ];
}
