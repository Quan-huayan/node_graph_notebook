import 'package:flutter_bloc/flutter_bloc.dart';

import 'ui_event.dart';
import 'ui_state.dart';

/// UI BLoC - UI 状态管理核心
///
/// 负责管理整个应用的UI状态，包括节点显示模式、连接线显示、背景样式、侧边栏状态等
class UIBloc extends Bloc<UIEvent, UIState> {
  /// 构造函数: bloc 初始化
  UIBloc() : super(UIState.initial()) {
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
    on<UISetSidebarWidthEvent>(_onSetSidebarWidth);
    on<UIToggleToolbarEvent>(_onToggleToolbar);
    on<UISetToolbarEvent>(_onSetToolbar);
  }

  void _onSetNodeViewMode(UISetNodeViewModeEvent event, Emitter<UIState> emit) {
    emit(state.copyWith(nodeViewMode: event.mode));
  }

  void _onSetDefaultViewMode(UISetDefaultViewModeEvent event, Emitter<UIState> emit) {
    emit(state.copyWith(nodeViewMode: event.mode));
  }

  void _onToggleConnections(UIToggleConnectionsEvent event, Emitter<UIState> emit) {
    emit(state.copyWith(showConnections: !state.showConnections));
  }

  void _onSetConnections(UISetConnectionsEvent event, Emitter<UIState> emit) {
    emit(state.copyWith(showConnections: event.show));
  }

  void _onSetBackgroundStyle(UISetBackgroundStyleEvent event, Emitter<UIState> emit) {
    emit(state.copyWith(backgroundStyle: event.style));
  }

  void _onToggleSidebar(UIToggleSidebarEvent event, Emitter<UIState> emit) {
    emit(state.copyWith(isSidebarOpen: !state.isSidebarOpen));
  }

  void _onSetSidebar(UISetSidebarEvent event, Emitter<UIState> emit) {
    emit(state.copyWith(isSidebarOpen: event.open));
  }

  void _onOpenSidebar(UIOpenSidebarEvent event, Emitter<UIState> emit) {
    emit(state.copyWith(isSidebarOpen: true));
  }

  void _onCloseSidebar(UICloseSidebarEvent event, Emitter<UIState> emit) {
    emit(state.copyWith(isSidebarOpen: false));
  }

  void _onSelectTab(UISelectTabEvent event, Emitter<UIState> emit) {
    emit(state.copyWith(selectedTab: event.tab));
  }

  void _onSetSidebarWidth(UISetSidebarWidthEvent event, Emitter<UIState> emit) {
    final width = event.width.clamp(150.0, 500.0);
    emit(state.copyWith(sidebarWidth: width));
  }

  void _onToggleToolbar(UIToggleToolbarEvent event, Emitter<UIState> emit) {
    emit(state.copyWith(isToolbarExpanded: !state.isToolbarExpanded));
  }

  void _onSetToolbar(UISetToolbarEvent event, Emitter<UIState> emit) {
    emit(state.copyWith(isToolbarExpanded: event.expanded));
  }
}
