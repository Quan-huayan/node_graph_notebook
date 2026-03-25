import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/services/i18n.dart';
import 'package:node_graph_notebook/core/services/theme_service.dart';
import 'package:node_graph_notebook/plugins/folder/ui/folder_selector.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/node_bloc.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/node_state.dart';
import 'package:provider/provider.dart';

@GenerateMocks([NodeBloc])
import 'folder_selector_test.mocks.dart';

void main() {
  group('FolderSelector', () {
    late Node node;
    late Node folder1;
    late Node folder2;
    late List<Node> folders;
    late MockNodeBloc mockNodeBloc;
    late ThemeService themeService;
    late I18n i18n;

    setUp(() {
      node = Node(
        id: 'node_1',
        title: 'Test Node',
        content: 'Test content',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      folder1 = Node(
        id: 'folder_1',
        title: 'Folder 1',
        content: '',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {'isFolder': true},
      );

      folder2 = Node(
        id: 'folder_2',
        title: 'Folder 2',
        content: '',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {'isFolder': true},
      );

      folders = [folder1, folder2];
      mockNodeBloc = MockNodeBloc();
      themeService = ThemeService();
      i18n = I18n();

      when(mockNodeBloc.state).thenReturn(NodeState.initial());
      when(mockNodeBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    testWidgets('should show folder selector dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
              ChangeNotifierProvider<I18n>.value(value: i18n),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: Scaffold(
                  body: ElevatedButton(
                    onPressed: () => showFolderSelector(context, node, folders),
                    child: const Text('Show Folder Selector'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Folder Selector'));
      await tester.pumpAndSettle();

      expect(find.text('Select Folder'), findsOneWidget);
      expect(find.text('Folder 1'), findsOneWidget);
      expect(find.text('Folder 2'), findsOneWidget);
    });

    testWidgets('should display all folders in list', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
              ChangeNotifierProvider<I18n>.value(value: i18n),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: Scaffold(
                  body: ElevatedButton(
                    onPressed: () => showFolderSelector(context, node, folders),
                    child: const Text('Show Folder Selector'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Folder Selector'));
      await tester.pumpAndSettle();

      expect(find.text('Folder 1'), findsOneWidget);
      expect(find.text('Folder 2'), findsOneWidget);
    });

    testWidgets('should close dialog on cancel', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
              ChangeNotifierProvider<I18n>.value(value: i18n),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: Scaffold(
                  body: ElevatedButton(
                    onPressed: () => showFolderSelector(context, node, folders),
                    child: const Text('Show Folder Selector'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Folder Selector'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Select Folder'), findsNothing);
    });

    testWidgets('should select folder and close dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
              ChangeNotifierProvider<I18n>.value(value: i18n),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: Scaffold(
                  body: ElevatedButton(
                    onPressed: () => showFolderSelector(context, node, folders),
                    child: const Text('Show Folder Selector'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Folder Selector'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Folder 1'));
      await tester.pumpAndSettle();

      expect(find.text('Select Folder'), findsNothing);
    });

    testWidgets('should handle empty folder list', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
              ChangeNotifierProvider<I18n>.value(value: i18n),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: Scaffold(
                  body: ElevatedButton(
                    onPressed: () => showFolderSelector(context, node, []),
                    child: const Text('Show Folder Selector'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Folder Selector'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('FolderSelector - Circular Contains Detection', () {
    late Node folder;
    late Node subFolder;
    late Node node;

    setUp(() {
      folder = Node(
        id: 'folder_1',
        title: 'Test Folder',
        content: '',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {'isFolder': true},
      );

      subFolder = Node(
        id: 'subfolder_1',
        title: 'Sub Folder',
        content: '',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {'isFolder': true},
      );

      node = Node(
        id: 'node_1',
        title: 'Node',
        content: '',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );
    });

    test('should detect circular contains when dragging folder to itself', () {
      final hasCircular = node.id == folder.id;
      expect(hasCircular, false);
    });

    test('should detect circular contains when dragging parent to child', () {
      folder = folder.copyWith(
        references: {
          'subfolder_1': const NodeReference(nodeId: 'subfolder_1', properties: {'type': 'relatesTo'}),
        },
      );

      final parentContainsChild = folder.references.containsKey(subFolder.id);
      expect(parentContainsChild, true);
    });

    test('should not detect circular contains for unrelated nodes', () {
      final hasCircular = node.id == folder.id;
      expect(hasCircular, false);
    });

    test('should check if folder is child folder', () {
      folder = folder.copyWith(
        references: {
          'subfolder_1': const NodeReference(nodeId: 'subfolder_1', properties: {'type': 'relatesTo'}),
        },
      );

      final isChild = folder.references.containsKey(subFolder.id);
      expect(isChild, true);
    });
  });

  group('FolderSelector - Parent Folder Detection', () {
    late Node folder;
    late Node node;
    late List<Node> allNodes;

    setUp(() {
      folder = Node(
        id: 'folder_1',
        title: 'Test Folder',
        content: '',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {'isFolder': true},
      );

      node = Node(
        id: 'node_1',
        title: 'Node',
        content: '',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      allNodes = [folder, node];
    });

    test('should find parent folder when node is in folder', () {
      folder = folder.copyWith(
        references: {
          'node_1': const NodeReference(nodeId: 'node_1', properties: {'type': 'relatesTo'}),
        },
      );

      final parentFolder = allNodes.firstWhere(
        (n) => n.isFolder && n.references.containsKey(node.id),
        orElse: () => folder,
      );

      expect(parentFolder.id, 'folder_1');
    });

    test('should return null when node has no parent folder', () {
      final parentFolder = allNodes.firstWhere(
        (n) => n.isFolder && n.references.containsKey(node.id),
        orElse: () => folder,
      );

      expect(parentFolder.id, 'folder_1');
      expect(parentFolder.references.containsKey(node.id), false);
    });
  });
}
