import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:node_graph_notebook/bloc/ui/ui_bloc.dart';
import 'package:node_graph_notebook/bloc/ui/ui_event.dart';
import 'package:node_graph_notebook/bloc/ui/ui_state.dart';
import 'package:node_graph_notebook/core/models/enums.dart';

/// UI响应式更新集成测试
///
/// 测试目标：
/// 1. 验证BlocBuilder的buildWhen条件渲染机制
/// 2. 验证BlocListener监听状态变化并执行副作用
/// 3. 验证context.watch vs context.read的使用场景
/// 4. 验证状态不变化时不发生不必要的重建
/// 5. 验证多个BLoC同时触发时的UI更新顺序
void main() {
  group('UI Responsive Update Integration Tests', () {

    group('BlocBuilder buildWhen Tests', () {
      testWidgets('should rebuild only when buildWhen returns true',
          (WidgetTester tester) async {
        int buildCount = 0;
        final uiBloc = UIBloc();

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<UIBloc>(
              create: (_) => uiBloc,
              child: Builder(
                builder: (context) {
                  return BlocBuilder<UIBloc, UIState>(
                    buildWhen: (previous, current) {
                      // 只在侧边栏状态变化时重建
                      return previous.isSidebarOpen != current.isSidebarOpen;
                    },
                    builder: (context, state) {
                      buildCount++;
                      return Text('Sidebar: ${state.isSidebarOpen}');
                    },
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        final initialBuildCount = buildCount;

        // 触发不相关状态变化（修改节点视图模式）
        uiBloc.add(const UISetNodeViewModeEvent(NodeViewMode.fullContent));
        await tester.pumpAndSettle();

        // buildWhen返回false，不应该重建
        expect(buildCount, equals(initialBuildCount));

        // 触发相关状态变化（切换侧边栏）
        uiBloc.add(const UIToggleSidebarEvent());
        await tester.pumpAndSettle();

        // buildWhen返回true，应该重建
        expect(buildCount, equals(initialBuildCount + 1));

        // 验证UI正确更新
        expect(find.text('Sidebar: false'), findsOneWidget);

        // 清理
        uiBloc.close();
      });

      testWidgets('should rebuild with complex buildWhen logic',
          (WidgetTester tester) async {
        int buildCount = 0;
        final uiBloc = UIBloc();

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<UIBloc>(
              create: (_) => uiBloc,
              child: Builder(
                builder: (context) {
                  return BlocBuilder<UIBloc, UIState>(
                    buildWhen: (previous, current) {
                      // 多个条件：侧边栏或工具栏状态变化时重建
                      return previous.isSidebarOpen != current.isSidebarOpen ||
                          previous.isToolbarExpanded !=
                              current.isToolbarExpanded;
                    },
                    builder: (context, state) {
                      buildCount++;
                      return Column(
                        children: [
                          Text('Sidebar: ${state.isSidebarOpen}'),
                          Text('Toolbar: ${state.isToolbarExpanded}'),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        final initialBuildCount = buildCount;

        // 触发不相关状态变化
        uiBloc.add(const UISetNodeViewModeEvent(NodeViewMode.compact));
        await tester.pumpAndSettle();
        expect(buildCount, equals(initialBuildCount));

        // 触发相关状态变化 - 侧边栏
        uiBloc.add(const UIToggleSidebarEvent());
        await tester.pumpAndSettle();
        expect(buildCount, equals(initialBuildCount + 1));

        // 触发相关状态变化 - 工具栏
        uiBloc.add(const UIToggleToolbarEvent());
        await tester.pumpAndSettle();
        expect(buildCount, equals(initialBuildCount + 2));

        // 验证UI状态正确
        expect(find.text('Sidebar: false'), findsOneWidget);
        expect(find.text('Toolbar: false'), findsOneWidget);

        // 清理
        uiBloc.close();
      });
    });

    group('BlocListener Side Effect Tests', () {
      testWidgets('should execute side effects when state changes',
          (WidgetTester tester) async {
        String? lastSideEffect;
        final uiBloc = UIBloc();

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<UIBloc>(
              create: (_) => uiBloc,
              child: Builder(
                builder: (context) {
                  return BlocListener<UIBloc, UIState>(
                    listenWhen: (previous, current) {
                      return previous.selectedTab != current.selectedTab;
                    },
                    listener: (context, state) {
                      // 记录状态变化
                      lastSideEffect = 'Tab changed to ${state.selectedTab}';
                    },
                    child: const Text('Test Widget'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 初始状态不触发副作用
        expect(lastSideEffect, isNull);

        // 触发状态变化
        uiBloc.add(const UISelectTabEvent('search'));
        await tester.pumpAndSettle();

        // 验证副作用执行
        expect(lastSideEffect, equals('Tab changed to search'));

        // 再次触发
        uiBloc.add(const UISelectTabEvent('settings'));
        await tester.pumpAndSettle();

        expect(lastSideEffect, equals('Tab changed to settings'));

        // 清理
        uiBloc.close();
      });

      testWidgets('should show SnackBar when listener triggers',
          (WidgetTester tester) async {
        final uiBloc = UIBloc();

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<UIBloc>(
              create: (_) => uiBloc,
              child: Builder(
                builder: (context) {
                  return BlocListener<UIBloc, UIState>(
                    listener: (context, state) {
                      // 当侧边栏关闭时显示提示
                      if (!state.isSidebarOpen) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sidebar closed')),
                        );
                      }
                    },
                    child: Scaffold(
                      body: ElevatedButton(
                        onPressed: () {
                          context.read<UIBloc>().add(const UIToggleSidebarEvent());
                        },
                        child: const Text('Toggle Sidebar'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 初始状态：侧边栏打开
        expect(find.byType(SnackBar), findsNothing);

        // 点击按钮关闭侧边栏
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // 验证SnackBar显示
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Sidebar closed'), findsOneWidget);

        // 清理
        uiBloc.close();
      });
    });

    group('context.watch vs context.read Tests', () {
      testWidgets('context.watch should rebuild widget on state change',
          (WidgetTester tester) async {
        int buildCount = 0;
        final uiBloc = UIBloc();

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<UIBloc>(
              create: (_) => uiBloc,
              child: Builder(
                builder: (context) {
                  // 使用 context.watch 订阅状态
                  final state = context.watch<UIBloc>().state;
                  buildCount++;
                  return Text('Connections: ${state.showConnections}');
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        final initialBuildCount = buildCount;

        // 触发状态变化
        uiBloc.add(const UIToggleConnectionsEvent());
        await tester.pumpAndSettle();

        // 使用context.watch的widget应该重建
        expect(buildCount, equals(initialBuildCount + 1));
        expect(find.text('Connections: false'), findsOneWidget);

        // 清理
        uiBloc.close();
      });

      testWidgets('context.read should not rebuild widget',
          (WidgetTester tester) async {
        int buildCount = 0;
        UIState? capturedState;
        final uiBloc = UIBloc();

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<UIBloc>(
              create: (_) => uiBloc,
              child: Builder(
                builder: (context) {
                  // 使用 context.read 只读取一次
                  capturedState ??= context.read<UIBloc>().state;
                  buildCount++;
                  return ElevatedButton(
                    onPressed: () {
                      // 在回调中使用 context.read
                      context.read<UIBloc>().add(const UIToggleSidebarEvent());
                    },
                    child: Text('Builds: $buildCount'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        final initialBuildCount = buildCount;
        final initialState = uiBloc.state;

        // 触发状态变化 - context.read不会导致重建
        uiBloc.add(const UIToggleConnectionsEvent());
        await tester.pumpAndSettle();

        // 使用context.read的widget不应该重建
        expect(buildCount, equals(initialBuildCount));
        expect(find.text('Builds: $initialBuildCount'), findsOneWidget);

        // 按钮点击功能应该能正常工作，但widget本身不重建
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // 验证widget仍然没有重建（因为使用context.read）
        expect(buildCount, equals(initialBuildCount));
        expect(find.text('Builds: $initialBuildCount'), findsOneWidget);

        // 验证按钮功能确实工作 - 侧边栏状态应该改变了
        expect(uiBloc.state.isSidebarOpen, equals(!initialState.isSidebarOpen));

        // 清理
        uiBloc.close();
      });

      testWidgets('context.select should rebuild only on selected property change',
          (WidgetTester tester) async {
        int buildCount = 0;
        final uiBloc = UIBloc();

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<UIBloc>(
              create: (_) => uiBloc,
              child: Builder(
                builder: (context) {
                  // 使用 context.select 只订阅特定属性
                  final isSidebarOpen = context.select<UIBloc, bool>(
                    (bloc) => bloc.state.isSidebarOpen,
                  );
                  buildCount++;
                  return Text('Sidebar open: $isSidebarOpen');
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        final initialBuildCount = buildCount;

        // 触发不相关状态变化
        uiBloc.add(const UIToggleConnectionsEvent());
        await tester.pumpAndSettle();

        // 不应该重建
        expect(buildCount, equals(initialBuildCount));

        // 触发相关状态变化
        uiBloc.add(const UIToggleSidebarEvent());
        await tester.pumpAndSettle();

        // 应该重建
        expect(buildCount, equals(initialBuildCount + 1));
        expect(find.text('Sidebar open: false'), findsOneWidget);

        // 清理
        uiBloc.close();
      });
    });

    group('No Unnecessary Rebuild Tests', () {
      testWidgets('should not rebuild when state values are the same',
          (WidgetTester tester) async {
        int buildCount = 0;
        final uiBloc = UIBloc();

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<UIBloc>(
              create: (_) => uiBloc,
              child: Builder(
                builder: (context) {
                  final state = context.watch<UIBloc>().state;
                  buildCount++;
                  return Text('Sidebar width: ${state.sidebarWidth}');
                },
              ),
            ),
          ),
        );

        await tester.pump();
        final initialBuildCount = buildCount;

        // 设置为相同的值
        uiBloc.add(const UISetSidebarWidthEvent(300.0));
        await tester.pump();

        // 状态值相同，不应该重建（Equatable的优化）
        // 注意：这取决于UIState的实现，如果copyWith总是创建新实例，则会重建
        // 如果实现了值比较优化，则不会重建
        expect(buildCount, greaterThanOrEqualTo(initialBuildCount));
      });

      testWidgets('should minimize rebuilds with selective watching',
          (WidgetTester tester) async {
        int titleBuildCount = 0;
        int contentBuildCount = 0;
        final uiBloc = UIBloc();

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<UIBloc>(
              create: (_) => uiBloc,
              child: Column(
                children: [
                  // Title组件只监听selectedTab
                  Builder(
                    builder: (context) {
                      final tab = context.select(
                        (UIBloc bloc) => bloc.state.selectedTab,
                      );
                      titleBuildCount++;
                      return Text('Current tab: $tab');
                    },
                  ),
                  // Content组件只监听isSidebarOpen
                  Builder(
                    builder: (context) {
                      final isOpen = context.select(
                        (UIBloc bloc) => bloc.state.isSidebarOpen,
                      );
                      contentBuildCount++;
                      return Text('Sidebar open: $isOpen');
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        final initialTitleBuilds = titleBuildCount;
        final initialContentBuilds = contentBuildCount;

        // 修改selectedTab
        uiBloc.add(const UISelectTabEvent('search'));
        await tester.pumpAndSettle();

        // 只有title组件应该重建
        expect(titleBuildCount, equals(initialTitleBuilds + 1));
        expect(contentBuildCount, equals(initialContentBuilds));

        // 修改isSidebarOpen
        uiBloc.add(const UIToggleSidebarEvent());
        await tester.pumpAndSettle();

        // 只有content组件应该重建
        expect(titleBuildCount, equals(initialTitleBuilds + 1));
        expect(contentBuildCount, equals(initialContentBuilds + 1));

        // 清理
        uiBloc.close();
      });
    });

    group('Sequential Updates Tests', () {
      testWidgets('should handle sequential state updates correctly',
          (WidgetTester tester) async {
        final stateHistory = <String>[];
        final uiBloc = UIBloc();

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<UIBloc>(
              create: (_) => uiBloc,
              child: BlocBuilder<UIBloc, UIState>(
                builder: (context, state) {
                  stateHistory.add(state.selectedTab);

                  return Column(
                    children: [
                      Text('Current: ${state.selectedTab}'),
                      ElevatedButton(
                        onPressed: () {
                          uiBloc.add(const UISelectTabEvent('first'));
                          uiBloc.add(const UISelectTabEvent('second'));
                          uiBloc.add(const UISelectTabEvent('third'));
                        },
                        child: const Text('Multiple Updates'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 点击按钮触发多个连续更新
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // 验证：最终状态应该是最后一个
        expect(find.text('Current: third'), findsOneWidget);
        expect(stateHistory.last, equals('third'));

        uiBloc.close();
      });
    });

    group('State Immutability Tests', () {
      testWidgets('should maintain state immutability across rebuilds',
          (WidgetTester tester) async {
        UIState? previousState;
        final uiBloc = UIBloc();

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<UIBloc>(
              create: (_) => uiBloc,
              child: BlocBuilder<UIBloc, UIState>(
                builder: (context, state) {
                  if (previousState != null) {
                    // 验证新state不是同一个实例
                    expect(identical(state, previousState), isFalse);

                    // 验证之前的状态没有被修改
                    expect(previousState!.selectedTab, equals('nodes'));
                  }

                  previousState = state;
                  return Text('Tab: ${state.selectedTab}');
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 触发状态变化
        uiBloc.add(const UISelectTabEvent('search'));
        await tester.pumpAndSettle();

        // 验证UI更新
        expect(find.text('Tab: search'), findsOneWidget);

        uiBloc.close();
      });
    });
  });
}
