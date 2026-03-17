import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/ui/bloc/ui_bloc.dart';
import 'package:node_graph_notebook/ui/bloc/ui_event.dart';
import 'package:node_graph_notebook/ui/bloc/ui_state.dart';

void main() {
  group('UIBloc', () {
    late UIBloc uiBloc;

    setUp(() {
      uiBloc = UIBloc();
    });

    tearDown(() {
      uiBloc.close();
    });

    test('initial state is correct', () {
      expect(uiBloc.state.nodeViewMode, NodeViewMode.titleWithPreview);
      expect(uiBloc.state.showConnections, true);
      expect(uiBloc.state.backgroundStyle, BackgroundStyle.grid);
      expect(uiBloc.state.isSidebarOpen, true);
      expect(uiBloc.state.selectedTab, 'nodes');
      expect(uiBloc.state.sidebarWidth, 300);
      expect(uiBloc.state.isToolbarExpanded, true);
    });

    blocTest<UIBloc, UIState>(
      'should emit updated nodeViewMode when UISetNodeViewModeEvent is added',
      build: () => uiBloc,
      act: (bloc) => bloc.add(const UISetNodeViewModeEvent(NodeViewMode.fullContent)),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.fullContent,
          showConnections: true,
          backgroundStyle: BackgroundStyle.grid,
          isSidebarOpen: true,
          selectedTab: 'nodes',
          sidebarWidth: 300,
          isToolbarExpanded: true,
        ),
      ],
    );

    blocTest<UIBloc, UIState>(
      'should emit updated nodeViewMode when UISetDefaultViewModeEvent is added',
      build: () => uiBloc,
      act: (bloc) => bloc.add(const UISetDefaultViewModeEvent(NodeViewMode.compact)),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.compact,
          showConnections: true,
          backgroundStyle: BackgroundStyle.grid,
          isSidebarOpen: true,
          selectedTab: 'nodes',
          sidebarWidth: 300,
          isToolbarExpanded: true,
        ),
      ],
    );

    blocTest<UIBloc, UIState>(
      'should toggle showConnections when UIToggleConnectionsEvent is added',
      build: () => uiBloc,
      act: (bloc) => bloc.add(const UIToggleConnectionsEvent()),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.titleWithPreview,
          showConnections: false,
          backgroundStyle: BackgroundStyle.grid,
          isSidebarOpen: true,
          selectedTab: 'nodes',
          sidebarWidth: 300,
          isToolbarExpanded: true,
        ),
      ],
    );

    blocTest<UIBloc, UIState>(
      'should emit updated showConnections when UISetConnectionsEvent is added',
      build: () => uiBloc,
      act: (bloc) => bloc.add(const UISetConnectionsEvent(false)),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.titleWithPreview,
          showConnections: false,
          backgroundStyle: BackgroundStyle.grid,
          isSidebarOpen: true,
          selectedTab: 'nodes',
          sidebarWidth: 300,
          isToolbarExpanded: true,
        ),
      ],
    );

    blocTest<UIBloc, UIState>(
      'should emit updated backgroundStyle when UISetBackgroundStyleEvent is added',
      build: () => uiBloc,
      act: (bloc) => bloc.add(const UISetBackgroundStyleEvent(BackgroundStyle.none)),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.titleWithPreview,
          showConnections: true,
          backgroundStyle: BackgroundStyle.none,
          isSidebarOpen: true,
          selectedTab: 'nodes',
          sidebarWidth: 300,
          isToolbarExpanded: true,
        ),
      ],
    );

    blocTest<UIBloc, UIState>(
      'should toggle isSidebarOpen when UIToggleSidebarEvent is added',
      build: () => uiBloc,
      act: (bloc) => bloc.add(const UIToggleSidebarEvent()),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.titleWithPreview,
          showConnections: true,
          backgroundStyle: BackgroundStyle.grid,
          isSidebarOpen: false,
          selectedTab: 'nodes',
          sidebarWidth: 300,
          isToolbarExpanded: true,
        ),
      ],
    );

    blocTest<UIBloc, UIState>(
      'should emit updated isSidebarOpen when UISetSidebarEvent is added',
      build: () => uiBloc,
      act: (bloc) => bloc.add(const UISetSidebarEvent(false)),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.titleWithPreview,
          showConnections: true,
          backgroundStyle: BackgroundStyle.grid,
          isSidebarOpen: false,
          selectedTab: 'nodes',
          sidebarWidth: 300,
          isToolbarExpanded: true,
        ),
      ],
    );

    blocTest<UIBloc, UIState>(
      'should set isSidebarOpen to true when UIOpenSidebarEvent is added',
      build: () => uiBloc,
      seed: () => const UIState(
        nodeViewMode: NodeViewMode.titleWithPreview,
        showConnections: true,
        backgroundStyle: BackgroundStyle.grid,
        isSidebarOpen: false,
        selectedTab: 'nodes',
        sidebarWidth: 300,
        isToolbarExpanded: true,
      ),
      act: (bloc) => bloc.add(const UIOpenSidebarEvent()),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.titleWithPreview,
          showConnections: true,
          backgroundStyle: BackgroundStyle.grid,
          isSidebarOpen: true,
          selectedTab: 'nodes',
          sidebarWidth: 300,
          isToolbarExpanded: true,
        ),
      ],
    );

    blocTest<UIBloc, UIState>(
      'should set isSidebarOpen to false when UICloseSidebarEvent is added',
      build: () => uiBloc,
      act: (bloc) => bloc.add(const UICloseSidebarEvent()),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.titleWithPreview,
          showConnections: true,
          backgroundStyle: BackgroundStyle.grid,
          isSidebarOpen: false,
          selectedTab: 'nodes',
          sidebarWidth: 300,
          isToolbarExpanded: true,
        ),
      ],
    );

    blocTest<UIBloc, UIState>(
      'should emit updated selectedTab when UISelectTabEvent is added',
      build: () => uiBloc,
      act: (bloc) => bloc.add(const UISelectTabEvent('plugins')),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.titleWithPreview,
          showConnections: true,
          backgroundStyle: BackgroundStyle.grid,
          isSidebarOpen: true,
          selectedTab: 'plugins',
          sidebarWidth: 300,
          isToolbarExpanded: true,
        ),
      ],
    );

    blocTest<UIBloc, UIState>(
      'should clamp sidebarWidth to minimum when UISetSidebarWidthEvent is added with value below 150',
      build: () => uiBloc,
      act: (bloc) => bloc.add(const UISetSidebarWidthEvent(100)),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.titleWithPreview,
          showConnections: true,
          backgroundStyle: BackgroundStyle.grid,
          isSidebarOpen: true,
          selectedTab: 'nodes',
          sidebarWidth: 150,
          isToolbarExpanded: true,
        ),
      ],
    );

    blocTest<UIBloc, UIState>(
      'should clamp sidebarWidth to maximum when UISetSidebarWidthEvent is added with value above 500',
      build: () => uiBloc,
      act: (bloc) => bloc.add(const UISetSidebarWidthEvent(600)),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.titleWithPreview,
          showConnections: true,
          backgroundStyle: BackgroundStyle.grid,
          isSidebarOpen: true,
          selectedTab: 'nodes',
          sidebarWidth: 500,
          isToolbarExpanded: true,
        ),
      ],
    );

    blocTest<UIBloc, UIState>(
      'should emit updated sidebarWidth when UISetSidebarWidthEvent is added with valid value',
      build: () => uiBloc,
      act: (bloc) => bloc.add(const UISetSidebarWidthEvent(400)),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.titleWithPreview,
          showConnections: true,
          backgroundStyle: BackgroundStyle.grid,
          isSidebarOpen: true,
          selectedTab: 'nodes',
          sidebarWidth: 400,
          isToolbarExpanded: true,
        ),
      ],
    );

    blocTest<UIBloc, UIState>(
      'should toggle isToolbarExpanded when UIToggleToolbarEvent is added',
      build: () => uiBloc,
      act: (bloc) => bloc.add(const UIToggleToolbarEvent()),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.titleWithPreview,
          showConnections: true,
          backgroundStyle: BackgroundStyle.grid,
          isSidebarOpen: true,
          selectedTab: 'nodes',
          sidebarWidth: 300,
          isToolbarExpanded: false,
        ),
      ],
    );

    blocTest<UIBloc, UIState>(
      'should emit updated isToolbarExpanded when UISetToolbarEvent is added',
      build: () => uiBloc,
      act: (bloc) => bloc.add(const UISetToolbarEvent(false)),
      expect: () => [
        const UIState(
          nodeViewMode: NodeViewMode.titleWithPreview,
          showConnections: true,
          backgroundStyle: BackgroundStyle.grid,
          isSidebarOpen: true,
          selectedTab: 'nodes',
          sidebarWidth: 300,
          isToolbarExpanded: false,
        ),
      ],
    );
  });
}
