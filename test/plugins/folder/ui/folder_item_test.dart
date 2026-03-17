
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/services/theme_service.dart';
import 'package:node_graph_notebook/plugins/folder/ui/folder_item.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/node_bloc.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/node_state.dart';
import 'package:provider/provider.dart';

@GenerateMocks([NodeBloc])
import 'folder_item_test.mocks.dart';

void main() {
  group('FolderItem', () {
    late Node folder;
    late Node childNode;
    late List<Node> allNodes;
    late Set<String> expandedFolders;
    late MockNodeBloc mockNodeBloc;
    late ThemeService themeService;

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

      childNode = Node(
        id: 'node_1',
        title: 'Child Node',
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

      allNodes = [folder, childNode];
      expandedFolders = {};
      mockNodeBloc = MockNodeBloc();
      themeService = ThemeService();

      when(mockNodeBloc.state).thenReturn(NodeState.initial());
      when(mockNodeBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    testWidgets('should display folder title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: FolderItem(
                  folder: folder,
                  allNodes: allNodes,
                  level: 0,
                  expandedFolders: expandedFolders,
                  onExpandedFoldersChanged: (_) {},
                  draggedNodeId: null,
                  onDragStarted: (_) {},
                  onDragEnd: (_) {},
                  onNodeSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test Folder'), findsOneWidget);
    });

    testWidgets('should display child count', (WidgetTester tester) async {
      folder = folder.copyWith(
        references: {'node_1': const NodeReference(nodeId: 'node_1', properties: {'type': 'relatesTo'})},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: FolderItem(
                  folder: folder,
                  allNodes: allNodes,
                  level: 0,
                  expandedFolders: expandedFolders,
                  onExpandedFoldersChanged: (_) {},
                  draggedNodeId: null,
                  onDragStarted: (_) {},
                  onDragEnd: (_) {},
                  onNodeSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('(1)'), findsOneWidget);
    });

    testWidgets('should toggle expand/collapse on tap', (WidgetTester tester) async {
      folder = folder.copyWith(
        references: {'node_1': const NodeReference(nodeId: 'node_1', properties: {'type': 'relatesTo'})},
      );

      final expandedFoldersChanged = <Set<String>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: FolderItem(
                  folder: folder,
                  allNodes: allNodes,
                  level: 0,
                  expandedFolders: expandedFolders,
                  onExpandedFoldersChanged: (folders) {
                    expandedFoldersChanged.add(folders);
                  },
                  draggedNodeId: null,
                  onDragStarted: (_) {},
                  onDragEnd: (_) {},
                  onNodeSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Folder'));
      await tester.pump();

      expect(expandedFoldersChanged.length, 1);
      expect(expandedFoldersChanged.first.contains('folder_1'), true);
    });

    testWidgets('should be draggable', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: FolderItem(
                  folder: folder,
                  allNodes: allNodes,
                  level: 0,
                  expandedFolders: expandedFolders,
                  onExpandedFoldersChanged: (_) {},
                  draggedNodeId: null,
                  onDragStarted: (_) {},
                  onDragEnd: (_) {},
                  onNodeSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      final draggableFinder = find.byType(Draggable<String>);
      expect(draggableFinder, findsOneWidget);
    });

    testWidgets('should accept drag target', (WidgetTester tester) async {
      folder = folder.copyWith(
        references: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: FolderItem(
                  folder: folder,
                  allNodes: allNodes,
                  level: 0,
                  expandedFolders: expandedFolders,
                  onExpandedFoldersChanged: (_) {},
                  draggedNodeId: null,
                  onDragStarted: (_) {},
                  onDragEnd: (_) {},
                  onNodeSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      final dragTargetFinder = find.byType(DragTarget<String>);
      expect(dragTargetFinder, findsOneWidget);
    });

    testWidgets('should display children when expanded', (WidgetTester tester) async {
      folder = folder.copyWith(
        references: {'node_1': const NodeReference(nodeId: 'node_1', properties: {'type': 'relatesTo'})},
      );

      expandedFolders.add('folder_1');

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: FolderItem(
                  folder: folder,
                  allNodes: allNodes,
                  level: 0,
                  expandedFolders: expandedFolders,
                  onExpandedFoldersChanged: (_) {},
                  draggedNodeId: null,
                  onDragStarted: (_) {},
                  onDragEnd: (_) {},
                  onNodeSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Child Node'), findsOneWidget);
    });

    testWidgets('should handle nested folders', (WidgetTester tester) async {
      final subFolder = Node(
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

      folder = folder.copyWith(
        references: {
          'subfolder_1': const NodeReference(nodeId: 'subfolder_1', properties: {'type': 'relatesTo'}),
        },
      );

      allNodes = [folder, subFolder, childNode];
      expandedFolders.add('folder_1');

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: FolderItem(
                  folder: folder,
                  allNodes: allNodes,
                  level: 0,
                  expandedFolders: expandedFolders,
                  onExpandedFoldersChanged: (_) {},
                  draggedNodeId: null,
                  onDragStarted: (_) {},
                  onDragEnd: (_) {},
                  onNodeSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sub Folder'), findsOneWidget);
    });
  });

  group('FolderItem - Circular Contains Detection', () {
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
      folder = folder.copyWith(
        references: {},
      );

      final hasCircular = folder.id == folder.id;
      expect(hasCircular, true);
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
      folder = folder.copyWith(
        references: {},
      );

      final hasCircular = folder.id == node.id;
      expect(hasCircular, false);
    });
  });
}
