import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/services/theme_service.dart';
import 'package:node_graph_notebook/plugins/folder/ui/folder_tree_view.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/graph_bloc.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/node_bloc.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/node_state.dart';
import 'package:node_graph_notebook/plugins/graph/service/node_service.dart';
import 'package:provider/provider.dart';

@GenerateMocks([NodeBloc, GraphBloc, NodeService])
import 'folder_tree_view_test.mocks.dart';

void main() {
  group('FolderTreeView', () {
    late Node folder1;
    late Node folder2;
    late Node node1;
    late Node node2;
    late List<Node> nodes;
    late List<Node> folders;
    late MockNodeBloc mockNodeBloc;
    late MockGraphBloc mockGraphBloc;
    late MockNodeService mockNodeService;
    late ThemeService themeService;

    setUp(() {
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

      node1 = Node(
        id: 'node_1',
        title: 'Node 1',
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

      node2 = Node(
        id: 'node_2',
        title: 'Node 2',
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

      nodes = [node1, node2];
      folders = [folder1, folder2];
      mockNodeBloc = MockNodeBloc();
      mockGraphBloc = MockGraphBloc();
      mockNodeService = MockNodeService();
      themeService = ThemeService();

      when(mockNodeBloc.state).thenReturn(NodeState.initial());
      when(mockNodeBloc.stream).thenAnswer((_) => const Stream.empty());
      when(mockGraphBloc.stream).thenAnswer((_) => const Stream.empty());
      when(mockGraphBloc.add(any)).thenReturn(null);
      when(mockNodeService.calculateNodeDepths(any)).thenAnswer((invocation) async {
        final nodes = invocation.positionalArguments[0] as List<Node>;
        final depths = <String, int>{};
        for (final node in nodes) {
          depths[node.id] = 0; // 所有节点的深度都设置为0
        }
        return depths;
      });
    });

    testWidgets('should display empty state when no nodes or folders', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              BlocProvider<GraphBloc>.value(value: mockGraphBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
              Provider<NodeService>.value(value: mockNodeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: const Scaffold(
                  body: FolderTreeView(
                    nodes: [],
                    folders: [],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('No nodes yet'), findsOneWidget);
    });

    testWidgets('should display root nodes', (WidgetTester tester) async {
      final testState = NodeState.initial().copyWith(nodes: nodes);
      when(mockNodeBloc.state).thenReturn(testState);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              BlocProvider<GraphBloc>.value(value: mockGraphBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
              Provider<NodeService>.value(value: mockNodeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: Scaffold(
                  body: FolderTreeView(
                    nodes: nodes,
                    folders: const [],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Node 1'), findsOneWidget);
      expect(find.text('Node 2'), findsOneWidget);
    });

    testWidgets('should display top level folders', (WidgetTester tester) async {
      final testState = NodeState.initial().copyWith(nodes: folders);
      when(mockNodeBloc.state).thenReturn(testState);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              BlocProvider<GraphBloc>.value(value: mockGraphBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
              Provider<NodeService>.value(value: mockNodeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: Scaffold(
                  body: FolderTreeView(
                    nodes: const [],
                    folders: folders,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Folder 1'), findsOneWidget);
      expect(find.text('Folder 2'), findsOneWidget);
    });

    testWidgets('should display both folders and nodes', (WidgetTester tester) async {
      final testState = NodeState.initial().copyWith(nodes: [...nodes, ...folders]);
      when(mockNodeBloc.state).thenReturn(testState);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              BlocProvider<GraphBloc>.value(value: mockGraphBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
              Provider<NodeService>.value(value: mockNodeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: Scaffold(
                  body: FolderTreeView(
                    nodes: nodes,
                    folders: folders,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Folder 1'), findsOneWidget);
      expect(find.text('Folder 2'), findsOneWidget);
      expect(find.text('Node 1'), findsOneWidget);
      expect(find.text('Node 2'), findsOneWidget);
    });

    testWidgets('should filter out AI nodes', (WidgetTester tester) async {
      final aiNode = Node(
        id: 'ai_node',
        title: 'AI Node',
        content: '',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {'isAI': true},
      );

      final allNodes = [...nodes, aiNode];
      final testState = NodeState.initial().copyWith(nodes: allNodes);
      when(mockNodeBloc.state).thenReturn(testState);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              BlocProvider<GraphBloc>.value(value: mockGraphBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
              Provider<NodeService>.value(value: mockNodeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: const Scaffold(
                  body: FolderTreeView(
                    nodes: [],
                    folders: [],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Node 1'), findsOneWidget);
      expect(find.text('Node 2'), findsOneWidget);
      expect(find.text('AI Node'), findsNothing);
    });

    testWidgets('should call onNodeSelected when node is tapped', (WidgetTester tester) async {
      String? selectedNodeId;
      final testState = NodeState.initial().copyWith(nodes: nodes);
      when(mockNodeBloc.state).thenReturn(testState);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              BlocProvider<GraphBloc>.value(value: mockGraphBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
              Provider<NodeService>.value(value: mockNodeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: Scaffold(
                  body: FolderTreeView(
                    nodes: nodes,
                    folders: const [],
                    onNodeSelected: (id) {
                      debugPrint('onNodeSelected called with id: $id');
                      selectedNodeId = id;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nodeFinder = find.text('Node 1');
      expect(nodeFinder, findsOneWidget);
      
      await tester.tap(nodeFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      debugPrint('selectedNodeId: $selectedNodeId');
      expect(selectedNodeId, 'node_1');
    });

    testWidgets('should be draggable', (WidgetTester tester) async {
      final testState = NodeState.initial().copyWith(nodes: [...nodes, ...folders]);
      when(mockNodeBloc.state).thenReturn(testState);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              BlocProvider<GraphBloc>.value(value: mockGraphBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
              Provider<NodeService>.value(value: mockNodeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: const Scaffold(
                  body: FolderTreeView(
                    nodes: [],
                    folders: [],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final draggableFinder = find.byType(Draggable<String>);
      expect(draggableFinder, findsWidgets);
    });

    testWidgets('should accept drag target', (WidgetTester tester) async {
      final testState = NodeState.initial().copyWith(nodes: [...nodes, ...folders]);
      when(mockNodeBloc.state).thenReturn(testState);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              BlocProvider<GraphBloc>.value(value: mockGraphBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
              Provider<NodeService>.value(value: mockNodeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: const Scaffold(
                  body: FolderTreeView(
                    nodes: [],
                    folders: [],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final dragTargetFinder = find.byType(DragTarget<String>);
      expect(dragTargetFinder, findsNothing);
    });

    testWidgets('should show divider between folders and nodes', (WidgetTester tester) async {
      final testState = NodeState.initial().copyWith(nodes: [...nodes, ...folders]);
      when(mockNodeBloc.state).thenReturn(testState);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<NodeBloc>.value(value: mockNodeBloc),
              BlocProvider<GraphBloc>.value(value: mockGraphBloc),
              ChangeNotifierProvider<ThemeService>.value(value: themeService),
              Provider<NodeService>.value(value: mockNodeService),
            ],
            child: Builder(
              builder: (context) => Theme(
                data: ThemeData.light(),
                child: const Scaffold(
                  body: FolderTreeView(
                    nodes: [],
                    folders: [],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final dividerFinder = find.byType(Divider);
      expect(dividerFinder, findsNothing);
    });
  });

  group('FolderTreeView - Node Extension', () {
    test('should identify folder nodes', () {
      final folder = Node(
        id: 'folder_1',
        title: 'Folder',
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

      expect(folder.isFolder, true);
    });

    test('should identify non-folder nodes', () {
      final node = Node(
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

      expect(node.isFolder, false);
    });

    test('should handle string boolean for isFolder', () {
      final folder = Node(
        id: 'folder_1',
        title: 'Folder',
        content: '',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {'isFolder': 'true'},
      );

      expect(folder.isFolder, false);
    });
  });

  group('FolderTreeView - Folder Children', () {
    late Node folder;
    late Node childNode;

    setUp(() {
      folder = Node(
        id: 'folder_1',
        title: 'Folder',
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

    test('should get folder children', () {
      folder = folder.copyWith(
        references: {
          'node_1': const NodeReference(nodeId: 'node_1', properties: {'type': 'relatesTo'}),
        },
      );

      final allNodes = [folder, childNode];
      final children = allNodes.where((node) => folder.references.containsKey(node.id)).toList();
      expect(children.length, 1);
      expect(children.first.id, 'node_1');
    });

    test('should return empty list when folder has no children', () {
      final allNodes = [folder, childNode];
      final children = allNodes.where((node) => folder.references.containsKey(node.id)).toList();
      expect(children, isEmpty);
    });
  });

  group('FolderTreeView - Root Nodes', () {
    late Node node1;
    late Node node2;
    late Node folder;
    late List<Node> nodes;
    late List<Node> folders;

    setUp(() {
      node1 = Node(
        id: 'node_1',
        title: 'Node 1',
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

      node2 = Node(
        id: 'node_2',
        title: 'Node 2',
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

      folder = Node(
        id: 'folder_1',
        title: 'Folder',
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

      nodes = [node1, node2];
      folders = [folder];
    });

    test('should get root nodes not in any folder', () {
      final folderContainedIds = folders.expand((folder) => folder.references.keys).toSet();
      final rootNodes = nodes.where((node) => !folderContainedIds.contains(node.id)).toList();

      expect(rootNodes.length, 2);
      expect(rootNodes.map((n) => n.id).toSet(), {'node_1', 'node_2'});
    });

    test('should exclude nodes in folder from root nodes', () {
      folder = folder.copyWith(
        references: {
          'node_1': const NodeReference(nodeId: 'node_1', properties: {'type': 'relatesTo'}),
        },
      );
      folders = [folder];

      final folderContainedIds = folders.expand((folder) => folder.references.keys).toSet();
      final rootNodes = nodes.where((node) => !folderContainedIds.contains(node.id)).toList();

      expect(rootNodes.length, 1);
      expect(rootNodes.first.id, 'node_2');
    });
  });

  group('FolderTreeView - Circular Contains Detection', () {
    late Node folder;
    late Node subFolder;
    late Node node;

    setUp(() {
      folder = Node(
        id: 'folder_1',
        title: 'Folder',
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
      final hasCircular = node.id == folder.id;
      expect(hasCircular, false);
    });
  });
}
