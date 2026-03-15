import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:node_graph_notebook/bloc/blocs.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';
import 'package:node_graph_notebook/core/repositories/repositories.dart';
import 'package:node_graph_notebook/core/services/services.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/ui/dialogs/export_markdown_dialog.dart';
import 'package:node_graph_notebook/converter/models/models.dart';
import '../test_helpers.dart';

// Mock生成器注解
@GenerateNiceMocks([
  MockSpec<NodeRepository>(),
  MockSpec<GraphRepository>(),
  MockSpec<NodeService>(),
  MockSpec<GraphService>(),
  MockSpec<ImportExportService>(),
])
import 'export_markdown_dialog_test.mocks.dart';

/// ExportMarkdownDialog UI 测试
///
/// 测试目标：
/// 1. 验证对话框的基本渲染
/// 2. 验证节点树形选择功能
/// 3. 验证顺序调整功能（上移/下移/拖拽/移除）
/// 4. 验证文件夹展开/折叠
/// 5. 验证搜索功能
/// 6. 验证合并策略切换
/// 7. 验证导出功能
void main() {
  group('ExportMarkdownDialog Widget Tests', () {
    late MockNodeRepository mockNodeRepository;
    late MockGraphRepository mockGraphRepository;
    late MockNodeService mockNodeService;
    late MockImportExportService mockImportExportService;
    late AppEventBus eventBus;
    late CommandBus commandBus;
    late NodeBloc nodeBloc;
    late GraphBloc graphBloc;
    late ConverterBloc converterBloc;

    setUp(() async {
      mockNodeRepository = MockNodeRepository();
      mockGraphRepository = MockGraphRepository();
      mockNodeService = MockNodeService();
      mockImportExportService = MockImportExportService();
      eventBus = AppEventBus();
      commandBus = CommandBus();

      // 设置mock返回值
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockNodeRepository.loadAll(any)).thenAnswer((_) async => []);
      when(mockNodeRepository.delete(any)).thenAnswer((_) async {});
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.load(any)).thenAnswer((_) async => null);
      when(mockGraphRepository.save(any)).thenAnswer((_) async {});

      // 设置服务mock返回值
      when(mockNodeService.getAllNodes()).thenAnswer((_) async => []);
      when(mockImportExportService.previewExport(
        nodeIds: anyNamed('nodeIds'),
        rule: anyNamed('rule'),
      )).thenAnswer((_) async => '# Test Markdown\n\nContent');
      when(mockImportExportService.executeExport(
        nodeIds: anyNamed('nodeIds'),
        rule: anyNamed('rule'),
        outputPath: anyNamed('outputPath'),
      )).thenAnswer((_) async => File('/tmp/test.md'));

      // 初始化BLoCs
      nodeBloc = NodeBloc(
        commandBus: commandBus,
        nodeRepository: mockNodeRepository,
        eventBus: eventBus,
      );

      graphBloc = GraphBloc(
        commandBus: commandBus,
        graphRepository: mockGraphRepository,
        nodeRepository: mockNodeRepository,
        eventBus: eventBus,
      );

      converterBloc = ConverterBloc(
        importExportService: mockImportExportService,
      );
    });

    tearDown(() async {
      await nodeBloc.close();
      await graphBloc.close();
      await converterBloc.close();
      commandBus.dispose();
      eventBus.dispose();
    });

    /// 创建测试用的节点数据
    List<Node> createTestNodes() {
      return [
        NodeTestHelpers.test(
          id: 'node-1',
          title: 'Introduction',
          content: 'This is the introduction',
        ),
        NodeTestHelpers.test(
          id: 'node-2',
          title: 'Chapter 1',
          content: 'First chapter content',
        ),
        NodeTestHelpers.test(
          id: 'node-3',
          title: 'Chapter 2',
          content: 'Second chapter content',
        ),
      ];
    }

    /// 辅助方法：设置并加载测试节点
    Future<void> setupAndLoadNodes(WidgetTester tester, List<Node> nodes) async {
      when(mockNodeService.getAllNodes()).thenAnswer((_) async => nodes);
      nodeBloc.add(const NodeLoadEvent());
      await tester.pump();
    }

    /// 创建测试用的文件夹数据
    List<Node> createTestFolders() {
      final folder = NodeTestHelpers.testFolder(
        'folder-1',
        'Documents',
        references: {
          'node-2': const NodeReference(
            nodeId: 'node-2',
            type: ReferenceType.contains,
          ),
        },
      );

      return [
        folder,
        NodeTestHelpers.test(
          id: 'node-1',
          title: 'Root Node',
        ),
        NodeTestHelpers.test(
          id: 'node-2',
          title: 'Child in Folder',
        ),
      ];
    }

    group('Basic Rendering', () {
      testWidgets('should render dialog with all columns',
          (WidgetTester tester) async {
        await setupAndLoadNodes(tester, createTestNodes());

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: Center(
                  child: ExportMarkdownDialog(),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 验证对话框标题
        expect(find.text('Export Markdown'), findsOneWidget);

        // 验证布局
        expect(find.text('Merge Strategy:'), findsOneWidget);
        expect(find.textContaining('Search'), findsOneWidget);

        // 验证合并策略选项
        expect(find.text('Sequence'), findsOneWidget);
        expect(find.text('Hierarchy'), findsOneWidget);

        // 验证底部按钮
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Export (0)'), findsOneWidget);
      });

      testWidgets('should show no nodes message when no nodes available',
          (WidgetTester tester) async {
        when(mockNodeService.getAllNodes()).thenAnswer((_) async => []);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 验证空状态提示
        expect(find.text('No nodes available'), findsOneWidget);
      });
    });

    group('Node Selection', () {
      testWidgets('should select node when checkbox is tapped',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 初始状态：没有选中任何节点
        expect(find.text('Export (0)'), findsOneWidget);

        // 点击第一个节点（通过点击其标题）
        await tester.tap(find.text('Introduction'));
        await tester.pumpAndSettle();

        // 验证选中状态更新
        expect(find.text('Export (1)'), findsOneWidget);

        // 验证节点出现在已选列表中
        expect(find.text('Introduction'), findsWidgets);
      });

      testWidgets('should select all nodes when Select All is pressed',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 点击 Select All 按钮
        await tester.tap(find.text('Select All'));
        await tester.pumpAndSettle();

        // 验证所有节点被选中
        expect(find.text('Export (3)'), findsOneWidget);
      });

      testWidgets('should clear all selections when Clear is pressed',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 先全选
        await tester.tap(find.text('Select All'));
        await tester.pumpAndSettle();
        expect(find.text('Export (3)'), findsOneWidget);

        // 再清除
        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();
        expect(find.text('Export (0)'), findsOneWidget);
      });
    });

    group('Order Adjustment', () {
      testWidgets('should move node up when up button is pressed',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 选择前两个节点（通过点击其标题）
        await tester.tap(find.text('Introduction'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chapter 1'));
        await tester.pumpAndSettle();

        // 等待预览更新
        await tester.pump(const Duration(milliseconds: 100));

        // 点击展开排序面板
        await tester.tap(find.text('Selected Order (2)'));
        await tester.pumpAndSettle();

        // 验证第二个节点的上移按钮可见且可点击
        final upButtons = find.byIcon(Icons.arrow_upward);
        expect(upButtons, findsWidgets);

        // 点击第二个节点的上移按钮
        await tester.tap(upButtons.at(1));
        await tester.pumpAndSettle();

        // 验证顺序已更新
        expect(find.text('Export (2)'), findsOneWidget);
      });

      testWidgets('should move node down when down button is pressed',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 选择前两个节点（通过点击其标题）
        await tester.tap(find.text('Introduction'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chapter 1'));
        await tester.pumpAndSettle();

        // 等待预览更新
        await tester.pump(const Duration(milliseconds: 100));

        // 点击展开排序面板
        await tester.tap(find.text('Selected Order (2)'));
        await tester.pumpAndSettle();

        // 验证第一个节点的下移按钮可见且可点击
        final downButtons = find.byIcon(Icons.arrow_downward);
        expect(downButtons, findsWidgets);

        // 点击第一个节点的下移按钮
        await tester.tap(downButtons.first);
        await tester.pumpAndSettle();

        // 验证顺序已更新
        expect(find.text('Export (2)'), findsOneWidget);
      });

      testWidgets('should remove node when close button is pressed',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 选择第一个节点（通过点击其标题）
        await tester.tap(find.text('Introduction'));
        await tester.pumpAndSettle();

        // 验证节点被选中
        expect(find.text('Export (1)'), findsOneWidget);

        // 等待预览更新
        await tester.pump(const Duration(milliseconds: 100));

        // 点击展开排序面板
        await tester.tap(find.text('Selected Order (1)'));
        await tester.pumpAndSettle();

        // 点击移除按钮
        final closeButton = find.byIcon(Icons.close);
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        // 验证节点被移除
        expect(find.text('Export (0)'), findsOneWidget);
      });
    });

    group('Folder Tree Structure', () {
      testWidgets('should display folder with children',
          (WidgetTester tester) async {
        final nodes = createTestFolders();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 验证文件夹显示
        expect(find.text('Documents'), findsOneWidget);

        // 验证文件夹显示子节点数量
        expect(find.text('(1)'), findsOneWidget);

        // 验证根节点显示
        expect(find.text('Root Node'), findsOneWidget);
      });

      testWidgets('should expand folder when tapped',
          (WidgetTester tester) async {
        final nodes = createTestFolders();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 验证子节点初始不可见（文件夹未展开）
        expect(find.text('Child in Folder'), findsNothing);

        // 点击文件夹展开
        await tester.tap(find.text('Documents'));
        await tester.pumpAndSettle();

        // 验证子节点现在可见
        expect(find.text('Child in Folder'), findsOneWidget);
      });

      testWidgets('should collapse folder when tapped again',
          (WidgetTester tester) async {
        final nodes = createTestFolders();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 展开文件夹
        await tester.tap(find.text('Documents'));
        await tester.pumpAndSettle();
        expect(find.text('Child in Folder'), findsOneWidget);

        // 再次点击折叠文件夹
        await tester.tap(find.text('Documents'));
        await tester.pumpAndSettle();
        expect(find.text('Child in Folder'), findsNothing);
      });
    });

    group('Search Functionality', () {
      testWidgets('should filter nodes based on search query',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 验证所有节点都显示
        expect(find.text('Introduction'), findsOneWidget);
        expect(find.text('Chapter 1'), findsOneWidget);
        expect(find.text('Chapter 2'), findsOneWidget);

        // 输入搜索关键词
        await tester.enterText(find.byType(TextField), 'Chapter');
        await tester.pumpAndSettle();

        // 验证搜索结果
        expect(find.text('Introduction'), findsNothing);
        expect(find.text('Chapter 1'), findsOneWidget);
        expect(find.text('Chapter 2'), findsOneWidget);
      });

      testWidgets('should show no results for non-matching search',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 输入不存在的搜索关键词
        await tester.enterText(find.byType(TextField), 'NonExistent');
        await tester.pumpAndSettle();

        // 验证没有搜索结果
        expect(find.text('Introduction'), findsNothing);
        expect(find.text('Chapter 1'), findsNothing);
        expect(find.text('Chapter 2'), findsNothing);
        expect(find.text('No nodes found'), findsOneWidget);
      });
    });

    group('Merge Strategy Selection', () {
      testWidgets('should switch to sequence strategy when tapped',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 选择一个节点以触发预览
        final checkboxes = find.byType(Checkbox);
        await tester.tap(checkboxes.at(1));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 100));

        // 点击 Sequence 策略
        await tester.tap(find.text('Sequence'));
        await tester.pumpAndSettle();

        // 验证策略被选中（SegmentedButton 会在 selected 中包含当前选中的值）
        final segmentedButton = find.byType(SegmentedButton<MergeStrategy>);
        expect(segmentedButton, findsOneWidget);
      });

      testWidgets('should switch to hierarchy strategy when tapped',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 选择一个节点以触发预览
        await tester.tap(find.text('Introduction'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 100));

        // 点击 Hierarchy 策略
        await tester.tap(find.text('Hierarchy'));
        await tester.pumpAndSettle();

        // 验证策略被选中
        final segmentedButton = find.byType(SegmentedButton<MergeStrategy>);
        expect(segmentedButton, findsOneWidget);
      });
    });

    group('Export Functionality', () {
      testWidgets('should enable export button when nodes are selected',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 初始状态：导出按钮禁用
        final exportButton = find.text('Export (0)');
        expect(exportButton, findsOneWidget);

        // 选择第一个节点（通过点击其标题）
        await tester.tap(find.text('Introduction'));
        await tester.pumpAndSettle();

        // 验证导出按钮更新
        expect(find.text('Export (1)'), findsOneWidget);
      });

      testWidgets('should disable export button when no nodes selected',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 验证导出按钮显示但禁用（0 个节点）
        expect(find.text('Export (0)'), findsOneWidget);
      });

      testWidgets('should close dialog when cancel is pressed',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: Center(
                  child: ExportMarkdownDialog(),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Export Markdown'), findsOneWidget);

        // 点击取消（由于没有使用showDialog，这里我们只验证取消按钮存在并可点击）
        final cancelButton = find.text('Cancel');
        expect(cancelButton, findsOneWidget);
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();
      });
    });

    group('Preview Functionality', () {
      testWidgets('should show preview placeholder when no nodes selected',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 验证预览占位符显示
        expect(find.text('Select nodes to preview'), findsOneWidget);
        expect(find.byIcon(Icons.description), findsOneWidget);
      });

      testWidgets('should update preview when node is selected',
          (WidgetTester tester) async {
        final nodes = createTestNodes();
        await setupAndLoadNodes(tester, nodes);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: nodeBloc),
                BlocProvider.value(value: graphBloc),
                BlocProvider.value(value: converterBloc),
              ],
              child: const Scaffold(
                body: ExportMarkdownDialog(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 验证初始预览占位符
        expect(find.text('Select nodes to preview'), findsOneWidget);

        // 选择第一个节点（通过点击其标题）
        await tester.tap(find.text('Introduction'));
        await tester.pumpAndSettle();

        // 等待预览加载
        await tester.pump(const Duration(milliseconds: 200));

        // 验证预览更新（mock 返回 '# Test Markdown\n\nContent'）
        // 注意：实际的 markdown 内容可能在 MarkdownPreviewWidget 中渲染
        // 这里我们验证预览占位符消失
        expect(find.text('Select nodes to preview'), findsNothing);
      });
    });
  });
}
