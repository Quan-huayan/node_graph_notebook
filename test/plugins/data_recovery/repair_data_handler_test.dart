import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/repositories/graph_repository.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/core/services/infrastructure/storage_path_service.dart';
import 'package:node_graph_notebook/plugins/data_recovery/command/repair_data_command.dart';
import 'package:node_graph_notebook/plugins/data_recovery/handler/repair_data_handler.dart';

@GenerateMocks([
  StoragePathService,
  CommandContext,
  NodeRepository,
  GraphRepository,
])
import 'repair_data_handler_test.mocks.dart';

void main() {
  group('RepairDataHandler', () {
    late RepairDataHandler handler;
    late MockStoragePathService mockStoragePathService;
    late MockCommandContext mockCommandContext;
    late MockNodeRepository mockNodeRepository;
    late MockGraphRepository mockGraphRepository;

    setUp(() {
      mockStoragePathService = MockStoragePathService();
      mockCommandContext = MockCommandContext();
      mockNodeRepository = MockNodeRepository();
      mockGraphRepository = MockGraphRepository();
      handler = RepairDataHandler(
        nodeRepository: mockNodeRepository,
        graphRepository: mockGraphRepository,
        storagePathService: mockStoragePathService,
      );
    });

    test('should repair missing storage directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('repair_test_');
      final storagePath = tempDir.path;
      final storageDir = Directory(storagePath)..deleteSync();

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = RepairDataCommand(createBackup: false);
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);
      expect(result.data!.repairedIssues, greaterThan(0));
      expect(storageDir.existsSync(), true);

      tempDir.deleteSync(recursive: true);
    });

    test('should repair missing nodes directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('repair_test_');
      final storagePath = tempDir.path;
      final nodesPath = '$storagePath/nodes';

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => nodesPath);
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = RepairDataCommand(createBackup: false);
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);
      expect(result.data!.repairedIssues, greaterThan(0));
      expect(Directory(nodesPath).existsSync(), true);

      tempDir.deleteSync(recursive: true);
    });

    test('should repair missing graphs directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('repair_test_');
      final storagePath = tempDir.path;
      final graphsPath = '$storagePath/graphs';

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => graphsPath);
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = RepairDataCommand(createBackup: false);
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.success, true);
      expect(result.data!.repairedIssues, greaterThan(0));
      expect(Directory(graphsPath).existsSync(), true);

      tempDir.deleteSync(recursive: true);
    });

    test('should rebuild index', () async {
      final tempDir = Directory.systemTemp.createTempSync('repair_test_');
      final storagePath = tempDir.path;
      Directory('$storagePath/nodes').createSync();
      Directory('$storagePath/graphs').createSync();

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockNodeRepository.updateIndex(any)).thenAnswer((_) async {});
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = RepairDataCommand(createBackup: false);
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.repairedIssues, greaterThan(0));

      tempDir.deleteSync(recursive: true);
    });

    test('should repair current graph setting', () async {
      final tempDir = Directory.systemTemp.createTempSync('repair_test_');
      final storagePath = tempDir.path;
      Directory('$storagePath/nodes').createSync();
      Directory('$storagePath/graphs').createSync();

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockNodeRepository.updateIndex(any)).thenAnswer((_) async {});
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = RepairDataCommand(createBackup: false);
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.repairedIssues, greaterThan(0));

      tempDir.deleteSync(recursive: true);
    });

    test('should create backup when createBackup is true', () async {
      final tempDir = Directory.systemTemp.createTempSync('repair_test_');
      final storagePath = tempDir.path;
      final nodesDir = Directory('$storagePath/nodes')..createSync();
      final graphsDir = Directory('$storagePath/graphs')..createSync();

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => nodesDir.path);
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => graphsDir.path);
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = RepairDataCommand(createBackup: true);
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.backupPath, isNotNull);
      expect(result.data!.backupPath, contains('backup_'));

      final backupDir = Directory(result.data!.backupPath!);
      expect(backupDir.existsSync(), true);

      tempDir.deleteSync(recursive: true);
    });

    test('should not create backup when createBackup is false', () async {
      final tempDir = Directory.systemTemp.createTempSync('repair_test_');
      final storagePath = tempDir.path;

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = RepairDataCommand(createBackup: false);
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.backupPath, isNull);

      tempDir.deleteSync(recursive: true);
    });

    test('should return failure when storage path fails', () async {
      when(mockStoragePathService.getStoragePath()).thenThrow(Exception('Storage path error'));

      final command = RepairDataCommand(createBackup: false);
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('修复失败'));
    });

    test('should include success message in result', () async {
      final tempDir = Directory.systemTemp.createTempSync('repair_test_');
      final storagePath = tempDir.path;

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = RepairDataCommand(createBackup: false);
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.message, contains('成功修复'));

      tempDir.deleteSync(recursive: true);
    });

    test('should handle no issues to repair', () async {
      final tempDir = Directory.systemTemp.createTempSync('repair_test_');
      final storagePath = tempDir.path;
      Directory('$storagePath/nodes').createSync();
      Directory('$storagePath/graphs').createSync();

      when(mockStoragePathService.getStoragePath()).thenAnswer((_) async => storagePath);
      when(mockStoragePathService.getNodesPath()).thenAnswer((_) async => '$storagePath/nodes');
      when(mockStoragePathService.getGraphsPath()).thenAnswer((_) async => '$storagePath/graphs');
      when(mockNodeRepository.queryAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getAll()).thenAnswer((_) async => []);
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      final command = RepairDataCommand(createBackup: false);
      final result = await handler.execute(command, mockCommandContext);

      expect(result.isSuccess, true);
      expect(result.data!.repairedIssues, greaterThan(0));

      tempDir.deleteSync(recursive: true);
    });
  });
}