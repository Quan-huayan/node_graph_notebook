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

    test('initial state is correct', () {
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
      test('should handle ImportPreviewEvent successfully', () async {
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

      test('should handle ImportPreviewEvent with error', () async {
        const rule = ConversionRule(
          splitStrategy: SplitStrategy.heading,
          headingRule: HeadingSplitRule(level: 2),
        );

        when(mockImportExportService.previewImport(
          filePath: anyNamed('filePath'),
          rule: anyNamed('rule'),
        )).thenThrow(Exception('File not found'));

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
      test('should handle ImportExecuteEvent successfully', () async {
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

      test('should handle ImportExecuteEvent with error', () async {
        const rule = ConversionRule(
          splitStrategy: SplitStrategy.heading,
          headingRule: HeadingSplitRule(level: 2),
        );

        when(mockImportExportService.executeImport(
          filePath: anyNamed('filePath'),
          rule: anyNamed('rule'),
          selectedIndices: anyNamed('selectedIndices'),
          addToGraph: anyNamed('addToGraph'),
        )).thenThrow(Exception('Import failed'));

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
      test('should handle ExportPreviewEvent successfully', () async {
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

      test('should handle ExportPreviewEvent with error', () async {
        const rule = MergeRule(
          strategy: MergeStrategy.sequence,
          sequenceRule: SequenceMergeRule(),
        );

        when(mockImportExportService.previewExport(
          nodeIds: anyNamed('nodeIds'),
          rule: anyNamed('rule'),
        )).thenThrow(Exception('Export failed'));

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
      test('should handle ExportExecuteEvent successfully', () async {
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

      test('should handle ExportExecuteEvent with error', () async {
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
        )).thenThrow(Exception('Write failed'));

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
      test('should handle BatchImportEvent successfully', () async {
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

      test('should handle BatchImportEvent with error', () async {
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
        )).thenThrow(Exception('Batch import failed'));

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
      test('should reset state to initial', () async {
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
      test('hasError returns true when error is not null', () {
        converterBloc.emit(
          converterBloc.state.copyWith(error: 'Test error'),
        );

        expect(converterBloc.state.hasError, true);
      });

      test('hasImportPreview returns true when nodes are present', () {
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

      test('hasExportPreview returns true when markdown is present', () {
        converterBloc.emit(
          converterBloc.state.copyWith(exportPreviewMarkdown: '# Test'),
        );

        expect(converterBloc.state.hasExportPreview, true);
      });

      test('isProcessing returns true when progress is set', () {
        converterBloc.emit(
          converterBloc.state.copyWith(
            currentProgress: 1,
            totalProgress: 3,
          ),
        );

        expect(converterBloc.state.isProcessing, true);
      });

      test('hasResult returns true when conversionResult is not null', () {
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

      test('wasSuccessful returns true when no failures', () {
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

      test('wasSuccessful returns false when there are failures', () {
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
