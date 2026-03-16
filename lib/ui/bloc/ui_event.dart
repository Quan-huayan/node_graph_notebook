import 'package:equatable/equatable.dart';
import '../../core/models/enums.dart';

/// UI 事件基类
abstract class UIEvent extends Equatable {
  /// 创建一个 UI 事件
  const UIEvent();

  @override
  List<Object?> get props => [];
}

// 节点显示模式事件

/// 设置节点显示模式事件
class UISetNodeViewModeEvent extends UIEvent {
  /// 创建一个设置节点显示模式事件
  ///
  /// [mode] - 要设置的节点显示模式
  const UISetNodeViewModeEvent(this.mode);

  /// 节点显示模式
  final NodeViewMode mode;

  @override
  List<Object?> get props => [mode];
}

/// 设置默认节点显示模式事件
class UISetDefaultViewModeEvent extends UIEvent {
  /// 创建一个设置默认节点显示模式事件
  ///
  /// [mode] - 要设置的默认节点显示模式
  const UISetDefaultViewModeEvent(this.mode);

  /// 默认节点显示模式
  final NodeViewMode mode;

  @override
  List<Object?> get props => [mode];
}

// 连接线显示事件

/// 切换连接线显示事件
class UIToggleConnectionsEvent extends UIEvent {
  /// 创建一个切换连接线显示事件
  const UIToggleConnectionsEvent();
}

/// 设置连接线显示事件
class UISetConnectionsEvent extends UIEvent {
  /// 创建一个设置连接线显示事件
  ///
  /// [show] - 是否显示连接线
  const UISetConnectionsEvent(this.show);

  /// 是否显示连接线
  final bool show;

  @override
  List<Object?> get props => [show];
}

// 背景样式事件

/// 设置背景样式事件
class UISetBackgroundStyleEvent extends UIEvent {
  /// 创建一个设置背景样式事件
  ///
  /// [style] - 要设置的背景样式
  const UISetBackgroundStyleEvent(this.style);

  /// 背景样式
  final BackgroundStyle style;

  @override
  List<Object?> get props => [style];
}

// 侧边栏事件

/// 切换侧边栏事件
class UIToggleSidebarEvent extends UIEvent {
  /// 创建一个切换侧边栏事件
  const UIToggleSidebarEvent();
}

/// 设置侧边栏事件
class UISetSidebarEvent extends UIEvent {
  /// 创建一个设置侧边栏事件
  ///
  /// [open] - 侧边栏是否打开
  const UISetSidebarEvent(this.open);

  /// 侧边栏是否打开
  final bool open;

  @override
  List<Object?> get props => [open];
}

/// 打开侧边栏事件
class UIOpenSidebarEvent extends UIEvent {
  /// 创建一个打开侧边栏事件
  const UIOpenSidebarEvent();
}

/// 关闭侧边栏事件
class UICloseSidebarEvent extends UIEvent {
  /// 创建一个关闭侧边栏事件
  const UICloseSidebarEvent();
}

// 标签页事件

/// 选择标签页事件
class UISelectTabEvent extends UIEvent {
  /// 创建一个选择标签页事件
  ///
  /// [tab] - 要选择的标签页
  const UISelectTabEvent(this.tab);

  /// 要选择的标签页
  final String tab;

  @override
  List<Object?> get props => [tab];
}

// 侧边栏宽度事件

/// 设置侧边栏宽度事件
class UISetSidebarWidthEvent extends UIEvent {
  /// 创建一个设置侧边栏宽度事件
  ///
  /// [width] - 侧边栏宽度
  const UISetSidebarWidthEvent(this.width);

  /// 侧边栏宽度
  final double width;

  @override
  List<Object?> get props => [width];
}

// 工具栏事件

/// 切换工具栏展开状态事件
class UIToggleToolbarEvent extends UIEvent {
  /// 创建一个切换工具栏展开状态事件
  const UIToggleToolbarEvent();
}

/// 设置工具栏展开状态事件
class UISetToolbarEvent extends UIEvent {
  /// 创建一个设置工具栏展开状态事件
  ///
  /// [expanded] - 工具栏是否展开
  const UISetToolbarEvent(this.expanded);

  /// 工具栏是否展开
  final bool expanded;

  @override
  List<Object?> get props => [expanded];
}
