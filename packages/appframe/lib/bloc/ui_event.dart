import 'package:core_data/core_data.dart';
import 'package:equatable/equatable.dart';

/// UI 事件基类。
abstract class UIEvent extends Equatable {
  /// 创建一个 UI 事件实例。
  const UIEvent();

  @override
  List<Object?> get props => [];
}

/// 设置节点显示模式的事件。
class UISetNodeViewModeEvent extends UIEvent {
  /// 创建一个设置节点显示模式的事件。
  const UISetNodeViewModeEvent(this.mode);

  /// 要设置的节点显示模式。
  final NodeViewMode mode;

  @override
  List<Object?> get props => [mode];
}

/// 设置默认节点显示模式的事件。
class UISetDefaultViewModeEvent extends UIEvent {
  /// 创建一个设置默认节点显示模式的事件。
  const UISetDefaultViewModeEvent(this.mode);

  /// 要设置的默认节点显示模式。
  final NodeViewMode mode;

  @override
  List<Object?> get props => [mode];
}

/// 切换连接线显示的事件。
class UIToggleConnectionsEvent extends UIEvent {
  /// 创建一个切换连接线显示的事件。
  const UIToggleConnectionsEvent();
}

/// 设置连接线显示的事件。
class UISetConnectionsEvent extends UIEvent {
  /// 创建一个设置连接线显示的事件。
  const UISetConnectionsEvent(this.show);

  /// 是否显示连接线。
  final bool show;

  @override
  List<Object?> get props => [show];
}

/// 设置背景样式的事件。
class UISetBackgroundStyleEvent extends UIEvent {
  /// 创建一个设置背景样式的事件。
  const UISetBackgroundStyleEvent(this.style);

  /// 要设置的背景样式。
  final BackgroundStyle style;

  @override
  List<Object?> get props => [style];
}

/// 切换侧边栏的事件。
class UIToggleSidebarEvent extends UIEvent {
  /// 创建一个切换侧边栏的事件。
  const UIToggleSidebarEvent();
}

/// 设置侧边栏状态的事件。
class UISetSidebarEvent extends UIEvent {
  /// 创建一个设置侧边栏状态的事件。
  const UISetSidebarEvent(this.open);

  /// 是否打开侧边栏。
  final bool open;

  @override
  List<Object?> get props => [open];
}

/// 打开侧边栏的事件。
class UIOpenSidebarEvent extends UIEvent {
  /// 创建一个打开侧边栏的事件。
  const UIOpenSidebarEvent();
}

/// 关闭侧边栏的事件。
class UICloseSidebarEvent extends UIEvent {
  /// 创建一个关闭侧边栏的事件。
  const UICloseSidebarEvent();
}

/// 选择标签页的事件。
class UISelectTabEvent extends UIEvent {
  /// 创建一个选择标签页的事件。
  const UISelectTabEvent(this.tab);

  /// 要选择的标签页标识。
  final String tab;

  @override
  List<Object?> get props => [tab];
}

/// 设置侧边栏宽度的事件。
class UISetSidebarWidthEvent extends UIEvent {
  /// 创建一个设置侧边栏宽度的事件。
  const UISetSidebarWidthEvent(this.width);

  /// 侧边栏的宽度值。
  final double width;

  @override
  List<Object?> get props => [width];
}

/// 切换工具栏展开状态的事件。
class UIToggleToolbarEvent extends UIEvent {
  /// 创建一个切换工具栏展开状态的事件。
  const UIToggleToolbarEvent();
}

/// 设置工具栏展开状态的事件。
class UISetToolbarEvent extends UIEvent {
  /// 创建一个设置工具栏展开状态的事件。
  const UISetToolbarEvent(this.expanded);

  /// 是否展开工具栏。
  final bool expanded;

  @override
  List<Object?> get props => [expanded];
}
