import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/plugins/converter/bloc/converter_bloc.dart';
import 'package:node_graph_notebook/plugins/converter/bloc/converter_event.dart';
import 'package:node_graph_notebook/plugins/converter/bloc/converter_state.dart';
import 'package:node_graph_notebook/plugins/converter/models/models.dart';
import 'package:node_graph_notebook/plugins/converter/service/import_export_service.dart';

@GenerateMocks([ImportExportService])
import 'converter_bloc_test.mocks.dart';

void main() {
  group('ConverterBloc', () {
      late ConverterBloc converterBloc;
      late MockImportExportService mockImportExportService;

      setUp(() {
        mockImportExportService = MockImportExportService();
        converterBloc = ConverterBloc(
          importExportService: mockImportExportService,
        );
      });

    tearDown(() {
      converterBloc.close();
    });

    test('初始状态正确', () {
      expect(converterBloc.state.isLoading, false);
      expect(converterBloc.state.importPreviewNodes, isEmpty);
      expect(converterBloc.state.exportPreviewMarkdown, '');
      expect(converterBloc.state.error, null);
      expect(converterBloc.state.hasError, false);
      expect(converterBloc.state.hasImportPreview, false);
      expect(converterBloc.state.hasExportPreview, false);
      expect(converterBloc.state.isProcessing, false);
      expect(converterBloc.state.hasResult, false);
    });

    group('ImportPreviewEvent', () {
      test('成功处理导入预览事件', () async {
        final mockNodes = [
          Node(
            id: 'node_1',
            title: 'Test Node 1',
            content: 'Content 1',
            references: {},
            position: const Offset(100, 100),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: {},
          ),
          Node(
            id: 'node_2',
            title: 'Test Node 2',
            content: 'Content 2',
            references: {},
            position: const Offset(100, 100),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: {},
          ),
        ];

        const rule = ConversionRule(
          splitStrategy: SplitStrategy.heading,
          headingRule: HeadingSplitRule(level: 2),
        );

        when(mockImportExportService.previewImport(
          filePath: anyNamed('filePath'),
          rule: anyNamed('rule'),
        )).thenAnswer((_) async => mockNodes);

        converterBloc.add(
          const ImportPreviewEvent(
            'test.md',
            rule,
          ),
        );

        await expectLater(
          converterBloc.stream,
          emitsInOrder([
            predicate<ConverterState>((state) => state.isLoading),
            predicate<ConverterState>((state) =>
                !state.isLoading &&
                state.importPreviewNodes.length == 2 &&
                state.error == null),
          ]),
        );
      });

      test('处理导入预览事件出错', () async {
        const rule = ConversionRule(
          splitStrategy: SplitStrategy.heading,
          headingRule: HeadingSplitRule(level: 2),
        );

        when(mockImportExportService.previewImport(
          filePath: anyNamed('filePath'),
          rule: anyNamed('rule'),
        )).thenThrow(Exception('文件未找到'));

        converterBloc.add(
          const ImportPreviewEvent(
            'nonexistent.md',
            rule,
          ),
        );

        await expectLater(
          converterBloc.stream,
          emitsInOrder([
            predicate<ConverterState>((state) => state.isLoading),
            predicate<ConverterState>((state) =>
                !state.isLoading && state.error != null),
          ]),
        );
      });
    });

    group('ImportExecuteEvent', () {
      test('成功处理导入执行事件', () async {
        final mockNodes = [
          Node(
            id: 'node_1',
            title: 'Test Node 1',
            content: 'Content 1',
            references: {},
            position: const Offset(100, 100),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: {},
          ),
        ];

        const mockResult = ConversionResult(
          successCount: 1,
          failureCount: 0,
          errors: [],
          duration: Duration(milliseconds: 100),
          createdNodeIds: ['node_1'],
        );

        const rule = ConversionRule(
          splitStrategy: SplitStrategy.heading,
          headingRule: HeadingSplitRule(level: 2),
        );

        when(mockImportExportService.previewImport(
          filePath: anyNamed('filePath'),
          rule: anyNamed('rule'),
        )).thenAnswer((_) async => mockNodes);

        when(mockImportExportService.executeImport(
          filePath: anyNamed('filePath'),
          rule: anyNamed('rule'),
          selectedIndices: anyNamed('selectedIndices'),
          addToGraph: anyNamed('addToGraph'),
        )).thenAnswer((_) async => mockResult);

        converterBloc.add(
          const ImportExecuteEvent(
            'test.md',
            rule,
            [0],
          ),
        );

        await expectLater(
          converterBloc.stream,
          emitsInOrder([
            predicate<ConverterState>((state) => state.isLoading),
            predicate<ConverterState>((state) =>
                !state.isLoading &&
                state.conversionResult?.successCount == 1 &&
                state.error == null),
          ]),
        );
      });

      test('处理导入执行事件出错', () async {
        const rule = ConversionRule(
          splitStrategy: SplitStrategy.heading,
          headingRule: HeadingSplitRule(level: 2),
        );

        when(mockImportExportService.executeImport(
          filePath: anyNamed('filePath'),
          rule: anyNamed('rule'),
          selectedIndices: anyNamed('selectedIndices'),
          addToGraph: anyNamed('addToGraph'),
        )).thenThrow(Exception('导入失败'));

        converterBloc.add(
          const ImportExecuteEvent(
            'test.md',
            rule,
            [0],
          ),
        );

        await expectLater(
          converterBloc.stream,
          emitsInOrder([
            predicate<ConverterState>((state) => state.isLoading),
            predicate<ConverterState>((state) =>
                !state.isLoading && state.error != null),
          ]),
        );
      });
    });

    group('ExportPreviewEvent', () {
      test('成功处理导出预览事件', () async {
        const mockMarkdown = '# Test Node 1\n\nContent 1\n\n---\n\n# Test Node 2\n\nContent 2';

        const rule = MergeRule(
          strategy: MergeStrategy.sequence,
          sequenceRule: SequenceMergeRule(),
        );

        when(mockImportExportService.previewExport(
          nodeIds: anyNamed('nodeIds'),
          rule: anyNamed('rule'),
        )).thenAnswer((_) async => mockMarkdown);

        converterBloc.add(
          const ExportPreviewEvent(
            ['node_1', 'node_2'],
            rule,
          ),
        );

        await expectLater(
          converterBloc.stream,
          emitsInOrder([
            predicate<ConverterState>((state) => state.isLoading),
            predicate<ConverterState>((state) =>
                !state.isLoading &&
                state.exportPreviewMarkdown == mockMarkdown &&
                state.error == null),
          ]),
        );
      });

      test('处理导出预览事件出错', () async {
        const rule = MergeRule(
          strategy: MergeStrategy.sequence,
          sequenceRule: SequenceMergeRule(),
        );

        when(mockImportExportService.previewExport(
          nodeIds: anyNamed('nodeIds'),
          rule: anyNamed('rule'),
        )).thenThrow(Exception('导出失败'));

        converterBloc.add(
          const ExportPreviewEvent(
            ['node_1'],
            rule,
          ),
        );

        await expectLater(
          converterBloc.stream,
          emitsInOrder([
            predicate<ConverterState>((state) => state.isLoading),
            predicate<ConverterState>((state) =>
                !state.isLoading && state.error != null),
          ]),
        );
      });
    });

    group('ExportExecuteEvent', () {
      test('成功处理导出执行事件', () async {
        const rule = MergeRule(
          strategy: MergeStrategy.sequence,
          sequenceRule: SequenceMergeRule(),
        );

        when(mockImportExportService.previewExport(
          nodeIds: anyNamed('nodeIds'),
          rule: anyNamed('rule'),
        )).thenAnswer((_) async => '# Test\n\nContent');

        final mockFile = File('output.md');
        when(mockImportExportService.executeExport(
          nodeIds: anyNamed('nodeIds'),
          rule: anyNamed('rule'),
          outputPath: anyNamed('outputPath'),
        )).thenAnswer((_) async => mockFile);

        converterBloc.add(
          const ExportExecuteEvent(
            ['node_1'],
            rule,
            'output.md',
          ),
        );

        await expectLater(
          converterBloc.stream,
          emitsInOrder([
            predicate<ConverterState>((state) => state.isLoading),
            predicate<ConverterState>((state) =>
                !state.isLoading &&
                state.conversionResult?.successCount == 1 &&
                state.error == null),
          ]),
        );
      });

      test('处理导出执行事件出错', () async {
        const rule = MergeRule(
          strategy: MergeStrategy.sequence,
          sequenceRule: SequenceMergeRule(),
        );

        when(mockImportExportService.previewExport(
          nodeIds: anyNamed('nodeIds'),
          rule: anyNamed('rule'),
        )).thenAnswer((_) async => '# Test\n\nContent');

        when(mockImportExportService.executeExport(
          nodeIds: anyNamed('nodeIds'),
          rule: anyNamed('rule'),
          outputPath: anyNamed('outputPath'),
        )).thenThrow(Exception('写入失败'));

        converterBloc.add(
          const ExportExecuteEvent(
            ['node_1'],
            rule,
            'output.md',
          ),
        );

        await expectLater(
          converterBloc.stream,
          emitsInOrder([
            predicate<ConverterState>((state) => state.isLoading),
            predicate<ConverterState>((state) =>
                !state.isLoading && state.error != null),
          ]),
        );
      });
    });

    group('BatchImportEvent', () {
      test('成功处理批量导入事件', () async {
        const mockResult = ConversionResult(
          successCount: 3,
          failureCount: 0,
          errors: [],
          duration: Duration(milliseconds: 500),
          createdNodeIds: ['node_1', 'node_2', 'node_3'],
        );

        const config = ConversionConfig(
          rule: ConversionRule(
            splitStrategy: SplitStrategy.heading,
            headingRule: HeadingSplitRule(level: 2),
          ),
        );

        when(mockImportExportService.batchImport(
          filePaths: anyNamed('filePaths'),
          config: anyNamed('config'),
          onProgress: anyNamed('onProgress'),
        )).thenAnswer((_) async => mockResult);

        converterBloc.add(
          const BatchImportEvent(
            ['file1.md', 'file2.md', 'file3.md'],
            config,
          ),
        );

        await expectLater(
          converterBloc.stream,
          emitsInOrder([
            predicate<ConverterState>((state) =>
                state.isLoading &&
                state.currentProgress == 0 &&
                state.totalProgress == 3),
            predicate<ConverterState>((state) =>
                !state.isLoading &&
                state.conversionResult?.successCount == 3 &&
                state.currentProgress == null &&
                state.totalProgress == null &&
                state.error == null),
          ]),
        );
      });

      test('处理批量导入事件出错', () async {
        const config = ConversionConfig(
          rule: ConversionRule(
            splitStrategy: SplitStrategy.heading,
            headingRule: HeadingSplitRule(level: 2),
          ),
        );

        when(mockImportExportService.batchImport(
          filePaths: anyNamed('filePaths'),
          config: anyNamed('config'),
          onProgress: anyNamed('onProgress'),
        )).thenThrow(Exception('批量导入失败'));

        converterBloc.add(
          const BatchImportEvent(
            ['file1.md'],
            config,
          ),
        );

        await expectLater(
          converterBloc.stream,
          emitsInOrder([
            predicate<ConverterState>((state) =>
                state.isLoading &&
                state.currentProgress == 0 &&
                state.totalProgress == 1),
            predicate<ConverterState>((state) =>
                !state.isLoading &&
                state.currentProgress == null &&
                state.totalProgress == null &&
                state.error != null),
          ]),
        );
      });
    });

    group('ClearPreviewEvent', () {
      test('重置状态为初始状态', () async {
        const rule = ConversionRule(
          splitStrategy: SplitStrategy.heading,
          headingRule: HeadingSplitRule(level: 2),
        );

        when(mockImportExportService.previewImport(
          filePath: anyNamed('filePath'),
          rule: anyNamed('rule'),
        )).thenAnswer((_) async => []);

        converterBloc.add(
          const ImportPreviewEvent(
            'test.md',
            rule,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        converterBloc.add(const ClearPreviewEvent());

        await Future.delayed(const Duration(milliseconds: 50));

        expect(converterBloc.state.isLoading, false);
        expect(converterBloc.state.importPreviewNodes, isEmpty);
        expect(converterBloc.state.exportPreviewMarkdown, '');
        expect(converterBloc.state.error, null);
        expect(converterBloc.state.conversionResult, null);
      });
    });

    group('State getters', () {
      test('当错误不为空时hasError返回true', () {
        converterBloc.emit(
          converterBloc.state.copyWith(error: '测试错误'),
        );

        expect(converterBloc.state.hasError, true);
      });

      test('当节点存在时hasImportPreview返回true', () {
        final mockNodes = [
          Node(
            id: 'node_1',
            title: 'Test Node',
            content: 'Content',
            references: {},
            position: const Offset(100, 100),
            size: const Size(300, 400),
            viewMode: NodeViewMode.titleWithPreview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: {},
          ),
        ];

        converterBloc.emit(
          converterBloc.state.copyWith(importPreviewNodes: mockNodes),
        );

        expect(converterBloc.state.hasImportPreview, true);
      });

      test('当markdown存在时hasExportPreview返回true', () {
        converterBloc.emit(
          converterBloc.state.copyWith(exportPreviewMarkdown: '# Test'),
        );

        expect(converterBloc.state.hasExportPreview, true);
      });

      test('当进度设置时isProcessing返回true', () {
        converterBloc.emit(
          converterBloc.state.copyWith(
            currentProgress: 1,
            totalProgress: 3,
          ),
        );

        expect(converterBloc.state.isProcessing, true);
      });

      test('当conversionResult不为空时hasResult返回true', () {
        const mockResult = ConversionResult(
          successCount: 1,
          failureCount: 0,
          errors: [],
          duration: Duration.zero,
          createdNodeIds: ['node_1'],
        );

        converterBloc.emit(
          converterBloc.state.copyWith(conversionResult: mockResult),
        );

        expect(converterBloc.state.hasResult, true);
      });

      test('当没有失败时wasSuccessful返回true', () {
        const mockResult = ConversionResult(
          successCount: 1,
          failureCount: 0,
          errors: [],
          duration: Duration.zero,
          createdNodeIds: ['node_1'],
        );

        converterBloc.emit(
          converterBloc.state.copyWith(conversionResult: mockResult),
        );

        expect(converterBloc.state.wasSuccessful, true);
      });

      test('当有失败时wasSuccessful返回false', () {
        const mockResult = ConversionResult(
          successCount: 1,
          failureCount: 1,
          errors: ['Error'],
          duration: Duration.zero,
          createdNodeIds: ['node_1'],
        );

        converterBloc.emit(
          converterBloc.state.copyWith(conversionResult: mockResult),
        );

        expect(converterBloc.state.wasSuccessful, false);
      });
    });
  });
}
