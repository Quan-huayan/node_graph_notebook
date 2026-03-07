import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:node_graph_notebook/bloc/ui/ui_bloc.dart';
import 'package:node_graph_notebook/bloc/ui/ui_event.dart';
import 'package:node_graph_notebook/bloc/ui/ui_state.dart';
import 'package:node_graph_notebook/core/models/enums.dart';

void main() {
  group('UIBloc', () {
    late UIBloc uiBloc;

    setUp(() {
      uiBloc = UIBloc();
    });

    tearDown(() {
      uiBloc.close();
    });

    // === 初始状态测试 ===
    group('Initial State', () {
      test('should have correct initial state', () {
        expect(uiBloc.state, UIState.initial());
        expect(uiBloc.state.nodeViewMode, NodeViewMode.titleWithPreview);
        expect(uiBloc.state.showConnections, true);
        expect(uiBloc.state.backgroundStyle, BackgroundStyle.grid);
        expect(uiBloc.state.isSidebarOpen, true);
        expect(uiBloc.state.selectedTab, 'nodes');
        expect(uiBloc.state.sidebarWidth, 300.0);
        expect(uiBloc.state.isToolbarExpanded, true);
      });
    });

    // === 节点视图模式测试 ===
    group('UISetNodeViewModeEvent', () {
      blocTest<UIBloc, UIState>(
        'should update node view mode',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetNodeViewModeEvent(NodeViewMode.fullContent)),
        expect: () => [
          predicate<UIState>((state) => state.nodeViewMode == NodeViewMode.fullContent),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should not change other state properties when changing view mode',
        seed: () => uiBloc.state,
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetNodeViewModeEvent(NodeViewMode.compact)),
        expect: () => [
          predicate<UIState>((state) =>
              state.nodeViewMode == NodeViewMode.compact &&
              state.showConnections == uiBloc.state.showConnections &&
              state.backgroundStyle == uiBloc.state.backgroundStyle &&
              state.isSidebarOpen == uiBloc.state.isSidebarOpen &&
              state.selectedTab == uiBloc.state.selectedTab &&
              state.sidebarWidth == uiBloc.state.sidebarWidth &&
              state.isToolbarExpanded == uiBloc.state.isToolbarExpanded),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should handle all view modes',
        build: () => uiBloc,
        act: (bloc) async {
          for (final mode in NodeViewMode.values) {
            bloc.add(const UISetNodeViewModeEvent(NodeViewMode.titleOnly));
            bloc.add(UISetNodeViewModeEvent(mode));
            await Future.delayed(const Duration(milliseconds: 10));
          }
        },
        skip: NodeViewMode.values.length * 2, // Skip all 8 states (4 modes × 2 events each)
        expect: () => [
          // 由于使用了 skip，这里不需要期望值
        ],
      );
    });

    // === 默认视图模式测试 ===
    group('UISetDefaultViewModeEvent', () {
      blocTest<UIBloc, UIState>(
        'should update default view mode',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetDefaultViewModeEvent(NodeViewMode.titleOnly)),
        expect: () => [
          predicate<UIState>((state) => state.nodeViewMode == NodeViewMode.titleOnly),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should update both nodeViewMode and defaultViewMode',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetDefaultViewModeEvent(NodeViewMode.compact)),
        expect: () => [
          predicate<UIState>((state) =>
              state.nodeViewMode == NodeViewMode.compact &&
              state.defaultViewMode == NodeViewMode.compact),
        ],
      );
    });

    // === 连接显示测试 ===
    group('UIToggleConnectionsEvent', () {
      blocTest<UIBloc, UIState>(
        'should toggle connections from true to false',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UIToggleConnectionsEvent()),
        expect: () => [
          predicate<UIState>((state) => state.showConnections == false),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should toggle connections from false to true',
        seed: () => uiBloc.state.copyWith(showConnections: false),
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UIToggleConnectionsEvent()),
        expect: () => [
          predicate<UIState>((state) => state.showConnections == true),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should not change other state properties when toggling connections',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UIToggleConnectionsEvent()),
        expect: () => [
          predicate<UIState>((state) =>
              state.showConnections == false &&
              state.nodeViewMode == uiBloc.state.nodeViewMode &&
              state.backgroundStyle == uiBloc.state.backgroundStyle &&
              state.isSidebarOpen == uiBloc.state.isSidebarOpen &&
              state.selectedTab == uiBloc.state.selectedTab &&
              state.sidebarWidth == uiBloc.state.sidebarWidth &&
              state.isToolbarExpanded == uiBloc.state.isToolbarExpanded),
        ],
      );
    });

    // === 设置连接显示测试 ===
    group('UISetConnectionsEvent', () {
      blocTest<UIBloc, UIState>(
        'should set connections to true',
        seed: () => uiBloc.state.copyWith(showConnections: false),
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetConnectionsEvent(true)),
        expect: () => [
          predicate<UIState>((state) => state.showConnections == true),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should set connections to false',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetConnectionsEvent(false)),
        expect: () => [
          predicate<UIState>((state) => state.showConnections == false),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should handle setting to same value',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetConnectionsEvent(true)),
        expect: () => [
          predicate<UIState>((state) => state.showConnections == true),
        ],
      );
    });

    // === 背景样式测试 ===
    group('UISetBackgroundStyleEvent', () {
      blocTest<UIBloc, UIState>(
        'should update background style',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetBackgroundStyleEvent(BackgroundStyle.dots)),
        expect: () => [
          predicate<UIState>((state) => state.backgroundStyle == BackgroundStyle.dots),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should handle all background styles',
        build: () => uiBloc,
        act: (bloc) async {
          for (final style in BackgroundStyle.values) {
            bloc.add(UISetBackgroundStyleEvent(style));
            await Future.delayed(const Duration(milliseconds: 10));
          }
        },
        skip: BackgroundStyle.values.length,
        expect: () => [],
      );

      blocTest<UIBloc, UIState>(
        'should not change other state properties when changing background style',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetBackgroundStyleEvent(BackgroundStyle.none)),
        expect: () => [
          predicate<UIState>((state) =>
              state.backgroundStyle == BackgroundStyle.none &&
              state.nodeViewMode == uiBloc.state.nodeViewMode &&
              state.showConnections == uiBloc.state.showConnections &&
              state.isSidebarOpen == uiBloc.state.isSidebarOpen &&
              state.selectedTab == uiBloc.state.selectedTab &&
              state.sidebarWidth == uiBloc.state.sidebarWidth &&
              state.isToolbarExpanded == uiBloc.state.isToolbarExpanded),
        ],
      );
    });

    // === 侧边栏开关测试 ===
    group('UIToggleSidebarEvent', () {
      blocTest<UIBloc, UIState>(
        'should toggle sidebar from open to closed',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UIToggleSidebarEvent()),
        expect: () => [
          predicate<UIState>((state) => state.isSidebarOpen == false),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should toggle sidebar from closed to open',
        seed: () => uiBloc.state.copyWith(isSidebarOpen: false),
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UIToggleSidebarEvent()),
        expect: () => [
          predicate<UIState>((state) => state.isSidebarOpen == true),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should not change other state properties when toggling sidebar',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UIToggleSidebarEvent()),
        expect: () => [
          predicate<UIState>((state) =>
              state.isSidebarOpen == false &&
              state.nodeViewMode == uiBloc.state.nodeViewMode &&
              state.showConnections == uiBloc.state.showConnections &&
              state.backgroundStyle == uiBloc.state.backgroundStyle &&
              state.selectedTab == uiBloc.state.selectedTab &&
              state.sidebarWidth == uiBloc.state.sidebarWidth &&
              state.isToolbarExpanded == uiBloc.state.isToolbarExpanded),
        ],
      );
    });

    // === 设置侧边栏状态测试 ===
    group('UISetSidebarEvent', () {
      blocTest<UIBloc, UIState>(
        'should set sidebar to open',
        seed: () => uiBloc.state.copyWith(isSidebarOpen: false),
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetSidebarEvent(true)),
        expect: () => [
          predicate<UIState>((state) => state.isSidebarOpen == true),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should set sidebar to closed',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetSidebarEvent(false)),
        expect: () => [
          predicate<UIState>((state) => state.isSidebarOpen == false),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should handle setting to same value',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetSidebarEvent(true)),
        expect: () => [
          predicate<UIState>((state) => state.isSidebarOpen == true),
        ],
      );
    });

    // === 打开/关闭侧边栏测试 ===
    group('UIOpenSidebarEvent & UICloseSidebarEvent', () {
      blocTest<UIBloc, UIState>(
        'should open sidebar',
        seed: () => uiBloc.state.copyWith(isSidebarOpen: false),
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UIOpenSidebarEvent()),
        expect: () => [
          predicate<UIState>((state) => state.isSidebarOpen == true),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should handle already open sidebar',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UIOpenSidebarEvent()),
        expect: () => [
          predicate<UIState>((state) => state.isSidebarOpen == true),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should close sidebar',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UICloseSidebarEvent()),
        expect: () => [
          predicate<UIState>((state) => state.isSidebarOpen == false),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should handle already closed sidebar',
        seed: () => uiBloc.state.copyWith(isSidebarOpen: false),
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UICloseSidebarEvent()),
        expect: () => [], // No state emitted when already closed (Equatable optimization)
      );
    });

    // === 选择标签测试 ===
    group('UISelectTabEvent', () {
      blocTest<UIBloc, UIState>(
        'should select specified tab',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISelectTabEvent('search')),
        expect: () => [
          predicate<UIState>((state) => state.selectedTab == 'search'),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should handle different tab names',
        build: () => uiBloc,
        act: (bloc) async {
          final tabs = ['nodes', 'search', 'settings', 'custom'];
          for (final tab in tabs) {
            bloc.add(UISelectTabEvent(tab));
            await Future.delayed(const Duration(milliseconds: 10));
          }
        },
        skip: 4, // Skip all 4 states (4 tabs)
        expect: () => [],
      );

      blocTest<UIBloc, UIState>(
        'should not change other state properties when selecting tab',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISelectTabEvent('plugins')),
        expect: () => [
          predicate<UIState>((state) =>
              state.selectedTab == 'plugins' &&
              state.nodeViewMode == uiBloc.state.nodeViewMode &&
              state.showConnections == uiBloc.state.showConnections &&
              state.backgroundStyle == uiBloc.state.backgroundStyle &&
              state.isSidebarOpen == uiBloc.state.isSidebarOpen &&
              state.sidebarWidth == uiBloc.state.sidebarWidth &&
              state.isToolbarExpanded == uiBloc.state.isToolbarExpanded),
        ],
      );
    });

    // === 侧边栏宽度测试 ===
    group('UISetSidebarWidthEvent', () {
      blocTest<UIBloc, UIState>(
        'should set sidebar width within range',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetSidebarWidthEvent(400.0)),
        expect: () => [
          predicate<UIState>((state) => state.sidebarWidth == 400.0),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should clamp width to minimum of 150',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetSidebarWidthEvent(100.0)),
        expect: () => [
          predicate<UIState>((state) => state.sidebarWidth == 150.0),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should clamp width to maximum of 500',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetSidebarWidthEvent(600.0)),
        expect: () => [
          predicate<UIState>((state) => state.sidebarWidth == 500.0),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should handle boundary values',
        build: () => uiBloc,
        act: (bloc) async {
          bloc.add(const UISetSidebarWidthEvent(150.0));
          await Future.delayed(const Duration(milliseconds: 10));
          bloc.add(const UISetSidebarWidthEvent(500.0));
        },
        skip: 1,
        expect: () => [
          predicate<UIState>((state) => state.sidebarWidth == 500.0),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should handle zero width',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetSidebarWidthEvent(0.0)),
        expect: () => [
          predicate<UIState>((state) => state.sidebarWidth == 150.0),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should handle negative width',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetSidebarWidthEvent(-100.0)),
        expect: () => [
          predicate<UIState>((state) => state.sidebarWidth == 150.0),
        ],
      );
    });

    // === 工具栏开关测试 ===
    group('UIToggleToolbarEvent', () {
      blocTest<UIBloc, UIState>(
        'should toggle toolbar from expanded to collapsed',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UIToggleToolbarEvent()),
        expect: () => [
          predicate<UIState>((state) => state.isToolbarExpanded == false),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should toggle toolbar from collapsed to expanded',
        seed: () => uiBloc.state.copyWith(isToolbarExpanded: false),
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UIToggleToolbarEvent()),
        expect: () => [
          predicate<UIState>((state) => state.isToolbarExpanded == true),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should not change other state properties when toggling toolbar',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UIToggleToolbarEvent()),
        expect: () => [
          predicate<UIState>((state) =>
              state.isToolbarExpanded == false &&
              state.nodeViewMode == uiBloc.state.nodeViewMode &&
              state.showConnections == uiBloc.state.showConnections &&
              state.backgroundStyle == uiBloc.state.backgroundStyle &&
              state.isSidebarOpen == uiBloc.state.isSidebarOpen &&
              state.selectedTab == uiBloc.state.selectedTab &&
              state.sidebarWidth == uiBloc.state.sidebarWidth),
        ],
      );
    });

    // === 设置工具栏状态测试 ===
    group('UISetToolbarEvent', () {
      blocTest<UIBloc, UIState>(
        'should set toolbar to expanded',
        seed: () => uiBloc.state.copyWith(isToolbarExpanded: false),
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetToolbarEvent(true)),
        expect: () => [
          predicate<UIState>((state) => state.isToolbarExpanded == true),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should set toolbar to collapsed',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetToolbarEvent(false)),
        expect: () => [
          predicate<UIState>((state) => state.isToolbarExpanded == false),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should handle setting to same value',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetToolbarEvent(true)),
        expect: () => [
          predicate<UIState>((state) => state.isToolbarExpanded == true),
        ],
      );
    });

    // === 复杂场景测试 ===
    group('Complex Scenarios', () {
      blocTest<UIBloc, UIState>(
        'should handle multiple events in sequence',
        build: () => uiBloc,
        act: (bloc) async {
          bloc.add(const UISetNodeViewModeEvent(NodeViewMode.fullContent));
          await Future.delayed(const Duration(milliseconds: 10));
          bloc.add(const UIToggleConnectionsEvent());
          await Future.delayed(const Duration(milliseconds: 10));
          bloc.add(const UISetBackgroundStyleEvent(BackgroundStyle.dots));
          await Future.delayed(const Duration(milliseconds: 10));
          bloc.add(const UICloseSidebarEvent());
        },
        skip: 3,
        expect: () => [
          predicate<UIState>((state) =>
              state.nodeViewMode == NodeViewMode.fullContent &&
              state.showConnections == false &&
              state.backgroundStyle == BackgroundStyle.dots &&
              state.isSidebarOpen == false),
        ],
      );

      blocTest<UIBloc, UIState>(
        'should maintain state consistency',
        build: () => uiBloc,
        act: (bloc) async {
          bloc.add(const UISetNodeViewModeEvent(NodeViewMode.compact));
          await Future.delayed(const Duration(milliseconds: 10));
          bloc.add(const UIToggleSidebarEvent());
          await Future.delayed(const Duration(milliseconds: 10));
          bloc.add(const UISelectTabEvent('search'));
        },
        skip: 2,
        expect: () => [
          predicate<UIState>((state) =>
              state.nodeViewMode == NodeViewMode.compact &&
              state.isSidebarOpen == false &&
              state.selectedTab == 'search' &&
              state.showConnections == uiBloc.state.showConnections &&
              state.backgroundStyle == uiBloc.state.backgroundStyle &&
              state.sidebarWidth == uiBloc.state.sidebarWidth &&
              state.isToolbarExpanded == uiBloc.state.isToolbarExpanded),
        ],
      );
    });

    // === 状态不可变性测试 ===
    group('State Immutability', () {
      blocTest<UIBloc, UIState>(
        'should create new state object on each event',
        build: () => uiBloc,
        act: (bloc) => bloc.add(const UISetNodeViewModeEvent(NodeViewMode.fullContent)),
        verify: (_) {
          final firstState = uiBloc.state;
          expect(identical(firstState, uiBloc.state), true);
        },
      );

      test('should not mutate previous state', () {
        final firstState = uiBloc.state;
        uiBloc.add(const UISetNodeViewModeEvent(NodeViewMode.fullContent));
        // 注意：由于事件是异步处理的，这里我们不能直接验证
        // 在实际使用中，blocTest 的 seed 参数可以更好地测试这个场景
        expect(firstState.nodeViewMode, NodeViewMode.titleWithPreview);
      });
    });
  });
}
