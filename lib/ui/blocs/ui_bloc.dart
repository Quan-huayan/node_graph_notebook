import 'package:flutter_bloc/flutter_bloc.dart';
import 'ui_event.dart';
import 'ui_state.dart';

/// UI BLoC - UI 状态管理核心
class UIBloc extends Bloc<UIEvent, UIState> {
  UIBloc() : super(UIState.initial()) {
    // 注册事件处理器
    on<UISetNodeViewModeEvent>(_onSetNodeViewMode);
    on<UISetDefaultViewModeEvent>(_onSetDefaultViewMode);
    on<UIToggleConnectionsEvent>(_onToggleConnections);
    on<UISetConnectionsEvent>(_onSetConnections);
    on<UISetBackgroundStyleEvent>(_onSetBackgroundStyle);
    on<UIToggleSidebarEvent>(_onToggleSidebar);
    on<UISetSidebarEvent>(_onSetSidebar);
    on<UIOpenSidebarEvent>(_onOpenSidebar);
    on<UICloseSidebarEvent>(_onCloseSidebar);
    on<UISelectTabEvent>(_onSelectTab);
  }

  /// 设置节点显示模式
  void _onSetNodeViewMode(
    UISetNodeViewModeEvent event,
    Emitter<UIState> emit,
  ) {
    emit(state.copyWith(nodeViewMode: event.mode));
  }

  /// 设置默认节点显示模式
  void _onSetDefaultViewMode(
    UISetDefaultViewModeEvent event,
    Emitter<UIState> emit,
  ) {
    emit(state.copyWith(nodeViewMode: event.mode));
  }

  /// 切换连接线显示
  void _onToggleConnections(
    UIToggleConnectionsEvent event,
    Emitter<UIState> emit,
  ) {
    emit(state.copyWith(showConnections: !state.showConnections));
  }

  /// 设置连接线显示
  void _onSetConnections(
    UISetConnectionsEvent event,
    Emitter<UIState> emit,
  ) {
    emit(state.copyWith(showConnections: event.show));
  }

  /// 设置背景样式
  void _onSetBackgroundStyle(
    UISetBackgroundStyleEvent event,
    Emitter<UIState> emit,
  ) {
    emit(state.copyWith(backgroundStyle: event.style));
  }

  /// 切换侧边栏
  void _onToggleSidebar(
    UIToggleSidebarEvent event,
    Emitter<UIState> emit,
  ) {
    emit(state.copyWith(isSidebarOpen: !state.isSidebarOpen));
  }

  /// 设置侧边栏
  void _onSetSidebar(
    UISetSidebarEvent event,
    Emitter<UIState> emit,
  ) {
    emit(state.copyWith(isSidebarOpen: event.open));
  }

  /// 打开侧边栏
  void _onOpenSidebar(
    UIOpenSidebarEvent event,
    Emitter<UIState> emit,
  ) {
    emit(state.copyWith(isSidebarOpen: true));
  }

  /// 关闭侧边栏
  void _onCloseSidebar(
    UICloseSidebarEvent event,
    Emitter<UIState> emit,
  ) {
    emit(state.copyWith(isSidebarOpen: false));
  }

  /// 选择标签页
  void _onSelectTab(
    UISelectTabEvent event,
    Emitter<UIState> emit,
  ) {
    emit(state.copyWith(selectedTab: event.tab));
  }
}
