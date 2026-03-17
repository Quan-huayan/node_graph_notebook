import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/plugins/editor/ui/markdown_editor_page.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/node_bloc.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/node_event.dart';

import 'markdown_editor_page_test.mocks.dart';

@GenerateMocks([NodeBloc])
void main() {
  group('MarkdownEditorPage', () {
    late MockNodeBloc mockNodeBloc;

    setUp(() {
      mockNodeBloc = MockNodeBloc();
    });

    tearDown(() {
      mockNodeBloc.close();
    });

    testWidgets('should display editor page with empty fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
          ),
        ),
      );

      expect(find.text('Markdown Editor'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Write your content in Markdown...'), findsOneWidget);
    });

    testWidgets('should display editor page with existing node', (WidgetTester tester) async {
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
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: MarkdownEditorPage(node: testNode),
          ),
        ),
      );

      expect(find.text('Markdown Editor'), findsOneWidget);
      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('should toggle between edit and preview mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
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

    testWidgets('should display markdown toolbar in edit mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
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

    testWidgets('should insert bold markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
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

    testWidgets('should insert italic markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
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

    testWidgets('should insert H1 markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
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

    testWidgets('should insert H2 markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
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

    testWidgets('should insert list markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
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

    testWidgets('should insert code markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
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

    testWidgets('should insert link markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
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

    testWidgets('should insert image markdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
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

    testWidgets('should show error when saving with empty title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Title cannot be empty'), findsOneWidget);
    });

    testWidgets('should create new node when saving without existing node', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
          ),
        ),
      );

      final titleField = find.widgetWithText(TextField, 'Title');
      await tester.enterText(titleField, 'New Title');

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, 'New Content');

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      verify(mockNodeBloc.add(argThat(isA<NodeCreateContentEvent>()))).called(1);
    });

    testWidgets('should update existing node when saving with existing node', (WidgetTester tester) async {
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
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: MarkdownEditorPage(node: testNode),
          ),
        ),
      );

      final titleField = find.widgetWithText(TextField, 'Old Title');
      await tester.enterText(titleField, 'Updated Title');

      final contentField = find.widgetWithText(TextField, 'Old Content');
      await tester.enterText(contentField, 'Updated Content');

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      verify(mockNodeBloc.add(argThat(isA<NodeUpdateEvent>()))).called(1);
    });

    testWidgets('should disable save button while saving', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
          ),
        ),
      );

      final titleField = find.widgetWithText(TextField, 'Title');
      await tester.enterText(titleField, 'Test Title');

      await tester.tap(find.byTooltip('Save'));
      await tester.pump();

      final saveButton = find.byTooltip('Save');
      expect(tester.widget<IconButton>(saveButton).onPressed, isNull);
    });

    testWidgets('should show preview mode content', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
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

    testWidgets('should show nothing to preview when content is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Preview'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing to preview'), findsOneWidget);
    });

    testWidgets('should dispose controllers when widget is disposed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
          ),
        ),
      );

      await tester.pumpWidget(Container());

      expect(find.byType(MarkdownEditorPage), findsNothing);
    });

    testWidgets('should handle markdown with selected text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
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

    testWidgets('should handle markdown insertion at cursor position', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
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

    testWidgets('should display toolbar buttons with correct icons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
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

    testWidgets('should handle title field changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
          ),
        ),
      );

      final titleField = find.widgetWithText(TextField, 'Title');
      await tester.enterText(titleField, 'Test Title');

      final textField = tester.widget<TextField>(titleField);
      expect(textField.controller?.text, 'Test Title');
    });

    testWidgets('should handle content field changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
          ),
        ),
      );

      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, 'Test Content');

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, 'Test Content');
    });

    testWidgets('should display app bar with correct title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
          ),
        ),
      );

      expect(find.text('Markdown Editor'), findsOneWidget);
    });

    testWidgets('should have save and preview buttons in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
          ),
        ),
      );

      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.byIcon(Icons.preview), findsOneWidget);
    });

    testWidgets('should handle long content in editor', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
          ),
        ),
      );

      final longContent = 'A' * 1000;
      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, longContent);

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, longContent);
    });

    testWidgets('should handle special characters in content', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
          ),
        ),
      );

      const specialContent = 'Special: @#\$%^&*()_+-=[]{}|;:\'".,<>?/~`';
      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, specialContent);

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, specialContent);
    });

    testWidgets('should handle unicode characters in content', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
          ),
        ),
      );

      const unicodeContent = 'Unicode: 中文 日本語 한글 العربية';
      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, unicodeContent);

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, unicodeContent);
    });

    testWidgets('should handle multiline content', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: const MarkdownEditorPage(),
          ),
        ),
      );

      const multilineContent = 'Line 1\nLine 2\nLine 3';
      final contentField = find.widgetWithText(TextField, 'Write your content in Markdown...');
      await tester.enterText(contentField, multilineContent);

      final textField = tester.widget<TextField>(contentField);
      expect(textField.controller?.text, multilineContent);
    });

    testWidgets('should handle empty node with null values', (WidgetTester tester) async {
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
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: MarkdownEditorPage(node: testNode),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Write your content in Markdown...'), findsOneWidget);
    });

    testWidgets('should handle node with very long title', (WidgetTester tester) async {
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
          home: BlocProvider<NodeBloc>(
            create: (_) => mockNodeBloc,
            child: MarkdownEditorPage(node: testNode),
          ),
        ),
      );

      expect(find.text(longTitle), findsOneWidget);
    });
  });
}
