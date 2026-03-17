import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/models/graph.dart';
import 'package:node_graph_notebook/core/repositories/graph_repository.dart';
import 'package:node_graph_notebook/core/repositories/metadata_index.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/core/services/infrastructure/storage_path_service.dart';
import 'package:node_graph_notebook/plugins/data_recovery/command/validate_data_command.dart';
import 'package:node_graph_notebook/plugins/data_recovery/handler/validate_data_handler.dart';

@GenerateMocks([
  StoragePathService,
  CommandContext,
  NodeRepository,
  GraphRepository,
  MetadataIndex,
])
import 'validate_data_handler_test.mocks.dart';

void main() {
  group('ValidateDataHandler', () {
    late ValidateDataHandler handler;
    late MockStoragePathService mockStoragePathService;
    late MockCommandContext mockCommandContext;
    late MockNodeRepository mockNodeRepository;
    late MockGraphRepository mockGraphRepository;
    late MockMetadataIndex mockMetadataIndex;

    setUp(() {
      mockStoragePathService = MockStoragePathService();
      mockCommandContext = MockCommandContext();
      mockNodeRepository = MockNodeRepository();
      mockGraphRepository = MockGraphRepository();
      mockMetadataIndex = MockMetadataIndex();
      handler = ValidateDataHandler(
        nodeRepository: mockNodeRepository,
        graphRepository: mockGraphRepository,
        storagePathService: mockStoragePathService,
      );
    });

    test('should validate successfully when all directories exist', () async {
      final tempDir = Directory.systemTemp.createTempSync('validate_test_');
      final storagePath = tempDir.path;
      Directory('$storagePath/nodes').createSync();
      Directory('$storagePath/graphs').createSync();

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockNodeRepository.getMetadataIndex()).thenAnswer((_) async => mockMetadataIndex);
      when(mockMetadataIndex.nodes).thenReturn([]);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = ValidateDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);
      expect(result.data!.issuesFound, 0);
      expect(result.data!.message, contains('所有数据验证通过'));

      tempDir.deleteSync(recursive: true);
    });

    test('should detect missing storage directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('validate_test_');
      final storagePath = tempDir.path;
      Directory('$storagePath/nodes').createSync();
      Directory('$storagePath/graphs').createSync();

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockNodeRepository.getMetadataIndex()).thenAnswer((_) async => mockMetadataIndex);
      when(mockMetadataIndex.nodes).thenReturn([]);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = ValidateDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);
      expect(result.data!.issuesFound, 0);

      tempDir.deleteSync(recursive: true);
    });

    test('should detect missing nodes directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('validate_test_');
      final storagePath = tempDir.path;
      Directory('$storagePath/graphs').createSync();

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockNodeRepository.getMetadataIndex()).thenAnswer((_) async => mockMetadataIndex);
      when(mockMetadataIndex.nodes).thenReturn([]);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = ValidateDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);
      expect(result.data!.issuesFound, 1);
      expect(result.data!.issues.any((issue) => issue.contains('节点目录不存在')), true);

      tempDir.deleteSync(recursive: true);
    });

    test('should detect missing graphs directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('validate_test_');
      final storagePath = tempDir.path;
      Directory('$storagePath/nodes').createSync();

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockNodeRepository.getMetadataIndex()).thenAnswer((_) async => mockMetadataIndex);
      when(mockMetadataIndex.nodes).thenReturn([]);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = ValidateDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);
      expect(result.data!.issuesFound, 1);
      expect(result.data!.issues.any((issue) => issue.contains('图目录不存在')), true);

      tempDir.deleteSync(recursive: true);
    });

    test('should detect index mismatch', () async {
      final tempDir = Directory.systemTemp.createTempSync('validate_test_');
      final storagePath = tempDir.path;
      Directory('$storagePath/nodes').createSync();
      Directory('$storagePath/graphs').createSync();

      final nodeMetadata1 = NodeMetadata(
        id: 'node1',
        title: 'Node 1',
        position: const PositionInfo(dx: 0, dy: 0),
        size: const SizeInfo(width: 100, height: 100),
        filePath: '/path/to/node1.json',
        referencedNodeIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final nodeMetadata2 = NodeMetadata(
        id: 'node2',
        title: 'Node 2',
        position: const PositionInfo(dx: 100, dy: 100),
        size: const SizeInfo(width: 100, height: 100),
        filePath: '/path/to/node2.json',
        referencedNodeIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockNodeRepository.getMetadataIndex()).thenAnswer((_) async => mockMetadataIndex);
      when(mockMetadataIndex.nodes).thenReturn([nodeMetadata1, nodeMetadata2]);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = ValidateDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);
      expect(result.data!.issuesFound, 1);
      expect(result.data!.issues.any((issue) => issue.contains('索引不匹配')), true);

      tempDir.deleteSync(recursive: true);
    });

    test('should detect node validation failure', () async {
      final tempDir = Directory.systemTemp.createTempSync('validate_test_');
      final storagePath = tempDir.path;
      Directory('$storagePath/nodes').createSync();
      Directory('$storagePath/graphs').createSync();

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenThrow(Exception('Node query error'));
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = ValidateDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);
      expect(result.data!.issuesFound, 1);
      expect(result.data!.issues.any((issue) => issue.contains('节点验证失败')), true);

      tempDir.deleteSync(recursive: true);
    });

    test('should detect invalid current graph setting', () async {
      final tempDir = Directory.systemTemp.createTempSync('validate_test_');
      final storagePath = tempDir.path;
      Directory('$storagePath/nodes').createSync();
      Directory('$storagePath/graphs').createSync();

      final graph = Graph.empty('graph1');

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockNodeRepository.getMetadataIndex()).thenAnswer((_) async => mockMetadataIndex);
      when(mockMetadataIndex.nodes).thenReturn([]);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => [graph]);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = ValidateDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);
      expect(result.data!.issuesFound, 1);
      expect(result.data!.issues.any((issue) => issue.contains('当前图设置无效')), true);

      tempDir.deleteSync(recursive: true);
    });

    test('should detect graph validation failure', () async {
      final tempDir = Directory.systemTemp.createTempSync('validate_test_');
      final storagePath = tempDir.path;
      Directory('$storagePath/nodes').createSync();
      Directory('$storagePath/graphs').createSync();

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockNodeRepository.getMetadataIndex()).thenAnswer((_) async => mockMetadataIndex);
      when(mockMetadataIndex.nodes).thenReturn([]);
      when(mockGraphRepository.getAll()).thenThrow(Exception('Graph query error'));

      final command = ValidateDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);
      expect(result.data!.issuesFound, 1);
      expect(result.data!.issues.any((issue) => issue.contains('图验证失败')), true);

      tempDir.deleteSync(recursive: true);
    });

    test('should detect multiple issues', () async {
      final tempDir = Directory.systemTemp.createTempSync('validate_test_');
      final storagePath = tempDir.path;
      Directory('$storagePath/graphs').createSync();

      final nodeMetadata = NodeMetadata(
        id: 'node1',
        title: 'Node 1',
        position: const PositionInfo(dx: 0, dy: 0),
        size: const SizeInfo(width: 100, height: 100),
        filePath: '/path/to/node1.json',
        referencedNodeIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final graph = Graph.empty('graph1');

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockNodeRepository.getMetadataIndex()).thenAnswer((_) async => mockMetadataIndex);
      when(mockMetadataIndex.nodes).thenReturn([nodeMetadata]);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => [graph]);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = ValidateDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);
      expect(result.data!.issuesFound, greaterThan(1));
      expect(result.data!.message, contains('发现'));

      tempDir.deleteSync(recursive: true);
    });

    test('should return failure when validation fails', () async {
      when(mockStoragePathService.getStoragePath()).thenThrow(Exception('Storage path error'));

      final command = ValidateDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('验证失败'));
    });

    test('should include issues list in result', () async {
      final tempDir = Directory.systemTemp.createTempSync('validate_test_');
      final storagePath = tempDir.path;
      Directory('$storagePath/graphs').createSync();

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockNodeRepository.getMetadataIndex()).thenAnswer((_) async => mockMetadataIndex);
      when(mockMetadataIndex.nodes).thenReturn([]);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = ValidateDataCommand();
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.issues, isNotEmpty);
      expect(result.data!.issues.any((issue) => issue.contains('节点目录不存在')), true);

      tempDir.deleteSync(recursive: true);
    });
  });
}