import 'package:equatable/equatable.dart';
import '../../core/models/enums.dart';

/// UI 事件基类
abstract class UIEvent extends Equatable {
  const UIEvent();

  @override
  List<Object?> get props => [];
}

// 节点显示模式事件

/// 设置节点显示模式事件
class UISetNodeViewModeEvent extends UIEvent {
  const UISetNodeViewModeEvent(this.mode);

  final NodeViewMode mode;

  @override
  List<Object?> get props => [mode];
}

/// 设置默认节点显示模式事件
class UISetDefaultViewModeEvent extends UIEvent {
  const UISetDefaultViewModeEvent(this.mode);

  final NodeViewMode mode;

  @override
  List<Object?> get props => [mode];
}

// 连接线显示事件

/// 切换连接线显示事件
class UIToggleConnectionsEvent extends UIEvent {
  const UIToggleConnectionsEvent();
}

/// 设置连接线显示事件
class UISetConnectionsEvent extends UIEvent {
  const UISetConnectionsEvent(this.show);

  final bool show;

  @override
  List<Object?> get props => [show];
}

// 背景样式事件

/// 设置背景样式事件
class UISetBackgroundStyleEvent extends UIEvent {
  const UISetBackgroundStyleEvent(this.style);

  final BackgroundStyle style;

  @override
  List<Object?> get props => [style];
}

// 侧边栏事件

/// 切换侧边栏事件
class UIToggleSidebarEvent extends UIEvent {
  const UIToggleSidebarEvent();
}

/// 设置侧边栏事件
class UISetSidebarEvent extends UIEvent {
  const UISetSidebarEvent(this.open);

  final bool open;

  @override
  List<Object?> get props => [open];
}

/// 打开侧边栏事件
class UIOpenSidebarEvent extends UIEvent {
  const UIOpenSidebarEvent();
}

/// 关闭侧边栏事件
class UICloseSidebarEvent extends UIEvent {
  const UICloseSidebarEvent();
}

// 标签页事件

/// 选择标签页事件
class UISelectTabEvent extends UIEvent {
  const UISelectTabEvent(this.tab);

  final String tab;

  @override
  List<Object?> get props => [tab];
}
