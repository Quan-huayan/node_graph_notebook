import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/services/i18n.dart';
import 'package:node_graph_notebook/plugins/editor/ui/markdown_editor_page.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/node_bloc.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/node_event.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/node_state.dart';
import 'package:provider/provider.dart';

import 'markdown_editor_page_test.mocks.dart';

@GenerateMocks([NodeBloc])
void main() {
  group('MarkdownEditorPage', () {
    late MockNodeBloc mockNodeBloc;
    late I18n i18n;

    setUp(() {
      mockNodeBloc = MockNodeBloc();
      i18n = I18n();
      when(mockNodeBloc.stream).thenAnswer((_) => const Stream.empty());
      when(mockNodeBloc.state).thenReturn(NodeState.initial());
      when(mockNodeBloc.add(any)).thenAnswer((_) async {});
    });

    tearDown(() {
      mockNodeBloc.close();
    });

    testWidgets('应该显示带空字段的编辑器页面', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      expect(find.text('Markdown Editor'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Write your content in Markdown...'), findsOneWidget);
    });

    testWidgets('应该显示带现有节点的编辑器页面', (WidgetTester tester) async {
      final testNode = Node(
        id: 'test_node_1',
        title: 'Test Title',
        content: 'Test Content',
        references: const {},
        position: const Offset(0, 0),
        size: const Size(200, 100),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: MarkdownEditorPage(node: testNode),
            ),
          ),
        ),
      );

      expect(find.text('Markdown Editor'), findsOneWidget);
      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('应该在编辑和预览模式之间切换', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final previewButton = find.byTooltip('Preview');
      expect(previewButton, findsOneWidget);

      await tester.tap(previewButton);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Edit'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Preview'), findsOneWidget);
    });

    testWidgets('应该在编辑模式下显示 Markdown 工具栏', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Bold'), findsOneWidget);
      expect(find.byTooltip('Italic'), findsOneWidget);
      expect(find.byTooltip('H1'), findsOneWidget);
      expect(find.byTooltip('H2'), findsOneWidget);
      expect(find.byTooltip('List'), findsOneWidget);
      expect(find.byTooltip('Code'), findsOneWidget);
      expect(find.byTooltip('Link'), findsOneWidget);
      expect(find.byTooltip('Image'), findsOneWidget);
    });

    testWidgets('应该插入粗体 Markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, 'test text');

      await tester.tap(find.byTooltip('Bold'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, 'test text****');
    });

    testWidgets('应该插入斜体 Markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, 'test text');

      await tester.tap(find.byTooltip('Italic'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, 'test text**');
    });

    testWidgets('应该插入 H1 Markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, 'test text');

      await tester.tap(find.byTooltip('H1'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, 'test text# ');
    });

    testWidgets('应该插入 H2 Markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, 'test text');

      await tester.tap(find.byTooltip('H2'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, 'test text## ');
    });

    testWidgets('应该插入列表 Markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, 'test text');

      await tester.tap(find.byTooltip('List'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, 'test text- ');
    });

    testWidgets('应该插入代码 Markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, 'test text');

      await tester.tap(find.byTooltip('Code'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, 'test text``');
    });

    testWidgets('应该插入链接 Markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, 'test text');

      await tester.tap(find.byTooltip('Link'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, 'test text[](url)');
    });

    testWidgets('应该插入图片 Markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, 'test text');

      await tester.tap(find.byTooltip('Image'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, 'test text![alt]()');
    });

    testWidgets('当标题为空时保存应该显示错误', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Title cannot be empty'), findsOneWidget);
    });

    testWidgets('当没有现有节点时保存应该创建新节点', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final titleField = find.widgetWithText(TextField, 'Title');
      await tester.enterText(titleField, 'New Title');

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, 'New Content');

      final saveButtonFinder = find.byType(IconButton).last;
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      verify(mockNodeBloc.add(argThat(isA<NodeCreateContentEvent>()))).called(1);
    });

    testWidgets('当有现有节点时保存应该更新节点', (WidgetTester tester) async {
      final testNode = Node(
        id: 'test_node_1',
        title: 'Old Title',
        content: 'Old Content',
        references: const {},
        position: const Offset(0, 0),
        size: const Size(200, 100),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: MarkdownEditorPage(node: testNode),
            ),
          ),
        ),
      );

      final titleField = find.widgetWithText(TextField, 'Old Title');
      await tester.enterText(titleField, 'Updated Title');

      final contentField = find.widgetWithText(TextField, 'Old Content');
      await tester.enterText(contentField, 'Updated Content');

      final saveButtonFinder = find.byType(IconButton).last;
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      verify(mockNodeBloc.add(argThat(isA<NodeUpdateEvent>()))).called(1);
    });

    testWidgets('保存时应该禁用保存按钮', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final titleField = find.widgetWithText(TextField, 'Title');
      await tester.enterText(titleField, 'Test Title');

      final saveButtonFinder = find.byType(IconButton).last;
      await tester.tap(saveButtonFinder);
      await tester.pump();

      final iconButton = tester.widget<IconButton>(saveButtonFinder);
      expect(iconButton.onPressed, isNull);

      await tester.pumpAndSettle(const Duration(milliseconds: 200));
    });

    testWidgets('应该显示预览模式内容', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final titleField = find.widgetWithText(TextField, 'Title');
      await tester.enterText(titleField, 'Test Title');

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, '**Bold Text**');

      await tester.tap(find.byTooltip('Preview'));
      await tester.pumpAndSettle();

      expect(find.text('# Test Title'), findsOneWidget);
      expect(find.text('Bold Text'), findsOneWidget);
    });

    testWidgets('当内容为空时应该显示无内容可预览', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Preview'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing to preview'), findsOneWidget);
    });

    testWidgets('当组件被销毁时应该销毁控制器', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      await tester.pumpWidget(Container());

      expect(find.byType(MarkdownEditorPage), findsNothing);
    });

    testWidgets('应该处理带选中文本的 Markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, 'selected text');

      await tester.tap(contentField);
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(contentField);
      final text = textField.controller!.text;
      final selection = TextSelection(baseOffset: 0, extentOffset: text.length);
      textField.controller!.selection = selection;

      await tester.tap(find.byTooltip('Bold'));
      await tester.pumpAndSettle();

      expect(textField.controller?.text, '**selected text**');
    });

    testWidgets('应该在光标位置处理 Markdown 插入', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, 'test');

      await tester.tap(contentField);
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(contentField);
      textField.controller!.selection = const TextSelection.collapsed(offset: 4);

      await tester.tap(find.byTooltip('Bold'));
      await tester.pumpAndSettle();

      expect(textField.controller?.text, 'test****');
    });

    testWidgets('应该显示带有正确图标的工具栏按钮', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.format_bold), findsOneWidget);
      expect(find.byIcon(Icons.format_italic), findsOneWidget);
      expect(find.byIcon(Icons.title), findsNWidgets(2));
      expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
      expect(find.byIcon(Icons.image), findsOneWidget);
    });

    testWidgets('应该处理标题字段变更', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final titleField = find.widgetWithText(TextField, 'Title');
      await tester.enterText(titleField, 'Test Title');

      final textField = tester.widget<TextField>(titleField);
      expect(textField.controller?.text, 'Test Title');
    });

    testWidgets('应该处理内容字段变更', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, 'Test Content');

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, 'Test Content');
    });

    testWidgets('应该显示带有正确标题的应用栏', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      expect(find.text('Markdown Editor'), findsOneWidget);
    });

    testWidgets('应该在应用栏中有保存和预览按钮', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.byIcon(Icons.preview), findsOneWidget);
    });

    testWidgets('应该处理编辑器中的长内容', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      final longContent = 'A' * 1000;
      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, longContent);

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, longContent);
    });

    testWidgets('应该处理内容中的特殊字符', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      const specialContent = 'Special: @#\$%^&*()_+-=[]{}|;:\'".,<>?/~`';
      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, specialContent);

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, specialContent);
    });

    testWidgets('应该处理内容中的 Unicode 字符', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      const unicodeContent = 'Unicode: 中文 日本語 한글 العربية';
      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, unicodeContent);

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, unicodeContent);
    });

    testWidgets('应该处理多行内容', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: const MarkdownEditorPage(),
            ),
          ),
        ),
      );

      const multilineContent = 'Line 1\nLine 2\nLine 3';
      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, multilineContent);

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, multilineContent);
    });

    testWidgets('应该处理带有空值的空节点', (WidgetTester tester) async {
      final testNode = Node(
        id: 'test_node_1',
        title: '',
        content: '',
        references: const {},
        position: const Offset(0, 0),
        size: const Size(200, 100),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: MarkdownEditorPage(node: testNode),
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Write your content in Markdown...'), findsOneWidget);
    });

    testWidgets('应该处理带有超长标题的节点', (WidgetTester tester) async {
      final longTitle = 'A' * 200;
      final testNode = Node(
        id: 'test_node_1',
        title: longTitle,
        content: 'Content',
        references: const {},
        position: const Offset(0, 0),
        size: const Size(200, 100),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<I18n>.value(
            value: i18n,
            child: BlocProvider<NodeBloc>(
              create: (_) => mockNodeBloc,
              child: MarkdownEditorPage(node: testNode),
            ),
          ),
        ),
      );

      expect(find.text(longTitle), findsOneWidget);
    });
  });
}
